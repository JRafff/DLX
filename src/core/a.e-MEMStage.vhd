library ieee;
use ieee.std_logic_1164.all;

-- MEM stage: contiene la sola DRAM (accesso in indirizzamento sincrono in
-- scrittura, asincrono in lettura). Il registro di pipeline MEM/WB e' stato
-- estratto fuori dallo stadio (vedi 03-MEM_WB_reg.vhd) per uniformita' con
-- IF/ID, ID/EX, EX/MEM: enable per stallo e clear per flush sono gestiti
-- dalla CU sul registro esterno.
entity MEMStage is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;

        -- Ingressi (da EX/MEM)
        ALU_OUT_IN : in std_logic_vector(N-1 downto 0);  -- indirizzo per DRAM / valore da inoltrare
        RegB_IN    : in std_logic_vector(N-1 downto 0);  -- dato da scrivere in DRAM (store)
        RD_IN      : in std_logic_vector(REG_ADDR-1 downto 0);

        -- Segnali di Controllo
        DRAM_WE    : in std_logic;

        -- Uscite verso MEM/WB reg
        ALU_OUT_MEM_WB : out std_logic_vector(N-1 downto 0);
        LMD_MEM_WB     : out std_logic_vector(N-1 downto 0);
        RD_MEM_WB      : out std_logic_vector(REG_ADDR-1 downto 0)
    );
end MEMStage;

architecture STRUCTURAL of MEMStage is

    component DRAM
        generic (
            RAM_DEPTH : integer := 128;
            D_SIZE    : integer := 32
        );
        port (
            Clk  : in  std_logic;
            Rst  : in  std_logic;
            WM   : in  std_logic;
            Addr : in  std_logic_vector(D_SIZE - 1 downto 0);
            Din  : in  std_logic_vector(D_SIZE - 1 downto 0);
            Dout : out std_logic_vector(D_SIZE - 1 downto 0)
        );
    end component;

    signal dram_dout : std_logic_vector(N-1 downto 0);

begin

    DRAM_I: DRAM
        generic map (RAM_DEPTH => 128, D_SIZE => N)
        port map (
            Clk  => Clk,
            Rst  => Rst,
            WM   => DRAM_WE,
            Addr => ALU_OUT_IN,
            Din  => RegB_IN,
            Dout => dram_dout
        );

    -- I registri effettivi sono nel MEM_WB_reg esterno; qui portiamo solo
    -- i segnali combinatori.
    ALU_OUT_MEM_WB <= ALU_OUT_IN;
    LMD_MEM_WB     <= dram_dout;
    RD_MEM_WB      <= RD_IN;

end STRUCTURAL;
