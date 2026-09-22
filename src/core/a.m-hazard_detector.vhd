library ieee;
use ieee.std_logic_1164.all;

entity hazard_detector is
    port (
        ID_Rs1 : in  std_logic_vector(4 downto 0); 
        ID_Rs2 : in  std_logic_vector(4 downto 0); 
        EX_Rd : in  std_logic_vector(4 downto 0); 
        EX_RF_WE : in  std_logic; 
        EX_WB_MUX_SEL : in  std_logic;
        EQ_COND : in  std_logic;
        
        -- Segnali dallo stadio MEM (stallo del Branch)
        MEM_Rd : in  std_logic_vector(4 downto 0);
        MEM_RF_WE : in  std_logic;
        MEM_WB_MUX_SEL : in  std_logic;
        
        load_use_alarm : out std_logic;  
        branch_stall_alarm : out std_logic   
    );
end hazard_detector;

architecture behavioral of hazard_detector is
begin

    process(EX_RF_WE, EX_WB_MUX_SEL, EX_Rd, ID_Rs1, ID_Rs2, EQ_COND, MEM_Rd, MEM_RF_WE, MEM_WB_MUX_SEL)
    begin
        -- Se l'istruzione in EX è una LOAD e il target è uno dei registri sorgente in ID bisogna inserire uno stall
        if (EX_RF_WE = '1' and EX_WB_MUX_SEL = '1') and (EX_Rd /= "00000") and 
           (EX_Rd = ID_Rs1 or EX_Rd = ID_Rs2) then
            load_use_alarm <= '1'; -- Allarme
        else
            load_use_alarm <= '0';
        end if;

        -- Un Branch in ID usa solo Rs1. Dobbiamo stallare se:
        -- Rs1 viene calcolata in EX
        -- Rs1 viene scritta in MEM da una load
        
        if (EQ_COND = '1') and (ID_Rs1 /= "00000") then
            
            -- EX
            if (EX_RF_WE = '1' and EX_Rd = ID_Rs1) then
                branch_stall_alarm <= '1';
                
            -- MEM (stallo di due cicli in caso di load)
            elsif (MEM_RF_WE = '1' and MEM_WB_MUX_SEL = '1' and MEM_Rd = ID_Rs1) then
                branch_stall_alarm <= '1';
                
            else
                branch_stall_alarm <= '0';
            end if;
            
        else
            branch_stall_alarm <= '0';
        end if;
    end process;
end behavioral;