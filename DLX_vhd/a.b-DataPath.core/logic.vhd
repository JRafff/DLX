library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

entity logic is 
    generic(
        Nbit : integer := 32 
    );
    port(
        logic_sel : in  std_logic_vector(1 downto 0); -- 2 bit per 4 operazioni
        A         : in  std_logic_vector(Nbit-1 downto 0);
        B         : in  std_logic_vector(Nbit-1 downto 0); 
        logic_out : out std_logic_vector(Nbit-1 downto 0)  
    );
end entity;

architecture bh of logic is
begin
    
    logic_proc: process(A, B, logic_sel)
    begin
        case logic_sel 
            when "00" => logic_out <= A and B;
            when "01" => logic_out <= A or B;
            when "10" => logic_out <= A xor B;
            when others => logic_out <= (others => '0');      
        end case;
    end process;
    
end bh;