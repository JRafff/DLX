library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_if is
end tb_if;

architecture TEST of tb_if is

  constant IR_SIZE : integer := 32;
  constant PC_SIZE : integer := 32;

  component IFStage
    generic (IR_SIZE : integer := 32; PC_SIZE : integer := 32);
    port (
      Clk           : in  std_logic;
      Rst           : in  std_logic;
      PC_LATCH_EN   : in  std_logic;
      IR_LATCH_EN   : in  std_logic;
      NPC_LATCH_EN  : in  std_logic;
      PC_SEL        : in  std_logic;
      IRAM_DOut     : in  std_logic_vector(IR_SIZE-1 downto 0);
      JUMP_TARGET   : in  std_logic_vector(PC_SIZE-1 downto 0);
      PC_OUT        : out std_logic_vector(PC_SIZE-1 downto 0);
      NPC_OUT       : out std_logic_vector(PC_SIZE-1 downto 0);
      IR_OUT        : out std_logic_vector(IR_SIZE-1 downto 0)
    );
  end component;

  component IRAM
    generic (RAM_DEPTH : integer := 48; I_SIZE : integer := 32);
    port (
      Rst  : in  std_logic;
      Addr : in  std_logic_vector(I_SIZE - 1 downto 0);
      Dout : out std_logic_vector(I_SIZE - 1 downto 0)
    );
  end component;

  signal Clk : std_logic := '0';
  signal Rst : std_logic := '0';
  signal PC_LATCH_EN, IR_LATCH_EN, NPC_LATCH_EN : std_logic := '1';
  signal PC_SEL      : std_logic := '0';
  signal JUMP_TARGET : std_logic_vector(PC_SIZE-1 downto 0) := (others => '0');

  signal PC_OUT   : std_logic_vector(PC_SIZE-1 downto 0);
  signal NPC_OUT  : std_logic_vector(PC_SIZE-1 downto 0);
  signal IR_OUT   : std_logic_vector(IR_SIZE-1 downto 0);
  signal IRAM_DOut: std_logic_vector(IR_SIZE-1 downto 0);

  procedure check_eq_slv (
    signal   got : in  std_logic_vector;
    constant exp : in  std_logic_vector;
    constant tag : in  string) is
  begin
    assert got = exp
      report "FAIL " & tag
      severity error;
  end procedure;

begin

  DUT: IFStage
    generic map (IR_SIZE => IR_SIZE, PC_SIZE => PC_SIZE)
    port map (
      Clk => Clk, Rst => Rst,
      PC_LATCH_EN => PC_LATCH_EN, IR_LATCH_EN => IR_LATCH_EN, NPC_LATCH_EN => NPC_LATCH_EN,
      PC_SEL => PC_SEL,
      IRAM_DOut => IRAM_DOut,
      JUMP_TARGET => JUMP_TARGET,
      PC_OUT => PC_OUT, NPC_OUT => NPC_OUT, IR_OUT => IR_OUT
    );

  IRAM_I: IRAM
    generic map (RAM_DEPTH => 48, I_SIZE => IR_SIZE)
    port map (Rst => Rst, Addr => PC_OUT, Dout => IRAM_DOut);

  CLKP: process
  begin
    Clk <= '0'; wait for 0.5 ns;
    Clk <= '1'; wait for 0.5 ns;
  end process;

  STIM: process
  begin
    -- reset pulse (active low)
    Rst <= '0';
    wait for 2 ns;
    Rst <= '1';

    -- After reset PC=0, so IRAM addresses word 0 = AAAAAAA1.
    -- Wait a couple of full cycles so PC has been latched once and IR sees the fetched word.
    wait until rising_edge(Clk);
    wait for 0.1 ns;

    -- After the first rising edge past reset:
    --   PC_reg     : moved from 0 to 4 (was 0, PC+4=4, latched)
    --   IR         : latched IRam_DOut sampled at PC=0 -> AAAAAAA1
    --   NPC        : latched PC+4 that was 4 -> 4
    check_eq_slv(PC_OUT,  std_logic_vector(to_unsigned(4, PC_SIZE)),  "PC after 1st cycle");
    check_eq_slv(IR_OUT,  x"AAAAAAA1",                                "IR after 1st cycle");
    check_eq_slv(NPC_OUT, std_logic_vector(to_unsigned(4, PC_SIZE)),  "NPC after 1st cycle");

    -- Second cycle: PC 4 -> 8, IR = word at PC=4 = BBBBBBB2, NPC = 8
    wait until rising_edge(Clk);
    wait for 0.1 ns;
    check_eq_slv(PC_OUT,  std_logic_vector(to_unsigned(8, PC_SIZE)),  "PC after 2nd cycle");
    check_eq_slv(IR_OUT,  x"BBBBBBB2",                                "IR after 2nd cycle");
    check_eq_slv(NPC_OUT, std_logic_vector(to_unsigned(8, PC_SIZE)),  "NPC after 2nd cycle");

    -- Third cycle: PC 8 -> 12, IR = CCCCCCC3, NPC = 12
    wait until rising_edge(Clk);
    wait for 0.1 ns;
    check_eq_slv(PC_OUT,  std_logic_vector(to_unsigned(12, PC_SIZE)), "PC after 3rd cycle");
    check_eq_slv(IR_OUT,  x"CCCCCCC3",                                "IR after 3rd cycle");
    check_eq_slv(NPC_OUT, std_logic_vector(to_unsigned(12, PC_SIZE)), "NPC after 3rd cycle");

    -- Freeze IR next cycle by lowering IR_LATCH_EN: IR should stay CCCCCCC3
    IR_LATCH_EN <= '0';
    wait until rising_edge(Clk);
    wait for 0.1 ns;
    check_eq_slv(PC_OUT, std_logic_vector(to_unsigned(16, PC_SIZE)), "PC keeps advancing");
    check_eq_slv(IR_OUT, x"CCCCCCC3",                                "IR frozen when IR_LATCH_EN=0");
    IR_LATCH_EN <= '1';

    -- Test PC_SEL: force JUMP_TARGET = 0x00000020, then PC should jump to that address
    JUMP_TARGET <= x"00000020";
    PC_SEL      <= '1';
    wait until rising_edge(Clk);
    wait for 0.1 ns;
    PC_SEL      <= '0';
    check_eq_slv(PC_OUT, x"00000020", "PC redirected by PC_SEL");

    -- Next cycle: after jump PC=0x20 (word 8), our IRAM has garbage there because
    -- test.asm.mem only defines 5 words. Just check that PC advances again by 4.
    wait until rising_edge(Clk);
    wait for 0.1 ns;
    check_eq_slv(PC_OUT, x"00000024", "PC+4 after jump");

    report "IFStage testbench complete." severity note;
    wait;
  end process STIM;

end TEST;

configuration CFG_TB_IF of tb_if is
  for TEST
  end for;
end CFG_TB_IF;
