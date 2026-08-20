library ieee;
use ieee.std_logic_1164.all;

entity MEMStage is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;

        -- ingresso (da EX/MEM)
        ALU_OUT_IN : in std_logic_vector(N-1 downto 0);
        RegB_IN    : in std_logic_vector(N-1 downto 0);
        RD_IN      : in std_logic_vector(REG_ADDR-1 downto 0);

        -- Segnali di Controllo 
        DRAM_WE      : in std_logic;
        LMD_LATCH_EN : in std_logic;

        -- Uscite verso wb
        ALU_OUT_WB : out std_logic_vector(N-1 downto 0);
        LMD_WB     : out std_logic_vector(N-1 downto 0);
        RD_OUT_WB  : out std_logic_vector(REG_ADDR-1 downto 0)
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

    component reg_en
        generic (NBIT : integer := 32);
        port (
            Clk : in  std_logic;
            Rst : in  std_logic;
            EN  : in  std_logic;
            D   : in  std_logic_vector(NBIT-1 downto 0);
            Q   : out std_logic_vector(NBIT-1 downto 0)
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


    
    LMD_R: reg_en
        generic map (NBIT => N)
        port map (
            Clk => Clk, 
            Rst => Rst, 
            EN  => LMD_LATCH_EN, 
            D   => dram_dout, 
            Q   => LMD_WB
        );

    ALU_RES_R: reg_en
        generic map (NBIT => N)
        port map (
            Clk => Clk, 
            Rst => Rst, 
            EN  => '1', 
            D   => ALU_OUT_IN, 
            Q   => ALU_OUT_WB
        );

    RD_R: reg_en
        generic map (NBIT => REG_ADDR)
        port map (
            Clk => Clk, 
            Rst => Rst, 
            EN  => '1', 
            D   => RD_IN, 
            Q   => RD_OUT_WB
        );

end STRUCTURAL;

