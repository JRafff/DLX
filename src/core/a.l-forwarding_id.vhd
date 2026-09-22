library ieee;
use ieee.std_logic_1164.all;

-- Forwarding Unit dedicata allo stadio ID.
--
-- La branch resolution avviene in ID (per ridurre la penalita' di
-- misprediction), quindi lo zero_check ha bisogno di RegA correttamente
-- aggiornato *prima* di scoprire l'uscita del Register File.
--
-- Questo modulo genera il selettore per un mux posto davanti a zero_check:
--     "10" -> forward da EX/MEM.alu_out  (priorita' massima)
--     "01" -> forward da MEM/WB.wb_data  (uscita del mux WB, e' gia' LMD per LW)
--     "00" -> valore letto dal Register File (default)
--
-- Regole:
--   * si attiva solo se IS_BRANCH='1' (=EQ_COND della CU)
--   * skip su R0 (che e' hardwired a zero)
--   * NON forwarda da EX/MEM se l'istruzione la' presente e' una LOAD
--     (EX_MEM_WB_MUX_SEL='1'): in quel caso exmem_alu_out contiene l'INDIRIZZO
--     di memoria, non il dato letto. La CU stalla la branch di un ulteriore
--     ciclo tramite hazard_detector; al ciclo successivo la LOAD sara' in
--     MEM/WB e wb_data conterra' il dato corretto.
entity forwarding_id is
    generic (
        REG_ADDR : integer := 5
    );
    port (
        -- Indirizzo del registro sorgente della branch (Rs1)
        ID_Rs1            : in  std_logic_vector(REG_ADDR-1 downto 0);

        -- Dal registro EX/MEM + control word CU (stadio MEM)
        EX_MEM_Rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
        EX_MEM_RF_WE      : in  std_logic;
        EX_MEM_WB_MUX_SEL : in  std_logic;  -- '1' = LOAD -> non forwardare da qui

        -- Dal registro MEM/WB + control word CU (stadio WB)
        MEM_WB_Rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
        MEM_WB_RF_WE      : in  std_logic;

        -- Attivo solo per istruzioni branch
        IS_BRANCH         : in  std_logic;

        -- Selettore mux davanti a zero_check
        FWD_ID_A          : out std_logic_vector(1 downto 0)
    );
end entity;

architecture behavioral of forwarding_id is
    constant R_ZERO : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');
begin

    process(ID_Rs1, EX_MEM_Rd, EX_MEM_RF_WE, EX_MEM_WB_MUX_SEL,
            MEM_WB_Rd, MEM_WB_RF_WE, IS_BRANCH)
    begin
        FWD_ID_A <= "00";

        if (IS_BRANCH = '1') and (ID_Rs1 /= R_ZERO) then

            -- Priorita' 1: EX/MEM (istruzione piu' recente).
            -- Escludiamo pero' la LOAD, perche' exmem_alu_out e' l'indirizzo.
            if (EX_MEM_RF_WE = '1') and (EX_MEM_WB_MUX_SEL = '0')
               and (EX_MEM_Rd = ID_Rs1) then
                FWD_ID_A <= "10";

            -- Priorita' 2: MEM/WB. wb_data e' gia' post-mux WB, quindi
            -- se l'istruzione era una LOAD contiene LMD, altrimenti alu_out.
            elsif (MEM_WB_RF_WE = '1') and (MEM_WB_Rd = ID_Rs1) then
                FWD_ID_A <= "01";
            end if;

        end if;
    end process;

end behavioral;
