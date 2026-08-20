library ieee;
use ieee.std_logic_1164.all;

entity tb_DLX is
end tb_DLX;

architecture BEHAVIORAL of tb_DLX is

    -- Costanti
    constant CLK_PERIOD : time := 10 ns;

    component DLX
        port (
            Clk : in std_logic;
            Rst : in std_logic
        );
    end component;

    -- Segnali 
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

begin

    -- Istanziazione del processore
    UUT: DLX
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
        -
        Rst <= '0';
        wait for CLK_PERIOD * 2.5;
        
        Rst <= '1';
        
        -- (50 cicli)
        wait for CLK_PERIOD * 50;
        
        -- stop
        assert false report "SIMULAZIONE COMPLETATA." severity failure;
    end process;

end BEHAVIORAL;