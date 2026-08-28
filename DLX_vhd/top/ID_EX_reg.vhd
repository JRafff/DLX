library ieee;
use ieee.std_logic_1164.all;

entity ID_EX_reg is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5;
        CTRL_W   : integer := 15 
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic; -- Reset globale (active low)
        
        -- Segnali di controllo 
        en          : in  std_logic; -- (per lo stallo: 0 = stall)
        clear       : in  std_logic; -- Clear sincrono (per il flush)
        
        -- Ingressi dallo stadio di Decode (Datapath)
        rega_in     : in  std_logic_vector(N-1 downto 0);
        regb_in     : in  std_logic_vector(N-1 downto 0);
        regimm_in   : in  std_logic_vector(N-1 downto 0);
        npc_in      : in  std_logic_vector(N-1 downto 0);
        rd_in       : in  std_logic_vector(REG_ADDR-1 downto 0);
        
        -- Uscite verso lo stadio di Execute
        rega_out    : out std_logic_vector(N-1 downto 0);
        regb_out    : out std_logic_vector(N-1 downto 0);
        regimm_out  : out std_logic_vector(N-1 downto 0);
        npc_out     : out std_logic_vector(N-1 downto 0);
        rd_out      : out std_logic_vector(REG_ADDR-1 downto 0);
    );
end entity;

architecture behavioral of ID_EX_reg is
begin

    process(clk, rst)
    begin
        -- Reset asincrono globale 
        if rst = '0' then 
            rega_out   <= (others => '0');
            regb_out   <= (others => '0');
            regimm_out <= (others => '0');
            npc_out    <= (others => '0');
            rd_out     <= (others => '0');
            
        elsif rising_edge(clk) then
            
            -- Flush (Svuotamento)
            if clear = '1' then
                rega_out   <= (others => '0');
                regb_out   <= (others => '0');
                regimm_out <= (others => '0');
                npc_out    <= (others => '0');
                rd_out     <= (others => '0');
                
            -- Enable (Avanzamento normale)
            elsif en = '1' then
                rega_out   <= rega_in;
                regb_out   <= regb_in;
                regimm_out <= regimm_in;
                npc_out    <= npc_in;
                rd_out     <= rd_in;
                ctrl_out   <= ctrl_in;
                
            -- Se en = '0' e clear = '0', i registri mantengono il vecchio valore (Stallo)
            end if;
            
        end if;
    end process;

end behavioral;