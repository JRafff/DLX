library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

entity shifter is 
    generic(
        Nbit : integer := 32 
    );
    port(
        nLeft_right : in  std_logic; -- 0 = left, 1 = right
        A           : in  std_logic_vector(Nbit-1 downto 0);
        B           : in  std_logic_vector(Nbit-1 downto 0); 
        shift_out   : out std_logic_vector(Nbit-1 downto 0)  
    );
end entity;

architecture bh of shifter is

    type mask_array is array(0 to (Nbit/8) - 1) of std_logic_vector(Nbit+7 downto 0);
    type mask_array_fine is array(0 to 7) of std_logic_vector(Nbit-1 downto 0);
    
    signal fine_masks     : mask_array_fine;
    signal coarse_masks   : mask_array;
    signal coarse_mux_out : std_logic_vector(Nbit+7 downto 0);

begin

    logic_proc: process(A, nLeft_right)
    begin
        for i in 0 to (Nbit/8) - 1 loop
 
            coarse_masks(i) <= (others => '0'); -- inizializzo a 0
            
            if nLeft_right = '0' then -- SLL
                coarse_masks(i)(Nbit + 7 downto 8 + (i*8)) <= A(Nbit - 1 - (i*8) downto 0);
            else -- SRL
                coarse_masks(i)(Nbit - 1 - (i*8) downto 0) <= A(Nbit - 1 downto (i*8));
            end if;
        end loop;
    end process;

    -- Selezione COARSE usa sempre i bit 4 e 3 dell'ammontare B (salto da 8)
    coarse_mux_out <= coarse_masks(to_integer(unsigned(B(4 downto 3)))); 

    fine_grain: process(coarse_mux_out, nLeft_right) 
    begin
        for i in 0 to 7 loop -- 8 step 
             
            if nLeft_right = '0' then -- SLL
                fine_masks(i) <= coarse_mux_out(Nbit + 7 - i downto 8 - i);
            else -- SRL
                fine_masks(i) <= coarse_mux_out(Nbit - 1 + i downto i); 
            end if;
            
        end loop;
    end process;

    -- Selezione FINE usa i bit 2, 1, 0 di B
    shift_out <= fine_masks(to_integer(unsigned(B(2 downto 0))));
    
end bh;