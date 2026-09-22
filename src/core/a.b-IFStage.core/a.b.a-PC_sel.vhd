library ieee;
use ieee.std_logic_1164.all;

entity pc_mux is
    generic (
        N : integer := 32
    );
    port (
        -- dati
        npc_in              : in  std_logic_vector(N-1 downto 0); -- PC + 4 (istruzione in fetch)
        predicted_target_in : in  std_logic_vector(N-1 downto 0); -- Dalla BTB
        recovery_address_in : in  std_logic_vector(N-1 downto 0); -- (Decode) target del branch: NPC + IMM
        branch_npc_in       : in  std_logic_vector(N-1 downto 0); -- NPC del branch in ID (PC del branch + 4)
        
        -- Segnali di controllo
        mispredict_in       : in  std_logic; -- Allarme dalla Decode
        actual_taken_in     : in  std_logic; -- Esito reale del branch risolto in Decode
        taken_in            : in  std_logic; -- Predizione dalla BTB in IF
        
        -- out
        next_pc_out         : out std_logic_vector(N-1 downto 0)
    );
end entity;

architecture behavioral of pc_mux is 
begin

    -- (MUX con priorità)
    -- 1) mispredict e branch realmente preso     -> target del branch (recovery)
    -- 2) mispredict e branch realmente NON preso -> istruzione successiva al branch (NPC del branch)
    -- 3) BTB predice taken                       -> target predetto
    -- 4) altrimenti                              -> PC + 4
    next_pc_out <= recovery_address_in when (mispredict_in = '1' and actual_taken_in = '1') else
                   branch_npc_in       when (mispredict_in = '1' and actual_taken_in = '0') else
                   predicted_target_in when (taken_in = '1')                                else
                   npc_in;

end behavioral;