library ieee;
use ieee.std_logic_1164.all;

-- Minimal testbench for the DLX-pro: only clock + reset.
-- The workload is defined by the program in test.asm.mem, which the
-- IRAM reads when reset is released.

entity tb_DLX is
end tb_DLX;

architecture BEHAVIORAL of tb_DLX is

    constant CLK_PERIOD : time := 10 ns;

    component DLX
        port (
            Clk : in std_logic;
            Rst : in std_logic
        );
    end component;

    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

begin

    U1: DLX
        port map (
            Clk => Clk,
            Rst => Rst
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
        -- Active-low asynchronous reset for 2.5 cycles, then released
        Rst <= '0';
        wait for CLK_PERIOD * 2.5;
        Rst <= '1';

        -- Simulation sized for test_pro_stress.asm (45 instructions):
        --  * 3 cycles of IRAM latency on every line miss (Icache 4-way, 4 sets),
        --  * back-to-back R-type / I-type chain with forwarding,
        --  * load-use stall (Sect.4) and branch-stall (Sect.5),
        --  * BTB training on a 4-iteration backward loop (Sect.6),
        --  * j / jal / final halt-loop (Sect.7-8).
        wait for CLK_PERIOD * 400;

        assert false report "SIMULATION COMPLETED." severity failure;
    end process;

end BEHAVIORAL;
