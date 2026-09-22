library ieee;
use ieee.std_logic_1164.all;

-- Testbench for DLX-pro: clock, reset, and nothing else.
-- The workload is whatever program sits in test.asm.mem, which the IRAM
-- reads (relative to the simulator's working directory) when reset is
-- released, so pointing the core at a different program is a file copy.
--
-- SIM_CYCLES sets how long the simulation runs. The default is sized for
-- sw/asm/test_pro_stress.asm; longer programs need a larger value, e.g.
--     ghdl  -r ... tb_dlx -gSIM_CYCLES=6000
--     vsim  -gSIM_CYCLES=6000 work.tb_dlx
entity tb_DLX is
    generic (
        SIM_CYCLES : integer := 400
    );
end tb_DLX;

architecture BEHAVIORAL of tb_DLX is

    constant CLK_PERIOD : time := 10 ns;

    component DLX
        generic (
            IR_SIZE  : integer := 32;
            PC_SIZE  : integer := 32;
            REG_ADDR : integer := 5
        );
        port (
            Clk          : in  std_logic;
            Rst          : in  std_logic;
            TEST_PC_OUT  : out std_logic_vector(31 downto 0);
            TEST_ALU_OUT : out std_logic_vector(31 downto 0)
        );
    end component;

    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

    signal test_pc  : std_logic_vector(31 downto 0);
    signal test_alu : std_logic_vector(31 downto 0);

begin

    U1: DLX
        port map (
            Clk          => Clk,
            Rst          => Rst,
            TEST_PC_OUT  => test_pc,
            TEST_ALU_OUT => test_alu
        );

    clk_process : process
    begin
        Clk <= '0';
        wait for CLK_PERIOD / 2;
        Clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_proc: process
    begin
        -- Active-low asynchronous reset held for 2.5 cycles, then released
        Rst <= '0';
        wait for CLK_PERIOD * 2.5;
        Rst <= '1';

        -- Sized for test_pro_stress.asm (45 instructions):
        --   * 5 cycles of IRAM latency on every line miss,
        --   * back-to-back R-type / I-type chains resolved by forwarding,
        --   * one load-use stall and one branch stall,
        --   * BTB training over a 4-iteration backward loop,
        --   * j / jal / final halt loop.
        wait for CLK_PERIOD * SIM_CYCLES;

        assert false report "SIMULATION COMPLETED." severity failure;
    end process;

end BEHAVIORAL;
