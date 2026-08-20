library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Instruction Fetch stage of the DLX pipeline.
--
-- Contains:
--   - Program Counter register (PC)
--   - PC + 4 adder (built on the Kogge-Stone from DP_v2)
--   - PC input mux: PC + 4  vs  jump_target
--       (selected by JUMP_EN AND (uncond OR branch_taken); we get the composite
--        select directly from the caller as PC_SEL, so no branch logic here)
--   - IR register (holds the instruction fetched from IRAM)
--   - NPC register (holds PC + 4, forwarded to later stages for JAL/target math)
--
-- Interface with the CU (Cu_v2):
--   PC_LATCH_EN  : always '1' in the current CW encoding
--   IR_LATCH_EN  : latch IRAM_DOut into IR
--   NPC_LATCH_EN : latch PC+4 into NPC
--
-- Interface with the outside:
--   IRAM_DOut   : instruction word coming from IRAM at address PC_OUT
--   JUMP_TARGET : jump/branch target computed in EX (kept at 0 until we wire EX)
--   PC_SEL      : 0 -> use PC+4, 1 -> use JUMP_TARGET
entity IFStage is
  generic (
    IR_SIZE : integer := 32;
    PC_SIZE : integer := 32
  );
  port (
    Clk           : in  std_logic;
    Rst           : in  std_logic;                                     -- active low
    -- Control signals from CU
    PC_LATCH_EN   : in  std_logic;
    IR_LATCH_EN   : in  std_logic;
    NPC_LATCH_EN  : in  std_logic;
    PC_SEL        : in  std_logic;
    -- Data ports
    IRAM_DOut     : in  std_logic_vector(IR_SIZE-1 downto 0);
    JUMP_TARGET   : in  std_logic_vector(PC_SIZE-1 downto 0);
    -- Outputs
    PC_OUT        : out std_logic_vector(PC_SIZE-1 downto 0);          -- to IRAM Addr
    NPC_OUT       : out std_logic_vector(PC_SIZE-1 downto 0);          -- to ID/EX
    IR_OUT        : out std_logic_vector(IR_SIZE-1 downto 0)           -- to CU + ID
  );
end IFStage;

architecture STRUCTURAL of IFStage is

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

  signal PC_reg    : std_logic_vector(PC_SIZE-1 downto 0);   -- current PC
  signal PC_plus4  : std_logic_vector(PC_SIZE-1 downto 0);   -- PC + 4
  signal PC_next   : std_logic_vector(PC_SIZE-1 downto 0);   -- input of PC register
  signal four_c    : std_logic_vector(PC_SIZE-1 downto 0);

begin

  four_c <= std_logic_vector(to_unsigned(4, PC_SIZE));

  -- PC + 4 (ripple-carry adder from DP_v3/rca_generic.vhd, BEHAVIORAL arch)
  PC_ADDER: entity work.RCA_GENERIC(BEHAVIORAL)
    generic map (NBIT => PC_SIZE)
    port map (
      A  => PC_reg,
      B  => four_c,
      Ci => '0',
      S  => PC_plus4,
      Co => open
    );

  -- PC input mux: PC + 4 (default) or jump target
  PC_next <= JUMP_TARGET when PC_SEL = '1' else PC_plus4;

  -- PC register
  PC_R: reg_en
    generic map (NBIT => PC_SIZE)
    port map (Clk => Clk, Rst => Rst, EN => PC_LATCH_EN, D => PC_next, Q => PC_reg);

  -- NPC register (PC + 4 saved for later stages)
  NPC_R: reg_en
    generic map (NBIT => PC_SIZE)
    port map (Clk => Clk, Rst => Rst, EN => NPC_LATCH_EN, D => PC_plus4, Q => NPC_OUT);

  -- IR register (instruction from IRAM)
  IR_R: reg_en
    generic map (NBIT => IR_SIZE)
    port map (Clk => Clk, Rst => Rst, EN => IR_LATCH_EN, D => IRAM_DOut, Q => IR_OUT);

  PC_OUT <= PC_reg;

end STRUCTURAL;

configuration CFG_IF_STRUCTURAL of IFStage is
  for STRUCTURAL
  end for;
end configuration;
