library ieee;
use ieee.std_logic_1164.all;

entity pc_mux is
    generic (
        N : integer := 32
    );
    port (
        -- dati
        npc_in              : in  std_logic_vector(N-1 downto 0); -- PC + 4
        predicted_target_in : in  std_logic_vector(N-1 downto 0); -- Dalla BTB
        recovery_address_in : in  std_logic_vector(N-1 downto 0); -- (Decode)
        
        -- Segnali di controllo
        mispredict_in       : in  std_logic; -- Allarme dalla Decode
        taken_in            : in  std_logic; -- Predizione dalla BTB in IF
        
        -- out
        next_pc_out         : out std_logic_vector(N-1 downto 0)
    );
end entity;

architecture behavioral of pc_mux is 
begin

    -- (MUX con priorità)
    next_pc_out <= recovery_address_in when (mispredict_in = '1') else
                   predicted_target_in when (taken_in = '1')      else
                   npc_in;

end behavioral;