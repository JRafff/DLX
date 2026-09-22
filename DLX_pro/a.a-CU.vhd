library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity dlx_cu is
  generic (
    MICROCODE_MEM_SIZE : integer := 64;  
    FUNC_SIZE          : integer := 11;  
    OP_CODE_SIZE       : integer := 6;   
    IR_SIZE            : integer := 32;      
    CW_SIZE            : integer := 7    
  );
  port (
    Clk                : in  std_logic;
    Rst                : in  std_logic;
    
    IR_IN              : in  std_logic_vector(IR_SIZE - 1 downto 0);
    
    -- ------------------------------------------------
    -- ALLARMI 
    cache_miss_in      : in  std_logic; -- Da IF o MEM (Congela TUTTO)
    load_use_alarm     : in  std_logic; -- load use hazard, inserisco stall
    mispredict_in      : in  std_logic; -- Da ID (Svuota IF_ID)
    branch_stall_alarm : in  std_logic; -- branch stall dalla hazard detection unit

    -- controlli registri di pipe
    PC_EN              : out std_logic;
    
    IF_ID_EN           : out std_logic;
    IF_ID_CLEAR        : out std_logic;
    
    ID_EX_EN           : out std_logic;
    ID_EX_CLEAR        : out std_logic;
    
    EX_MEM_EN          : out std_logic;
    EX_MEM_CLEAR       : out std_logic;
    
    MEM_WB_EN          : out std_logic;
    MEM_WB_CLEAR       : out std_logic;

    -- control signals
    JUMP_EN            : out std_logic;
    EQ_COND            : out std_logic;
    MUXA_SEL           : out std_logic;
    MUXB_SEL           : out std_logic;
    ALU_OPCODE         : out aluOp;
    EX_RF_WE_OUT       : out std_logic;
    EX_WB_MUX_SEL_OUT  : out std_logic;
    MEM_RF_WE_OUT      : out std_logic;   -- RF_WE dell'istr. in MEM (per forwarding/hazard)
    MEM_WB_MUX_SEL_OUT : out std_logic;   -- WB_MUX dell'istr. in MEM (per hazard: distingue Load)
    DRAM_WE            : out std_logic;
    WB_MUX_SEL         : out std_logic;
    RF_WE              : out std_logic
  );
end dlx_cu;

architecture dlx_cu_hw of dlx_cu is

  type mem_array is array (integer range 0 to MICROCODE_MEM_SIZE - 1) of std_logic_vector(CW_SIZE - 1 downto 0);
  constant cw_mem : mem_array := (
    -- ====================================================================
    -- Layout: JUMP_EN(6) | EQ_COND(5) | MUXA(4) | MUXB(3) | DRAM_WE(2) | WB_MUX(1) | RF_WE(0)
    -- ====================================================================

    -- ------ R-type ------
    -- RegA + RegB -> ALU -> WB in Register File
    "0000001", -- 0x00 R-type (ADD, SUB, AND, OR, XOR, SLL, SRL, etc.)
    "0000000", -- 0x01 unused
    
    -- ------ Jumps / Branches ------
    -- JUMP_EN=1 o EQ_COND=1. Il Datapath calcola tutto in Decode. Nessuna scrittura (tranne JAL).
    "1000000", -- 0x02 J:    Solo JUMP_EN=1
    "1011001", -- 0x03 JAL:  JUMP_EN=1, MUXA=NPC, MUXB=IMM(0), WB=ALU, RF_WE=1 (Scrive NPC in R31)
    "0100000", -- 0x04 BEQZ: Solo EQ_COND=1
    "0100000", -- 0x05 BNEZ: Solo EQ_COND=1 (Il DP nega la condizione)
    "0000000", -- 0x06 unused
    "0000000", -- 0x07 unused
    
    -- ------ I-type ALU ------
    -- RegA + IMM -> ALU -> WB in Register File
    "0001001", -- 0x08 ADDI
    "0000000", -- 0x09 unused
    "0001001", -- 0x0A SUBI
    "0000000", -- 0x0B unused
    "0001001", -- 0x0C ANDI
    "0001001", -- 0x0D ORI
    "0001001", -- 0x0E XORI
    "0000000", -- 0x0F unused
    "0000000", -- 0x10 unused
    "0000000", -- 0x11 unused
    "0000000", -- 0x12 unused
    "0000000", -- 0x13 unused
    "0001001", -- 0x14 SLLI
    "0000000", -- 0x15 NOP: Nessuna operazione. Tutto a 0.
    "0001001", -- 0x16 SRLI
    "0000000", -- 0x17 unused
    "0000000", -- 0x18 unused
    "0001001", -- 0x19 SNEI
    "0000000", -- 0x1A unused
    "0000000", -- 0x1B unused
    "0001001", -- 0x1C SLEI
    "0001001", -- 0x1D SGEI
    "0000000", -- 0x1E unused
    "0000000", -- 0x1F unused
    
    -- ------ Loads / Stores ------
    -- Memoria: Entrambe usano l'ALU (RegA + IMM) per l'indirizzo.
    "0000000", -- 0x20 unused
    "0000000", -- 0x21 unused
    "0000000", -- 0x22 unused
    "0001011", -- 0x23 LW:   MUXB=IMM(1), WB_MUX=LMD(1), RF_WE=1
    "0000000", -- 0x24 unused
    "0000000", -- 0x25 unused
    "0000000", -- 0x26 unused
    "0000000", -- 0x27 unused
    "0000000", -- 0x28 unused
    "0000000", -- 0x29 unused
    "0000000", -- 0x2A unused
    "0001100", -- 0x2B SW:   MUXB=IMM(1), DRAM_WE=1 (RF_WE=0)
    "0000000", -- 0x2C unused
    "0000000", -- 0x2D unused
    "0000000", -- 0x2E unused
    "0000000", -- 0x2F unused
    
    -- Tutte le altre istruzioni non definite (da 0x30 in poi) vengono mappate a 0 (comportamento sicuro stile NOP).
    others => "0000000"
  );
                                
  signal IR_opcode : std_logic_vector(OP_CODE_SIZE -1 downto 0);
  signal IR_func   : std_logic_vector(FUNC_SIZE - 1 downto 0);
  signal cw        : std_logic_vector(CW_SIZE - 1 downto 0); 
  
  -- REGISTRI DI PIPELINE INTERNI DELLA CU
  signal cw1 : std_logic_vector(4 downto 0); 
  signal cw2 : std_logic_vector(2 downto 0); 
  signal cw3 : std_logic_vector(1 downto 0); 

  signal aluOpcode_i : aluOp; 
  signal aluOpcode1  : aluOp;

begin 

  IR_opcode <= IR_IN(IR_SIZE - 1 downto IR_SIZE - OP_CODE_SIZE); 
  IR_func   <= IR_IN(FUNC_SIZE - 1 downto 0); 

  cw <= cw_mem(conv_integer(IR_opcode));

  JUMP_EN <= cw(6);
  EQ_COND <= cw(5);

  MUXA_SEL <= cw1(4);
  MUXB_SEL <= cw1(3);
  ALU_OPCODE <= aluOpcode1;
  EX_WB_MUX_SEL_OUT <= cw1(1);
  EX_RF_WE_OUT      <= cw1(0);

  DRAM_WE            <= cw2(2);
  MEM_WB_MUX_SEL_OUT <= cw2(1);
  MEM_RF_WE_OUT      <= cw2(0);
  WB_MUX_SEL         <= cw3(1);
  RF_WE              <= cw3(0);

  -- STALLI E FLUSH DEI REGISTRI DEL DATAPATH
  process(cache_miss_in, load_use_alarm, mispredict_in, branch_stall_alarm)
  begin
      -- Default
      PC_EN        <= '1';
      IF_ID_EN     <= '1';
      ID_EX_EN     <= '1';
      EX_MEM_EN    <= '1';
      MEM_WB_EN    <= '1';
      
      IF_ID_CLEAR  <= '0';
      ID_EX_CLEAR  <= '0';
      EX_MEM_CLEAR <= '0';
      MEM_WB_CLEAR <= '0';

      -- Massima Priorità: Cache Miss (Stallo Totale)
      if cache_miss_in = '1' then
          PC_EN     <= '0';
          IF_ID_EN  <= '0';
          ID_EX_EN  <= '0';
          EX_MEM_EN <= '0';
          MEM_WB_EN <= '0';
          
      -- Load-Use Hazard (Stallo Front-end, Bolla verso Back-end)
      elsif load_use_alarm = '1' then
          PC_EN       <= '0';
          IF_ID_EN    <= '0';
          ID_EX_CLEAR <= '1'; -- Inserisce una NOP nel Datapath verso Execute

      elsif branch_stall_alarm = '1' then
          PC_EN       <= '0';
          IF_ID_EN    <= '0';
          ID_EX_CLEAR <= '1'; -- Inserisce una NOP nel Datapath verso Execute
    
      -- Branch Mispredict (Nessuno stallo, solo Flush del Fetch)
      elsif mispredict_in = '1' then
          IF_ID_CLEAR <= '1'; -- Butta via l'istruzione sbagliata pescata da IF
      end if;
  end process;


  -- PIPELINE INTERNA DEI SEGNALI DI CONTROLLO
  CW_PIPE: process (Clk, Rst)
  begin 
    if Rst = '0' then 
      cw1 <= (others => '0');
      cw2 <= (others => '0');
      cw3 <= (others => '0');
      aluOpcode1 <= NOP;
      
    elsif rising_edge(Clk) then
      
      -- Se c'è un Miss della Cache, TUTTA la pipeline interna si congela (mantiene i vecchi valori).
      -- Avanziamo i segnali solo se NON c'è un cache miss.
      if cache_miss_in = '0' then
          
          -- I registri verso la fine avanzano sempre (MEM e WB non vengono mai stallati dal Load-Use)
          cw2 <= cw1(2 downto 0);
          cw3 <= cw2(1 downto 0);

          -- Gestione dello stadio EX (cw1)
          if load_use_alarm = '1' or branch_stall_alarm = '1' then
            -- Se abbiamo stallato il Fetch/Decode per un Load-Use o il branch hazard, dobbiamo mandare 
            -- una "bolla" di controllo (tutti zeri = NOP) verso Execute.
            cw1 <= (others => '0');
            aluOpcode1 <= NOP;
          else
            -- Condizione normale: campiona l'istruzione da ID a EX
            cw1 <= cw(4 downto 0);
            aluOpcode1 <= aluOpcode_i;
          end if;
          
      end if;
      
    end if;
  end process CW_PIPE;

  ALU_OP_CODE_P : process (IR_opcode, IR_func)
   begin  -- process ALU_OP_CODE_P
	case conv_integer(unsigned(IR_opcode)) is

    -- case of R type requires analysis of FUNC
		when 0 =>
			case conv_integer(unsigned(IR_func)) is
				when 16#04# => aluOpcode_i <= LLS;  -- sll
				when 16#06# => aluOpcode_i <= LRS;  -- srl
				when 16#20# => aluOpcode_i <= ADDS; -- add
				when 16#22# => aluOpcode_i <= SUBS; -- sub
				when 16#24# => aluOpcode_i <= ANDS; -- and
				when 16#25# => aluOpcode_i <= ORS;  -- or
				when 16#26# => aluOpcode_i <= XORS; -- xor
				when 16#29# => aluOpcode_i <= SNES; -- sne
				when 16#2C# => aluOpcode_i <= SLES; -- sle
				when 16#2D# => aluOpcode_i <= SGES; -- sge
				when others => aluOpcode_i <= NOP;
			end case;

		-- Jumps / branches: Calcolo target e condizione eseguiti in ID
        when 16#02# => aluOpcode_i <= NOP;  -- j    (target calcolato in ID)
        when 16#03# => aluOpcode_i <= ADDS; -- jal  (passa NPC tramite ALU con IMM forzato a 0 nel DP per WB in R31)
        when 16#04# => aluOpcode_i <= NOP;  -- beqz (zero-compare e target calcolati in ID)
        when 16#05# => aluOpcode_i <= NOP;  -- bnez (not-zero-compare e target calcolati in ID)

		-- I-type ALU operations
		when 16#08# => aluOpcode_i <= ADDS; -- addi
		when 16#0A# => aluOpcode_i <= SUBS; -- subi
		when 16#0C# => aluOpcode_i <= ANDS; -- andi
		when 16#0D# => aluOpcode_i <= ORS;  -- ori
		when 16#0E# => aluOpcode_i <= XORS; -- xori
		when 16#14# => aluOpcode_i <= LLS;  -- slli
		when 16#15# => aluOpcode_i <= NOP;  -- nop
		when 16#16# => aluOpcode_i <= LRS;  -- srli
		when 16#19# => aluOpcode_i <= SNES; -- snei
		when 16#1C# => aluOpcode_i <= SLES; -- slei
		when 16#1D# => aluOpcode_i <= SGES; -- sgei

		-- Memory access: ALU computes the effective address
		when 16#23# => aluOpcode_i <= ADDS; -- lw
		when 16#2B# => aluOpcode_i <= ADDS; -- sw

		when others => aluOpcode_i <= NOP;
	 end case;
	end process ALU_OP_CODE_P;

end dlx_cu_hw;
