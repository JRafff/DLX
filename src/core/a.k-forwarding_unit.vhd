library ieee;
use ieee.std_logic_1164.all;

-- Forwarding Unit puramente combinatoria per il pipeline DLX.
--
-- Guarda gli indirizzi dei registri sorgente presenti in EX (Rs1_EX / Rs2_EX,
-- salvati nel registro ID/EX) e li confronta con gli indirizzi di
-- destinazione delle istruzioni piu' avanti nella pipeline:
--   * EX/MEM.Rd  -> risultato appena calcolato dall'ALU (1 ciclo di anticipo)
--   * MEM/WB.Rd  -> risultato che sta per essere scritto nel RF (2 cicli)
--
-- Encoding dei selettori FORWARD_A / FORWARD_B (compatibile con l'EXStage):
--   "10" -> forwarding da EX/MEM (piu' recente)
--   "01" -> forwarding da MEM/WB
--   "00" -> nessun forwarding, usa il dato letto dal Register File
--
-- Priorita': EX/MEM ha priorita' su MEM/WB, perche' rappresenta
-- l'istruzione piu' recente che scrivera' su quel registro.
--
-- Nota importante: il caso Load-Use (istruzione in EX/MEM e' una Load, e
-- l'istruzione in EX ha bisogno di quel dato) NON viene risolto dalla
-- forwarding, perche' il dato dalla DRAM non e' ancora disponibile. Lo
-- gestisce hazard_detector.vhd alzando load_use_alarm alla CU, che stalla
-- il front-end di 1 ciclo. Dopo lo stallo la load e' in MEM/WB e il forward
-- combinatorio "01" fornisce il dato all'istruzione dipendente in EX.
entity forwarding_unit is
    generic (
        REG_ADDR : integer := 5
    );
    port (
        -- Sorgenti dell'istruzione attualmente in EX (dal registro ID/EX)
        ID_EX_Rs1  : in  std_logic_vector(REG_ADDR-1 downto 0);
        ID_EX_Rs2  : in  std_logic_vector(REG_ADDR-1 downto 0);

        -- Destinazione + write enable dell'istruzione in MEM (da EX/MEM)
        EX_MEM_Rd    : in  std_logic_vector(REG_ADDR-1 downto 0);
        EX_MEM_RF_WE : in  std_logic;

        -- Destinazione + write enable dell'istruzione in WB (da MEM/WB)
        MEM_WB_Rd    : in  std_logic_vector(REG_ADDR-1 downto 0);
        MEM_WB_RF_WE : in  std_logic;

        -- Selettori per i MUX di forwarding nell'EX stage
        FORWARD_A : out std_logic_vector(1 downto 0);
        FORWARD_B : out std_logic_vector(1 downto 0)
    );
end entity;

architecture behavioral of forwarding_unit is
    constant R_ZERO : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');
begin

    -- ============ Canale A ============
    -- Priorita' EX/MEM > MEM/WB. Skip su R0 (che e' hard-wired a 0).
    process(ID_EX_Rs1, EX_MEM_Rd, EX_MEM_RF_WE, MEM_WB_Rd, MEM_WB_RF_WE)
    begin
        if (EX_MEM_RF_WE = '1') and (EX_MEM_Rd /= R_ZERO)
           and (EX_MEM_Rd = ID_EX_Rs1) then
            FORWARD_A <= "10";
        elsif (MEM_WB_RF_WE = '1') and (MEM_WB_Rd /= R_ZERO)
              and (MEM_WB_Rd = ID_EX_Rs1) then
            FORWARD_A <= "01";
        else
            FORWARD_A <= "00";
        end if;
    end process;

    -- ============ Canale B ============
    process(ID_EX_Rs2, EX_MEM_Rd, EX_MEM_RF_WE, MEM_WB_Rd, MEM_WB_RF_WE)
    begin
        if (EX_MEM_RF_WE = '1') and (EX_MEM_Rd /= R_ZERO)
           and (EX_MEM_Rd = ID_EX_Rs2) then
            FORWARD_B <= "10";
        elsif (MEM_WB_RF_WE = '1') and (MEM_WB_Rd /= R_ZERO)
              and (MEM_WB_Rd = ID_EX_Rs2) then
            FORWARD_B <= "01";
        else
            FORWARD_B <= "00";
        end if;
    end process;

end behavioral;
