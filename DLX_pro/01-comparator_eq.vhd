library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity comparator_eq is
    generic(
        Nbit : integer := 32
    );
    port (
        A        : in  std_logic_vector(Nbit-1 downto 0);
        B        : in  std_logic_vector(Nbit-1 downto 0); 
        eq_out   : out std_logic_vector(Nbit-1 downto 0)  
    );
end entity;

architecture str of comparator_eq IS

    signal ab_xnor : std_logic_vector(Nbit-1 downto 0);
    signal is_equal: std_logic;

begin

    xnor_gen: for i in 0 to Nbit-1 generate
        ab_xnor(i) <= A(i) xnor B(i);
    end generate xnor_gen;

    -- Il sintetizzatore renderà efficiente l'AND a 32 porte
    is_equal <= '1' when ab_xnor = (Nbit-1 downto 0 => '1') else '0'; 
    
    eq_out(Nbit-1 downto 1) <= (others => '0');
    eq_out(0) <= not is_equal; -- Se NON sono uguali, esce 1 per l'operazione 		SNES Set if Not-Equal              


end str;