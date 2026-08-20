library ieee;
use ieee.std_logic_1164.all;

entity WBStage is
    generic (
        N        : integer := 32
    );
    port (
        ALU_OUT_IN : in std_logic_vector(N-1 downto 0);
        LMD_IN     : in std_logic_vector(N-1 downto 0);

        -- Segnali di Controllo 
        WB_MUX_SEL : in std_logic;

        WB_DATA_OUT  : out std_logic_vector(N-1 downto 0)
    );
end WBStage;

architecture STRUCTURAL of WBStage is

begin

    
    WB_DATA_OUT <= ALU_OUT_IN when (WB_MUX_SEL = '0') else LMD_IN;

    

end STRUCTURAL;

