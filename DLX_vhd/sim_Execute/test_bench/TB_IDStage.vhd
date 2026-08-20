library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_idstage is
end tb_idstage;

architecture TEST of tb_idstage is

  constant IR_SIZE  : integer := 32;
  constant N        : integer := 32;
  constant REG_ADDR : integer := 5;

  component IDStage
    generic (IR_SIZE : integer := 32; N : integer := 32; REG_ADDR : integer := 5);
    port (
      Clk : in std_logic;
      Rst : in std_logic;
      RegA_LATCH_EN   : in std_logic;
      RegB_LATCH_EN   : in std_logic;
      RegIMM_LATCH_EN : in std_logic;
      IR_IN  : in std_logic_vector(IR_SIZE-1 downto 0);
      NPC_IN : in std_logic_vector(N-1 downto 0);
      RF_WE       : in std_logic;
      WB_DATA     : in std_logic_vector(N-1 downto 0);
      WB_DEST_REG : in std_logic_vector(REG_ADDR-1 downto 0);
      RegA_OUT       : out std_logic_vector(N-1 downto 0);
      RegB_OUT       : out std_logic_vector(N-1 downto 0);
      RegIMM_OUT     : out std_logic_vector(N-1 downto 0);
      JUMP_TARGET_OUT: out std_logic_vector(N-1 downto 0);
      NPC_OUT        : out std_logic_vector(N-1 downto 0);
      OPCODE_OUT     : out std_logic_vector(5 downto 0);
      RD_OUT         : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  -- DUT signals
  signal Clk : std_logic := '0';
  signal Rst : std_logic := '0';
  signal RegA_LATCH_EN, RegB_LATCH_EN, RegIMM_LATCH_EN : std_logic := '0';
  signal IR_IN  : std_logic_vector(IR_SIZE-1 downto 0) := (others => '0');
  signal NPC_IN : std_logic_vector(N-1 downto 0)       := (others => '0');
  signal RF_WE  : std_logic := '0';
  signal WB_DATA     : std_logic_vector(N-1 downto 0)       := (others => '0');
  signal WB_DEST_REG : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');

  signal RegA_OUT, RegB_OUT, RegIMM_OUT, JUMP_TARGET_OUT, NPC_OUT
    : std_logic_vector(N-1 downto 0);
  signal OPCODE_OUT : std_logic_vector(5 downto 0);
  signal RD_OUT     : std_logic_vector(REG_ADDR-1 downto 0);

  -- Helpers
  function slv32(x : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(x, N));
  end function;

  function slv5(x : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(x, REG_ADDR));
  end function;

  function slv6(x : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(x, 6));
  end function;

  -- Build an R-type IR: opcode(6) | RS1(5) | RS2(5) | RD(5) | SHAMT(5) | FUNC(6)
  function rtype(opcode, rs1, rs2, rd, shamt, func : integer)
    return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(opcode, 6)) &
           std_logic_vector(to_unsigned(rs1,    5)) &
           std_logic_vector(to_unsigned(rs2,    5)) &
           std_logic_vector(to_unsigned(rd,     5)) &
           std_logic_vector(to_unsigned(shamt,  5)) &
           std_logic_vector(to_unsigned(func,   6));
  end function;

  -- Build an I-type IR: opcode(6) | RS1(5) | RD(5) | imm16(16)
  function itype(opcode, rs1, rd, imm16 : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(opcode, 6)) &
           std_logic_vector(to_unsigned(rs1,    5)) &
           std_logic_vector(to_unsigned(rd,     5)) &
           std_logic_vector(to_signed  (imm16, 16));
  end function;

  -- Build a J-type IR: opcode(6) | imm26(26)
  function jtype(opcode, imm26 : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(opcode, 6)) &
           std_logic_vector(to_signed  (imm26, 26));
  end function;

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

  DUT: IDStage
    generic map (IR_SIZE => IR_SIZE, N => N, REG_ADDR => REG_ADDR)
    port map (
      Clk => Clk, Rst => Rst,
      RegA_LATCH_EN   => RegA_LATCH_EN,
      RegB_LATCH_EN   => RegB_LATCH_EN,
      RegIMM_LATCH_EN => RegIMM_LATCH_EN,
      IR_IN => IR_IN, NPC_IN => NPC_IN,
      RF_WE => RF_WE, WB_DATA => WB_DATA, WB_DEST_REG => WB_DEST_REG,
      RegA_OUT => RegA_OUT, RegB_OUT => RegB_OUT,
      RegIMM_OUT => RegIMM_OUT, JUMP_TARGET_OUT => JUMP_TARGET_OUT,
      NPC_OUT => NPC_OUT, OPCODE_OUT => OPCODE_OUT, RD_OUT => RD_OUT
    );

  CLKP: process
  begin
    Clk <= '0'; wait for 0.5 ns;
    Clk <= '1'; wait for 0.5 ns;
  end process;

  STIM: process
  begin
    ------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------
    Rst <= '0';
    wait for 2 ns;
    Rst <= '1';
    wait until rising_edge(Clk);
    wait for 0.1 ns;

    ------------------------------------------------------------------
    -- Phase 1: preload RF via write-back port
    -- r1 = 100, r2 = -7, r5 = 42
    ------------------------------------------------------------------
    RF_WE <= '1';
    -- write r1 = 100
    WB_DEST_REG <= slv5(1); WB_DATA <= slv32(100);
    wait until rising_edge(Clk); wait for 0.1 ns;

    -- write r2 = -7
    WB_DEST_REG <= slv5(2); WB_DATA <= slv32(-7);
    wait until rising_edge(Clk); wait for 0.1 ns;

    -- write r5 = 42
    WB_DEST_REG <= slv5(5); WB_DATA <= slv32(42);
    wait until rising_edge(Clk); wait for 0.1 ns;

    -- attempt to write r0 = 0xDEADBEEF: RF must ignore it (R0 hardwired)
    WB_DEST_REG <= slv5(0); WB_DATA <= x"DEADBEEF";
    wait until rising_edge(Clk); wait for 0.1 ns;

    RF_WE <= '0';

    ------------------------------------------------------------------
    -- Phase 2: R-type ADD r3, r1, r2  (opcode 0x00, FUNC 0x20)
    -- Expected:
    --   RegA_OUT = 100      (r1)
    --   RegB_OUT = -7       (r2)
    --   RD_OUT   = 3
    --   OPCODE_OUT = 0x00
    --   NPC_OUT  = NPC_IN driven this cycle
    --   RegIMM_OUT unchanged (RegIMM_LATCH_EN=0 for R-type)
    ------------------------------------------------------------------
    IR_IN  <= rtype(16#00#, 1, 2, 3, 0, 16#20#);
    NPC_IN <= x"00000010";                       -- fake NPC = 0x10
    RegA_LATCH_EN   <= '1';
    RegB_LATCH_EN   <= '1';
    RegIMM_LATCH_EN <= '0';                      -- R-type: no immediate
    wait until rising_edge(Clk); wait for 0.1 ns;

    check_eq_slv(RegA_OUT,   slv32(100),        "R-type RegA=r1");
    check_eq_slv(RegB_OUT,   slv32(-7),         "R-type RegB=r2");
    check_eq_slv(RD_OUT,     slv5(3),           "R-type RD=3");
    check_eq_slv(OPCODE_OUT, slv6(16#00#),      "R-type OPCODE=0x00");
    check_eq_slv(NPC_OUT,    x"00000010",       "R-type NPC propagated");

    ------------------------------------------------------------------
    -- Phase 3: I-type  ADDI r6, r1, 10  (opcode 0x08, sign-ext)
    -- Expected:
    --   RegA_OUT   = 100 (r1)
    --   RegIMM_OUT = 10  (sign-ext)
    --   RD_OUT     = 6
    --   OPCODE_OUT = 0x08
    --   JUMP_TARGET_OUT = NPC + IMM = 0x20 + 10 = 0x2A
    ------------------------------------------------------------------
    IR_IN  <= itype(16#08#, 1, 6, 10);
    NPC_IN <= x"00000020";
    RegA_LATCH_EN   <= '1';
    RegB_LATCH_EN   <= '0';                      -- ADDI: no RS2 read
    RegIMM_LATCH_EN <= '1';
    wait until rising_edge(Clk); wait for 0.1 ns;

    check_eq_slv(RegA_OUT,       slv32(100),      "ADDI RegA=r1");
    check_eq_slv(RegIMM_OUT,     slv32(10),       "ADDI RegIMM sign-ext");
    check_eq_slv(RD_OUT,         slv5(6),         "ADDI RD=6");
    check_eq_slv(OPCODE_OUT,     slv6(16#08#),    "ADDI OPCODE=0x08");
    check_eq_slv(NPC_OUT,        x"00000020",     "ADDI NPC propagated");
    check_eq_slv(JUMP_TARGET_OUT, slv32(16#20# + 10),
                                                  "ADDI JT=NPC+IMM");

    ------------------------------------------------------------------
    -- Phase 4: I-type ANDI r7, r1, 0xFFFF  (opcode 0x0C, zero-ext)
    -- Expected: RegIMM_OUT = 0x0000FFFF (zero-ext, NOT sign-ext)
    ------------------------------------------------------------------
    IR_IN  <= itype(16#0C#, 1, 7, -1);           -- imm16 = 0xFFFF
    NPC_IN <= x"00000030";
    RegA_LATCH_EN   <= '1';
    RegB_LATCH_EN   <= '0';
    RegIMM_LATCH_EN <= '1';
    wait until rising_edge(Clk); wait for 0.1 ns;

    check_eq_slv(RegIMM_OUT, x"0000FFFF",         "ANDI zero-ext");
    check_eq_slv(RD_OUT,     slv5(7),             "ANDI RD=7");

    ------------------------------------------------------------------
    -- Phase 5: JAL, imm26 = 200 (opcode 0x03)
    -- Expected:
    --   RegIMM_OUT      = 0     (JAL trick: IMM to MUXB forced to 0)
    --   RD_OUT          = 31    (JAL: R31 forzato)
    --   OPCODE_OUT      = 0x03
    --   JUMP_TARGET_OUT = NPC + 200 = 0x40 + 200 = 0x108
    ------------------------------------------------------------------
    IR_IN  <= jtype(16#03#, 200);
    NPC_IN <= x"00000040";
    RegA_LATCH_EN   <= '0';                      -- JAL: no register read
    RegB_LATCH_EN   <= '0';
    RegIMM_LATCH_EN <= '1';
    wait until rising_edge(Clk); wait for 0.1 ns;

    check_eq_slv(RegIMM_OUT,      slv32(0),      "JAL RegIMM forzato a 0");
    check_eq_slv(RD_OUT,          slv5(31),      "JAL RD=R31");
    check_eq_slv(OPCODE_OUT,      slv6(16#03#),  "JAL OPCODE=0x03");
    check_eq_slv(JUMP_TARGET_OUT, slv32(16#40# + 200),
                                                  "JAL JT=NPC+IMM26");

    ------------------------------------------------------------------
    -- Phase 6: freeze test - RegA_LATCH_EN=0
    -- Drive a new IR that would load a different RegA if enable were '1'.
    -- Expected: RegA_OUT stays at the last latched value (RegA of JAL was 0).
    -- Wait: JAL had RegA_LATCH_EN=0, so RegA was NOT updated then.
    -- Last RegA update was in Phase 4 (ANDI, RegA=100). So RegA_OUT=100.
    ------------------------------------------------------------------
    IR_IN  <= rtype(16#00#, 5, 2, 4, 0, 16#20#); -- add r4, r5, r2 -- would give RegA=42
    NPC_IN <= x"00000050";
    RegA_LATCH_EN   <= '0';                      -- FROZEN
    RegB_LATCH_EN   <= '1';
    RegIMM_LATCH_EN <= '0';
    wait until rising_edge(Clk); wait for 0.1 ns;

    check_eq_slv(RegA_OUT, slv32(100),           "RegA frozen when enable=0");
    check_eq_slv(RegB_OUT, slv32(-7),            "RegB still updated");
    check_eq_slv(RD_OUT,   slv5(4),              "RD updated (aux_en=RegB or ...)");

    report "IDStage testbench complete." severity note;
    wait;
  end process STIM;

end TEST;

configuration CFG_TB_ID of tb_idstage is
  for TEST
  end for;
end CFG_TB_ID;
