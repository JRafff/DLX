library ieee;
use ieee.std_logic_1164.all;

entity EX_MEM_reg is
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
        
        -- Ingressi dallo stadio di Execute
        alu_out_in       : in  std_logic_vector(N-1 downto 0);
        data_to_store_in : in  std_logic_vector(N-1 downto 0); -- Il RegB bypassato (per le Store)
        rd_in            : in  std_logic_vector(REG_ADDR-1 downto 0);
        
        -- Uscite verso lo stadio di Memoria
        alu_out_out       : out std_logic_vector(N-1 downto 0);
        data_to_store_out : out std_logic_vector(N-1 downto 0);
        rd_out            : out std_logic_vector(REG_ADDR-1 downto 0)
    );
end entity;

architecture behavioral of EX_MEM_reg is
begin

    process(clk, rst)
    begin
        -- Reset asincrono globale 
        if rst = '0' then 
            alu_out_out       <= (others => '0');
            data_to_store_out <= (others => '0');
            rd_out            <= (others => '0');
            
        elsif rising_edge(clk) then
            
            -- Flush (Svuotamento in caso di eccezioni)
            if clear = '1' then
                alu_out_out       <= (others => '0');
                data_to_store_out <= (others => '0');
                rd_out            <= (others => '0');
                
            -- Enable (Avanzamento normale)
            elsif en = '1' then
                alu_out_out       <= alu_out_in;
                data_to_store_out <= data_to_store_in;
                rd_out            <= rd_in;
                
            -- Se en = '0' e clear = '0', i registri mantengono il vecchio valore (Stallo)
            end if;
            
        end if;
    end process;

end behavioral;