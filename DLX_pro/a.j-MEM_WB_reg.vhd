library ieee;
use ieee.std_logic_1164.all;

-- Pipeline register between MEM and WB.
-- Trasporta il risultato ALU, il dato letto dalla DRAM (LMD) e l'indirizzo
-- del registro destinazione. Coerente con gli altri registri di pipe:
-- enable per lo stallo, clear per il flush (bolla).
entity MEM_WB_reg is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic; -- Reset globale (active low)

        -- Segnali di controllo
        en          : in  std_logic; -- (per lo stallo: 0 = stall)
        clear       : in  std_logic; -- Clear sincrono (per il flush)

        -- Ingressi dallo stadio di Memory
        alu_out_in  : in  std_logic_vector(N-1 downto 0);
        lmd_in      : in  std_logic_vector(N-1 downto 0);
        rd_in       : in  std_logic_vector(REG_ADDR-1 downto 0);

        -- Uscite verso lo stadio di Write-Back
        alu_out_out : out std_logic_vector(N-1 downto 0);
        lmd_out     : out std_logic_vector(N-1 downto 0);
        rd_out      : out std_logic_vector(REG_ADDR-1 downto 0)
    );
end entity;

architecture behavioral of MEM_WB_reg is
begin

    process(clk, rst)
    begin
        if rst = '0' then
            alu_out_out <= (others => '0');
            lmd_out     <= (others => '0');
            rd_out      <= (others => '0');

        elsif rising_edge(clk) then
            if clear = '1' then
                alu_out_out <= (others => '0');
                lmd_out     <= (others => '0');
                rd_out      <= (others => '0');

            elsif en = '1' then
                alu_out_out <= alu_out_in;
                lmd_out     <= lmd_in;
                rd_out      <= rd_in;

            -- en='0' e clear='0' -> hold
            end if;
        end if;
    end process;

end behavioral;
