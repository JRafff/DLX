library ieee;
use ieee.std_logic_1164.all;

-- Pipeline register between IF and ID.
-- Trasporta PC, NPC, IR e anche il bit di "predizione taken" della BTB,
-- che serve al Branch Resolution nello stadio di Decode per capire se la
-- predizione fatta nel Fetch e' stata corretta.
entity IF_ID_reg is
    generic (
        N : integer := 32
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic; -- Reset globale (active low)

        -- Segnali di controllo
        en          : in  std_logic; -- (per lo stallo: 0 = stall)
        clear       : in  std_logic; -- Clear sincrono (per il flush)

        -- Ingressi dallo stadio di Fetch
        pc_in       : in  std_logic_vector(N-1 downto 0);
        npc_in      : in  std_logic_vector(N-1 downto 0);
        ir_in       : in  std_logic_vector(N-1 downto 0);
        taken_in    : in  std_logic;

        -- Uscite verso lo stadio di Decode
        pc_out      : out std_logic_vector(N-1 downto 0);
        npc_out     : out std_logic_vector(N-1 downto 0);
        ir_out      : out std_logic_vector(N-1 downto 0);
        taken_out   : out std_logic
    );
end entity;

architecture behavioral of IF_ID_reg is
begin

    process(clk, rst)
    begin
        -- Reset asincrono globale
        if rst = '0' then
            pc_out    <= (others => '0');
            npc_out   <= (others => '0');
            ir_out    <= (others => '0'); -- NOP hardware
            taken_out <= '0';

        elsif rising_edge(clk) then

            -- Flush (Svuotamento in caso di Mispredict)
            if clear = '1' then
                pc_out    <= (others => '0');
                npc_out   <= (others => '0');
                ir_out    <= (others => '0'); -- Inietta un'istruzione NOP
                taken_out <= '0';

            -- Enable (Avanzamento normale)
            elsif en = '1' then
                pc_out    <= pc_in;
                npc_out   <= npc_in;
                ir_out    <= ir_in;
                taken_out <= taken_in;

            -- Se en = '0' e clear = '0', i registri mantengono automaticamente il loro vecchio valore (Stallo)
            end if;

        end if;
    end process;

end behavioral;
