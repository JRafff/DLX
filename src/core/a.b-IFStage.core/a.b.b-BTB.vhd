library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

entity BTB is
    generic (N : integer := 32);
    port (
        clk : in  std_logic;
        
        -- fetch lettura
        PC_in            : in  std_logic_vector(N-1 downto 0); 
        Predicted_target : out std_logic_vector(N-1 downto 0); 
        taken            : out std_logic;

        -- decode scrittura
        PC_update        : in  std_logic_vector(N-1 downto 0);
        update_en        : in  std_logic; 
        Actual_Taken     : in  std_logic; 
        Actual_Target    : in  std_logic_vector(N-1 downto 0)
    );
end entity;

architecture behavioral of BTB is 
    
    type btb_entry is record
        Valid   : std_logic;                       
        Tag     : std_logic_vector(23 downto 0);   
        Target  : std_logic_vector(31 downto 0);   
        History : std_logic_vector(1 downto 0);    
    end record;

    type btb_tab is array (0 to 63) of btb_entry;
    
    signal btb_t : btb_tab := (others => (
        Valid   => '0', 
        Tag     => (others => '0'), 
        Target  => (others => '0'), 
        History => "00"
    ));

begin

  -- lettura in fetch combinatorio
    btb_proc : process(PC_in, btb_t) 
        variable v_index : integer range 0 to 63;
        variable v_entry : btb_entry;
    begin
        taken <= '0';
        Predicted_target <= (others => '0');

        v_index := to_integer(unsigned(PC_in(7 downto 2)));
        v_entry := btb_t(v_index); -- entry puntata dal PC

        if (v_entry.Valid = '1') and (v_entry.Tag = PC_in(31 downto 8)) then   
            if (v_entry.History(1) = '1') then
                taken <= '1';
                Predicted_target <= v_entry.Target;
            end if;
        end if;
    end process; 


   -- scrittura e aggiornamento della btb in decode (sincrona con il clock)
    btb_write : process(clk)
        variable counter : unsigned(1 downto 0);
        variable w_index : integer range 0 to 63;
        variable v_entry : btb_entry;
    begin
        if rising_edge(clk) then 
            if update_en = '1' then
                
                w_index := to_integer(unsigned(PC_update(7 downto 2)));
                v_entry := btb_t(w_index);
                
                -- Controllo se la casella è scritta
                if (v_entry.Valid = '1') and (v_entry.Tag = PC_update(31 downto 8)) then   
                    counter := unsigned(v_entry.History); -- 2 bit predictor
                    
                    if Actual_Taken = '1' then
                        if counter /= "11" then
                            counter := counter + 1;
                        end if;
                    else
                        if counter /= "00" then
                            counter := counter - 1;
                        end if;
                    end if;
                    
                else 
                    -- Casella non scritta o branch diverso 
                    if Actual_Taken = '1' then
                        counter := "10"; -- Weakly Taken
                    else
                        counter := "01"; -- Weakly Not Taken
                    end if;
                end if;
                
                -- Aggiornamento fisico 
                btb_t(w_index).Valid   <= '1';
                btb_t(w_index).Tag     <= PC_update(31 downto 8);
                btb_t(w_index).Target  <= Actual_Target;
                btb_t(w_index).History <= std_logic_vector(counter);
                
            end if;
        end if; 
    end process;

end behavioral;