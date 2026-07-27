library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;
--use ieee.numeric_std.all;
--use work.all;

entity dlx_cu is
  generic (
    MICROCODE_MEM_SIZE :     integer := 64;  -- Microcode Memory Size
    FUNC_SIZE          :     integer := 11;  -- Func Field Size for R-Type Ops
    OP_CODE_SIZE       :     integer := 6;  -- Op Code Size
    -- ALU_OPC_SIZE       :     integer := 6;  -- ALU Op Code Word Size
    IR_SIZE            :     integer := 32;  -- Instruction Register Size    
    CW_SIZE            :     integer := 15);  -- Control Word Size
  port (
    Clk                : in  std_logic;  -- Clock
    Rst                : in  std_logic;  -- Reset:Active-Low
    
    -- Instruction Register
    IR_IN              : in  std_logic_vector(IR_SIZE - 1 downto 0);
    
    -- IF Control Signal
    IR_LATCH_EN        : out std_logic;  -- Instruction Register Latch Enable
    NPC_LATCH_EN       : out std_logic;  -- NextProgramCounter Register Latch Enable
    
    -- ID Control Signals
    RegA_LATCH_EN      : out std_logic;  -- Register A Latch Enable
    RegB_LATCH_EN      : out std_logic;  -- Register B Latch Enable
    RegIMM_LATCH_EN    : out std_logic;  -- Immediate Register Latch Enable

    -- EX Control Signals
    MUXA_SEL           : out std_logic;  -- MUX-A Sel
    MUXB_SEL           : out std_logic;  -- MUX-B Sel
    ALU_OUTREG_EN      : out std_logic;  -- ALU Output Register Enable
    EQ_COND            : out std_logic;  -- generic "branch enable" (BEQZ e BNEZ);
                        --if opcode = BNEZ, datapath will negate the condition
    
    -- ALU Operation Code
    ALU_OPCODE         : out aluOp; -- choose between implicit or exlicit coding, like std_logic_vector(ALU_OPC_SIZE -1 downto 0);
    
    -- MEM Control Signals
    DRAM_WE            : out std_logic;  -- Data RAM Write Enable
    LMD_LATCH_EN       : out std_logic;  -- LMD Register Latch Enable
    JUMP_EN            : out std_logic;  -- JUMP Enable Signal for PC input MUX
    PC_LATCH_EN        : out std_logic;  -- Program Counte Latch Enable (Always '1')

    -- WB Control signals
    WB_MUX_SEL         : out std_logic;  -- Write Back MUX Sel
    RF_WE              : out std_logic);  -- Register File Write Enable

end dlx_cu;

architecture dlx_cu_hw of dlx_cu is

  -- Control Word layout (bit 14 .. bit 0):
  --  14 IR_LATCH_EN     (IF)
  --  13 NPC_LATCH_EN    (IF)
  --  12 RegA_LATCH_EN   (ID)
  --  11 RegB_LATCH_EN   (ID)
  --  10 RegIMM_LATCH_EN (ID)
  --   9 MUXA_SEL        (EX)  0->RegA, 1->NPC
  --   8 MUXB_SEL        (EX)  0->RegB, 1->IMM
  --   7 ALU_OUTREG_EN   (EX)
  --   6 EQ_COND         (EX)   generic "branch enable": high for BEQZ and BNEZ;
  --                             the datapath negates the condition when opcode = BNEZ
  --   5 DRAM_WE         (MEM)
  --   4 LMD_LATCH_EN    (MEM)
  --   3 JUMP_EN         (MEM)
  --   2 PC_LATCH_EN     (MEM)  always '1': the PC advances every cycle
  --   1 WB_MUX_SEL      (WB)   0->ALU_OUT, 1->LMD
  --   0 RF_WE           (WB)

  type mem_array is array (integer range 0 to MICROCODE_MEM_SIZE - 1) of std_logic_vector(CW_SIZE - 1 downto 0);
  signal cw_mem : mem_array := (
    -- ------ R-type ------
    "111100010000101", -- 0x00 R-type (add/sub/and/or/xor/sll/srl/sne/sle/sge): RegA+RegB, ALU op, WB from ALU, RF_WE=1
    "000000000000000", -- 0x01 unused
    -- ------ Jumps / branches ------
    "110011110001100", -- 0x02 J:    ALU=NPC+IMM26, JUMP_EN=1, no RF write (EQ_COND=0: unconditional)
    "110011110001101", -- 0x03 JAL:  as J but RF_WE=1; DP writes ALU_OUT (=NPC when IMM forced to 0) into R31 (needs a separate target-adder in the DP)
    "111011111001100", -- 0x04 BEQZ: RegA (zero-compare) + IMM (offset), ALU=NPC+IMM, EQ_COND=1, JUMP_EN=1, no RF write
    "111011111001100", -- 0x05 BNEZ: same CW as BEQZ; the datapath negates the condition because opcode differs
    "000000000000000", -- 0x06 unused (bfpt)
    "000000000000000", -- 0x07 unused (bfpf)
    -- ------ I-type ALU ------
    "111010110000101", -- 0x08 ADDI: RegA + IMM, ALU op, WB from ALU
    "000000000000000", -- 0x09 unused (addui)
    "111010110000101", -- 0x0A SUBI
    "000000000000000", -- 0x0B unused (subui)
    "111010110000101", -- 0x0C ANDI
    "111010110000101", -- 0x0D ORI
    "111010110000101", -- 0x0E XORI
    "000000000000000", -- 0x0F unused (lhi)
    "000000000000000", -- 0x10 unused (rfe)
    "000000000000000", -- 0x11 unused (trap)
    "000000000000000", -- 0x12 unused (jr)
    "000000000000000", -- 0x13 unused (jalr)
    "111010110000101", -- 0x14 SLLI
    "110000000000100", -- 0x15 NOP:  only IF+NPC+PC_LATCH; no ALU, no RF write, no branch
    "111010110000101", -- 0x16 SRLI
    "000000000000000", -- 0x17 unused (srai)
    "000000000000000", -- 0x18 unused (seqi)
    "111010110000101", -- 0x19 SNEI
    "000000000000000", -- 0x1A unused (slti)
    "000000000000000", -- 0x1B unused (sgti)
    "111010110000101", -- 0x1C SLEI
    "111010110000101", -- 0x1D SGEI
    "000000000000000", -- 0x1E unused
    "000000000000000", -- 0x1F unused
    -- ------ Loads / Stores ------
    "000000000000000", -- 0x20 unused (lb)
    "000000000000000", -- 0x21 unused (lh)
    "000000000000000", -- 0x22 unused
    "111010110010111", -- 0x23 LW:   ALU=RegA+IMM (address), LMD_LATCH=1, WB_MUX=1 (LMD), RF_WE=1
    "000000000000000", -- 0x24 unused (lbu)
    "000000000000000", -- 0x25 unused (lhu)
    "000000000000000", -- 0x26 unused (lf)
    "000000000000000", -- 0x27 unused (ld)
    "000000000000000", -- 0x28 unused (sb)
    "000000000000000", -- 0x29 unused (sh)
    "000000000000000", -- 0x2A unused
    "111110110100100", -- 0x2B SW:   RegA (base) + IMM (offset), RegB carries the data to store, DRAM_WE=1, no RF write
    "000000000000000", -- 0x2C unused
    "000000000000000", -- 0x2D unused
    "000000000000000", -- 0x2E unused (sf)
    "000000000000000", -- 0x2F unused (sd)
    "000000000000000", -- 0x30
    "000000000000000", -- 0x31
    "000000000000000", -- 0x32
    "000000000000000", -- 0x33
    "000000000000000", -- 0x34
    "000000000000000", -- 0x35
    "000000000000000", -- 0x36
    "000000000000000", -- 0x37
    "000000000000000", -- 0x38 unused (itlb)
    "000000000000000", -- 0x39
    "000000000000000", -- 0x3A unused (sltui)
    "000000000000000", -- 0x3B unused (sgtui)
    "000000000000000", -- 0x3C unused (sleui)
    "000000000000000", -- 0x3D unused (sgeui)
    "000000000000000", -- 0x3E
    "000000000000000"  -- 0x3F
  );
                                
                                
  signal IR_opcode : std_logic_vector(OP_CODE_SIZE -1 downto 0);  -- OpCode part of IR
  signal IR_func   : std_logic_vector(FUNC_SIZE - 1 downto 0);    -- Func part of IR when Rtype
  signal cw   : std_logic_vector(CW_SIZE - 1 downto 0); -- full control word read from cw_mem


  -- control word is shifted to the correct stage
  signal cw1 : std_logic_vector(CW_SIZE -1 downto 0); -- first stage
  signal cw2 : std_logic_vector(CW_SIZE - 1 - 2 downto 0); -- second stage
  signal cw3 : std_logic_vector(CW_SIZE - 1 - 5 downto 0); -- third stage
  signal cw4 : std_logic_vector(CW_SIZE - 1 - 9 downto 0); -- fourth stage
  signal cw5 : std_logic_vector(CW_SIZE -1 - 13 downto 0); -- fifth stage

  signal aluOpcode_i: aluOp := NOP; -- ALUOP defined in package
  signal aluOpcode1: aluOp := NOP;
  signal aluOpcode2: aluOp := NOP;
  signal aluOpcode3: aluOp := NOP;


 
begin  -- dlx_cu_rtl

  IR_opcode <= IR_IN(IR_SIZE - 1 downto IR_SIZE - OP_CODE_SIZE);  -- 6 bit
  IR_func   <= IR_IN(FUNC_SIZE - 1 downto 0); -- 11 bit 

  cw <= cw_mem(conv_integer(IR_opcode));


  -- stage one control signals
  IR_LATCH_EN  <= cw1(CW_SIZE - 1);
  NPC_LATCH_EN <= cw1(CW_SIZE - 2);
  
  -- stage two control signals
  RegA_LATCH_EN   <= cw2(CW_SIZE - 3);
  RegB_LATCH_EN   <= cw2(CW_SIZE - 4);
  RegIMM_LATCH_EN <= cw2(CW_SIZE - 5);
  
  -- stage three control signals
  MUXA_SEL      <= cw3(CW_SIZE - 6);
  MUXB_SEL      <= cw3(CW_SIZE - 7);
  ALU_OUTREG_EN <= cw3(CW_SIZE - 8);
  EQ_COND       <= cw3(CW_SIZE - 9);
  
  -- stage four control signals
  DRAM_WE      <= cw4(CW_SIZE - 10);
  LMD_LATCH_EN <= cw4(CW_SIZE - 11);
  JUMP_EN      <= cw4(CW_SIZE - 12);
  PC_LATCH_EN  <= cw4(CW_SIZE - 13);
  
  -- stage five control signals
  WB_MUX_SEL <= cw5(CW_SIZE - 14);
  RF_WE      <= cw5(CW_SIZE - 15);


  -- process to pipeline control words
  CW_PIPE: process (Clk, Rst)
  begin  -- process Clk
    if Rst = '0' then                   -- asynchronous reset (active low)
      cw1 <= (others => '0');
      cw2 <= (others => '0');
      cw3 <= (others => '0');
      cw4 <= (others => '0');
      cw5 <= (others => '0');
      aluOpcode1 <= NOP;
      aluOpcode2 <= NOP;
      aluOpcode3 <= NOP;
    elsif Clk'event and Clk = '1' then  -- rising clock edge
      cw1 <= cw;
      cw2 <= cw1(CW_SIZE - 1 - 2 downto 0);
      cw3 <= cw2(CW_SIZE - 1 - 5 downto 0);
      cw4 <= cw3(CW_SIZE - 1 - 9 downto 0);
      cw5 <= cw4(CW_SIZE -1 - 13 downto 0);

      aluOpcode1 <= aluOpcode_i;
      aluOpcode2 <= aluOpcode1;
      aluOpcode3 <= aluOpcode2;
    end if;
  end process CW_PIPE;

  ALU_OPCODE <= aluOpcode3;

  -- purpose: Generation of ALU OpCode
  -- type   : combinational
  -- inputs : IR_i
  -- outputs: aluOpcode
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

		-- Jumps / branches: ALU is used to compute the branch/jump target (NPC + IMM)
		when 16#02# => aluOpcode_i <= ADDS; -- j    (target = NPC + IMM26)
		when 16#03# => aluOpcode_i <= ADDS; -- jal  (target = NPC + IMM26; link value NPC via ALU trick with IMM=0 in the DP)
		when 16#04# => aluOpcode_i <= ADDS; -- beqz (target = NPC + IMM16; zero-compare done in EX)
		when 16#05# => aluOpcode_i <= ADDS; -- bnez (target = NPC + IMM16; not-zero-compare done in EX)

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