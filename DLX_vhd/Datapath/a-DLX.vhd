library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all;

entity DLX is
  generic (
    IR_SIZE      : integer := 32;       
    PC_SIZE      : integer := 32        
    );                        
  port (
    Clk : in std_logic;
    Rst : in std_logic);                
end DLX;

architecture dlx_rtl of DLX is

  -- Instruction Ram
  component IRAM
    port (
      Rst  : in  std_logic;
      Addr : in  std_logic_vector(PC_SIZE - 1 downto 0);
      Dout : out std_logic_vector(IR_SIZE - 1 downto 0)
    );
  end component;

  -- Datapath 
  component Datapath
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        Clk             : in  std_logic;
        Rst             : in  std_logic;
        IRAM_DOut       : in  std_logic_vector(N-1 downto 0);
        PC_OUT          : out std_logic_vector(N-1 downto 0);
        IR_OUT_CU       : out std_logic_vector(N-1 downto 0);
        PC_LATCH_EN     : in  std_logic;
        IR_LATCH_EN     : in  std_logic;
        NPC_LATCH_EN    : in  std_logic;
        JUMP_EN         : in  std_logic;
        RegA_LATCH_EN   : in  std_logic;
        RegB_LATCH_EN   : in  std_logic;
        RegIMM_LATCH_EN : in  std_logic;
        MUXA_SEL        : in  std_logic;
        MUXB_SEL        : in  std_logic;
        ALU_OPCODE      : in  aluOp;
        ALU_OUTREG_EN   : in  std_logic;
        EQ_COND         : in  std_logic;
        DRAM_WE         : in  std_logic;
        LMD_LATCH_EN    : in  std_logic;
        WB_MUX_SEL      : in  std_logic;
        RF_WE           : in  std_logic
    );
  end component;
  
  -- Control Unit
  component dlx_cu
    generic (
      MICROCODE_MEM_SIZE :     integer := 10;  
      FUNC_SIZE          :     integer := 11;  
      OP_CODE_SIZE       :     integer := 6;  
      IR_SIZE            :     integer := 32;      
      CW_SIZE            :     integer := 15
    );  
    port (
      Clk                : in  std_logic;  
      Rst                : in  std_logic;  
      IR_IN              : in  std_logic_vector(IR_SIZE - 1 downto 0);
      IR_LATCH_EN        : out std_logic;  
      NPC_LATCH_EN       : out std_logic;
      RegA_LATCH_EN      : out std_logic;  
      RegB_LATCH_EN      : out std_logic;  
      RegIMM_LATCH_EN    : out std_logic;  
      MUXA_SEL           : out std_logic;  
      MUXB_SEL           : out std_logic;  
      ALU_OUTREG_EN      : out std_logic;  
      EQ_COND            : out std_logic;  
      ALU_OPCODE         : out aluOp; 
      DRAM_WE            : out std_logic;  
      LMD_LATCH_EN       : out std_logic;  
      JUMP_EN            : out std_logic;  
      PC_LATCH_EN        : out std_logic;  
      WB_MUX_SEL         : out std_logic;  
      RF_WE              : out std_logic
    );
  end component;


  -- Bus 
  signal pc_to_iram    : std_logic_vector(PC_SIZE - 1 downto 0);
  signal iram_to_dp    : std_logic_vector(IR_SIZE - 1 downto 0);
  signal ir_to_cu      : std_logic_vector(IR_SIZE - 1 downto 0);

  -- Control Unit Bus signals
  signal IR_LATCH_EN_i     : std_logic;
  signal NPC_LATCH_EN_i    : std_logic;
  signal RegA_LATCH_EN_i   : std_logic;
  signal RegB_LATCH_EN_i   : std_logic;
  signal RegIMM_LATCH_EN_i : std_logic;
  signal EQ_COND_i         : std_logic;
  signal JUMP_EN_i         : std_logic;
  signal ALU_OPCODE_i      : aluOp;
  signal MUXA_SEL_i        : std_logic;
  signal MUXB_SEL_i        : std_logic;
  signal ALU_OUTREG_EN_i   : std_logic;
  signal DRAM_WE_i         : std_logic;
  signal LMD_LATCH_EN_i    : std_logic;
  signal PC_LATCH_EN_i     : std_logic;
  signal WB_MUX_SEL_i      : std_logic;
  signal RF_WE_i           : std_logic;

begin

    -- Riceve l'indirizzo (PC) dal Datapath e fornisce l'istruzione
    IRAM_I: IRAM
      port map (
          Rst  => Rst,
          Addr => pc_to_iram,
          Dout => iram_to_dp
      );

    -- Riceve l'istruzione decodificata dal Datapath e genera i segnali
    CU_I: dlx_cu
      port map (
          Clk             => Clk,
          Rst             => Rst,
          IR_IN           => ir_to_cu,
          IR_LATCH_EN     => IR_LATCH_EN_i,
          NPC_LATCH_EN    => NPC_LATCH_EN_i,
          RegA_LATCH_EN   => RegA_LATCH_EN_i,
          RegB_LATCH_EN   => RegB_LATCH_EN_i,
          RegIMM_LATCH_EN => RegIMM_LATCH_EN_i,
          MUXA_SEL        => MUXA_SEL_i,
          MUXB_SEL        => MUXB_SEL_i,
          ALU_OUTREG_EN   => ALU_OUTREG_EN_i,
          EQ_COND         => EQ_COND_i,
          ALU_OPCODE      => ALU_OPCODE_i,
          DRAM_WE         => DRAM_WE_i,
          LMD_LATCH_EN    => LMD_LATCH_EN_i,
          JUMP_EN         => JUMP_EN_i,
          PC_LATCH_EN     => PC_LATCH_EN_i,
          WB_MUX_SEL      => WB_MUX_SEL_i,
          RF_WE           => RF_WE_i
      );

-- riceve l'istruzione, esegue i calcoli e 
    
    DP_I: Datapath
      generic map (
          N        => PC_SIZE,
          REG_ADDR => 5
      )
      port map (
          Clk             => Clk,
          Rst             => Rst,
          
          -- Connessioni con la IRAM
          IRAM_DOut       => iram_to_dp,
          PC_OUT          => pc_to_iram,
          
          -- Connessione verso la Control Unit
          IR_OUT_CU       => ir_to_cu,
          
          -- Segnali di Controllo dalla CU
          PC_LATCH_EN     => PC_LATCH_EN_i,
          IR_LATCH_EN     => IR_LATCH_EN_i,
          NPC_LATCH_EN    => NPC_LATCH_EN_i,
          JUMP_EN         => JUMP_EN_i,
          RegA_LATCH_EN   => RegA_LATCH_EN_i,
          RegB_LATCH_EN   => RegB_LATCH_EN_i,
          RegIMM_LATCH_EN => RegIMM_LATCH_EN_i,
          MUXA_SEL        => MUXA_SEL_i,
          MUXB_SEL        => MUXB_SEL_i,
          ALU_OPCODE      => ALU_OPCODE_i,
          ALU_OUTREG_EN   => ALU_OUTREG_EN_i,
          EQ_COND         => EQ_COND_i,
          DRAM_WE         => DRAM_WE_i,
          LMD_LATCH_EN    => LMD_LATCH_EN_i,
          WB_MUX_SEL      => WB_MUX_SEL_i,
          RF_WE           => RF_WE_i
      );
    
end dlx_rtl;