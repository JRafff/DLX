library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IDStage is
  generic (
    IR_SIZE  : integer := 32;
    N        : integer := 32;
    REG_ADDR : integer := 5
  );
  port (
    Clk             : in std_logic;
    Rst             : in std_logic; -- active low

    -- Control signals from CU for Branch Resolution
    jump_en         : in std_logic; 
    eq_cond         : in std_logic; 

    -- From IF/ID pipeline
    IR_IN           : in std_logic_vector(IR_SIZE-1 downto 0);
    NPC_IN          : in std_logic_vector(N-1 downto 0);
    PC_IN           : in std_logic_vector(N-1 downto 0); 
    taken_in        : in std_logic; 

    -- Feedback verso IF Stage (Branch Prediction & PC Correction)
    mispredict_out  : out std_logic;
    update_en_out   : out std_logic;
    actual_taken_out: out std_logic;
    recovery_addr_out: out std_logic_vector(N-1 downto 0); 
    pc_update_out   : out std_logic_vector(N-1 downto 0);

    -- RF write port (driven by WB stage)
    RF_WE           : in std_logic;
    WB_DATA         : in std_logic_vector(N-1 downto 0);
    WB_DEST_REG     : in std_logic_vector(REG_ADDR-1 downto 0);

    -- Outputs to ID/EX pipeline register
    RegA_OUT        : out std_logic_vector(N-1 downto 0);
    RegB_OUT        : out std_logic_vector(N-1 downto 0);
    RegIMM_OUT      : out std_logic_vector(N-1 downto 0);
    NPC_OUT         : out std_logic_vector(N-1 downto 0);
    RD_OUT          : out std_logic_vector(REG_ADDR-1 downto 0)
  );
end IDStage;

architecture STRUCTURAL of IDStage is

  component RF
    generic (N : integer := 32; REG_ADDR : integer := 5);
    port (
      CLK     : in  std_logic;
      RESET   : in  std_logic;
      WR      : in  std_logic;
      ADD_WR  : in  std_logic_vector(REG_ADDR-1 downto 0);
      ADD_RD1 : in  std_logic_vector(REG_ADDR-1 downto 0);
      ADD_RD2 : in  std_logic_vector(REG_ADDR-1 downto 0);
      DATAIN  : in  std_logic_vector(N-1 downto 0);
      OUT1    : out std_logic_vector(N-1 downto 0);
      OUT2    : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component ImmGen
    generic (IR_SIZE : integer := 32; N : integer := 32);
    port (
      IR          : in  std_logic_vector(IR_SIZE-1 downto 0);
      IMM_OUT     : out std_logic_vector(N-1 downto 0);
      IMM_TO_MUXB : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component zero_check is
    generic (
        NBIT : integer := 32
    );
    port (
        D_IN     : in  std_logic_vector(NBIT-1 downto 0);
        OPCODE   : in  std_logic_vector(5 downto 0);
        COND_OUT : out std_logic
    );
  end component;

  component koggle_stone_adder is
    generic (N : integer := 32; lev : integer := 5);
    port (
      A    : in  std_logic_vector(N-1 downto 0);
      B    : in  std_logic_vector(N-1 downto 0);
      cin  : in  std_logic;
      S    : out std_logic_vector(N-1 downto 0);
      cout : out std_logic
    );
  end component;

  component branch_resolution
    port (
      jump_en_in       : in  std_logic;
      eq_cond          : in  std_logic;
      taken_in         : in  std_logic;
      zero_checker_in  : in  std_logic;
      actual_taken_out : out std_logic;
      update_en_out    : out std_logic;
      mispredict_out   : out std_logic
    );
  end component;

  signal opcode  : std_logic_vector(5 downto 0); 
  signal rs1     : std_logic_vector(REG_ADDR-1 downto 0);
  signal rs2     : std_logic_vector(REG_ADDR-1 downto 0);
  signal rd_sel  : std_logic_vector(REG_ADDR-1 downto 0);

  signal rf_out1, rf_out2 : std_logic_vector(N-1 downto 0);
  signal imm_raw, imm_muxB : std_logic_vector(N-1 downto 0);
  signal jump_target_comb : std_logic_vector(N-1 downto 0);
  
  signal zero_checker_sig : std_logic;

begin

  opcode <= IR_IN(IR_SIZE-1 downto IR_SIZE-6);
  rs1    <= IR_IN(25 downto 21);
  rs2    <= IR_IN(20 downto 16);

  rd_sel <= IR_IN(15 downto 11) when opcode = "000000" else
            "11111"              when opcode = "000011" else
            IR_IN(20 downto 16);

  RF_I: RF
    generic map (N => N, REG_ADDR => REG_ADDR)
    port map (
      CLK     => Clk,
      RESET   => Rst,
      WR      => RF_WE,
      ADD_WR  => WB_DEST_REG,
      ADD_RD1 => rs1,
      ADD_RD2 => rs2,
      DATAIN  => WB_DATA,
      OUT1    => rf_out1,
      OUT2    => rf_out2
    );

  IMM_I: ImmGen
    generic map (IR_SIZE => IR_SIZE, N => N)
    port map (
      IR          => IR_IN,
      IMM_OUT     => imm_raw,
      IMM_TO_MUXB => imm_muxB
    );

  JT_ADDER: koggle_stone_adder
    generic map (N => N, lev => 5)
    port map (
      A    => NPC_IN,
      B    => imm_raw,
      cin  => '0',
      S    => jump_target_comb,
      cout => open
    );

  U_ZERO_CHECK: zero_check
    generic map (NBIT => N)
    port map (
      D_IN     => rf_out1,  -- (RegA)
      OPCODE   => opcode,   
      COND_OUT => zero_checker_sig 
    );

  B_RES: branch_resolution
    port map (
      jump_en_in       => jump_en,
      eq_cond          => eq_cond,
      taken_in         => taken_in,
      zero_checker_in  => zero_checker_sig,
      actual_taken_out => actual_taken_out,
      update_en_out    => update_en_out,
      mispredict_out   => mispredict_out
    );

  recovery_addr_out <= jump_target_comb;
  pc_update_out     <= PC_IN;

  RegA_OUT        <= rf_out1;
  RegB_OUT        <= rf_out2;
  RegIMM_OUT      <= imm_muxB;
  NPC_OUT         <= NPC_IN;
  RD_OUT          <= rd_sel;

end STRUCTURAL;