library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Instruction Decode stage of the DLX pipeline.
--
-- Contains:
--   - Register File (RF): comb read on RS1/RS2, sync write from WB
--   - Immediate generator (ImmGen): sign/zero-extend + JAL trick
--   - Jump-target adder in ID (NPC + IMM_raw)  <-- chosen placement
--   - Destination register selector (R-type / I-type / JAL)
--   - ID/EX pipeline registers:
--         RegA        : latched RF port 1
--         RegB        : latched RF port 2
--         RegIMM      : latched immediate for MUXB (with JAL trick)
--         JUMP_TARGET : latched output of the ID adder
--         NPC         : forwarded NPC
--         OPCODE      : forwarded 6-bit opcode
--         RD_DEST     : selected destination register
--
-- Control from CU (stage 2 - ID):
--   RegA_LATCH_EN, RegB_LATCH_EN, RegIMM_LATCH_EN
--   -> the auxiliary registers (JUMP_TARGET, NPC, OPCODE, RD_DEST) use
--      aux_en = OR of the three, so they latch whenever ID is doing
--      anything meaningful (NOP has all three low -> aux_en = 0).
--
-- RF write port is exposed to the outside so WB can drive it.
entity IDStage is
  generic (
    IR_SIZE  : integer := 32;
    N        : integer := 32;
    REG_ADDR : integer := 5
  );
  port (
    Clk : in std_logic;
    Rst : in std_logic;                                  -- active low

    -- Control signals from CU (stage 2)
    RegA_LATCH_EN   : in std_logic;
    RegB_LATCH_EN   : in std_logic;
    RegIMM_LATCH_EN : in std_logic;

    -- From IF/ID pipeline
    IR_IN  : in std_logic_vector(IR_SIZE-1 downto 0);
    NPC_IN : in std_logic_vector(N-1 downto 0);

    -- RF write port (driven by WB stage during integration)
    RF_WE       : in std_logic;
    WB_DATA     : in std_logic_vector(N-1 downto 0);
    WB_DEST_REG : in std_logic_vector(REG_ADDR-1 downto 0);

    -- Outputs to EX (all latched at end of ID)
    RegA_OUT       : out std_logic_vector(N-1 downto 0);
    RegB_OUT       : out std_logic_vector(N-1 downto 0);
    RegIMM_OUT     : out std_logic_vector(N-1 downto 0);
    JUMP_TARGET_OUT: out std_logic_vector(N-1 downto 0);
    NPC_OUT        : out std_logic_vector(N-1 downto 0);
    OPCODE_OUT     : out std_logic_vector(5 downto 0);
    RD_OUT         : out std_logic_vector(REG_ADDR-1 downto 0)
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

  component reg_en
    generic (NBIT : integer := 32);
    port (
      Clk : in  std_logic;
      Rst : in  std_logic;
      EN  : in  std_logic;
      D   : in  std_logic_vector(NBIT-1 downto 0);
      Q   : out std_logic_vector(NBIT-1 downto 0)
    );
  end component;

  -- decoded fields from IR
  signal opcode  : std_logic_vector(5 downto 0);
  signal rs1     : std_logic_vector(REG_ADDR-1 downto 0);
  signal rs2     : std_logic_vector(REG_ADDR-1 downto 0);
  signal rd_sel  : std_logic_vector(REG_ADDR-1 downto 0);

  -- RF read outputs
  signal rf_out1, rf_out2 : std_logic_vector(N-1 downto 0);

  -- ImmGen outputs
  signal imm_raw, imm_muxB : std_logic_vector(N-1 downto 0);

  -- jump-target adder result (combinatorial)
  signal jump_target_comb : std_logic_vector(N-1 downto 0);

  -- aux enable for OPCODE / RD / NPC / JUMP_TARGET pipeline registers
  signal aux_en : std_logic;

begin

  ------------------------------------------------------------------
  -- Combinatorial decode of IR fields
  ------------------------------------------------------------------
  opcode <= IR_IN(IR_SIZE-1 downto IR_SIZE-6);
  rs1    <= IR_IN(25 downto 21);
  rs2    <= IR_IN(20 downto 16);

  -- Destination register:
  --   R-type (0x00) -> IR[15:11]
  --   JAL    (0x03) -> R31 forzato
  --   else          -> IR[20:16]  (I-type ALU, LW)
  rd_sel <= IR_IN(15 downto 11) when opcode = "000000" else
            "11111"              when opcode = "000011" else
            IR_IN(20 downto 16);

  aux_en <= RegA_LATCH_EN or RegB_LATCH_EN or RegIMM_LATCH_EN;

  ------------------------------------------------------------------
  -- Register File
  ------------------------------------------------------------------
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

  ------------------------------------------------------------------
  -- Immediate generator (IMM_OUT = raw ext, IMM_TO_MUXB = JAL-tricked)
  ------------------------------------------------------------------
  IMM_I: ImmGen
    generic map (IR_SIZE => IR_SIZE, N => N)
    port map (
      IR          => IR_IN,
      IMM_OUT     => imm_raw,
      IMM_TO_MUXB => imm_muxB
    );

  ------------------------------------------------------------------
  -- Jump-target adder in ID:  jump_target = NPC + IMM_raw
  -- Kogge-Stone (same family used by the ALU main adder) so the ID
  -- combinational path stays balanced with the EX path.
  ------------------------------------------------------------------
  JT_ADDER: entity work.koggle_stone_adder
    generic map (N => N, lev => 5)
    port map (
      A    => NPC_IN,
      B    => imm_raw,
      cin  => '0',
      S    => jump_target_comb,
      cout => open
    );

  ------------------------------------------------------------------
  -- ID/EX pipeline registers (all N-bit unless noted)
  ------------------------------------------------------------------
  RegA_R: reg_en
    generic map (NBIT => N)
    port map (Clk => Clk, Rst => Rst, EN => RegA_LATCH_EN,   D => rf_out1,          Q => RegA_OUT);

  RegB_R: reg_en
    generic map (NBIT => N)
    port map (Clk => Clk, Rst => Rst, EN => RegB_LATCH_EN,   D => rf_out2,          Q => RegB_OUT);

  RegIMM_R: reg_en
    generic map (NBIT => N)
    port map (Clk => Clk, Rst => Rst, EN => RegIMM_LATCH_EN, D => imm_muxB,         Q => RegIMM_OUT);

  JT_R: reg_en
    generic map (NBIT => N)
    port map (Clk => Clk, Rst => Rst, EN => aux_en,          D => jump_target_comb, Q => JUMP_TARGET_OUT);

  NPC_R: reg_en
    generic map (NBIT => N)
    port map (Clk => Clk, Rst => Rst, EN => aux_en,          D => NPC_IN,           Q => NPC_OUT);

  OPCODE_R: reg_en
    generic map (NBIT => 6)
    port map (Clk => Clk, Rst => Rst, EN => aux_en,          D => opcode,           Q => OPCODE_OUT);

  RD_R: reg_en
    generic map (NBIT => REG_ADDR)
    port map (Clk => Clk, Rst => Rst, EN => aux_en,          D => rd_sel,           Q => RD_OUT);

end STRUCTURAL;

configuration CFG_ID_STRUCTURAL of IDStage is
  for STRUCTURAL
  end for;
end configuration;
