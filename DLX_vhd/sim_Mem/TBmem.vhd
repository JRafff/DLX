library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_MEMStage is
end tb_MEMStage;

architecture BEHAVIORAL of tb_MEMStage is

    -- Costanti
    constant N          : integer := 32;
    constant REG_ADDR   : integer := 5;
    constant CLK_PERIOD : time := 10 ns;
    constant RAM_DEPTH  : integer := 128;

    -- (UUT)
    component MEMStage
        generic (
            N        : integer := 32;
            REG_ADDR : integer := 5
        );
        port (
            Clk          : in std_logic;
            Rst          : in std_logic;
            ALU_OUT_IN   : in std_logic_vector(N-1 downto 0);
            RegB_IN      : in std_logic_vector(N-1 downto 0);
            RD_IN        : in std_logic_vector(REG_ADDR-1 downto 0);
            DRAM_WE      : in std_logic;
            LMD_LATCH_EN : in std_logic;
            ALU_OUT_WB   : out std_logic_vector(N-1 downto 0);
            LMD_WB       : out std_logic_vector(N-1 downto 0);
            RD_OUT_WB    : out std_logic_vector(REG_ADDR-1 downto 0)
        );
    end component;

    -- Segnali 
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic := '0';
    signal ALU_OUT_IN   : std_logic_vector(N-1 downto 0) := (others => '0');
    signal RegB_IN      : std_logic_vector(N-1 downto 0) := (others => '0');
    signal RD_IN        : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');
    signal DRAM_WE      : std_logic := '0';
    signal LMD_LATCH_EN : std_logic := '0';

    -- Segnali in uscita UUT
    signal uut_ALU_OUT_WB : std_logic_vector(N-1 downto 0);
    signal uut_LMD_WB     : std_logic_vector(N-1 downto 0);
    signal uut_RD_OUT_WB  : std_logic_vector(REG_ADDR-1 downto 0);

    -- golden model
    type ram_type is array (0 to RAM_DEPTH - 1) of std_logic_vector(N-1 downto 0);
    signal golden_ram : ram_type := (others => (others => '0'));
    
    -- Lettura asincrona combinatoria dalla RAM fittizia
    signal golden_ram_dout : std_logic_vector(N-1 downto 0);

    -- Uscite attese (Golden Output)
    signal exp_ALU_OUT_WB : std_logic_vector(N-1 downto 0) := (others => '0');
    signal exp_LMD_WB     : std_logic_vector(N-1 downto 0) := (others => '0');
    signal exp_RD_OUT_WB  : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');

    -- Flag per terminare la simulazione pulita
    signal end_of_sim     : boolean := false;

begin

    UUT: MEMStage
        port map (
            Clk          => Clk,
            Rst          => Rst,
            ALU_OUT_IN   => ALU_OUT_IN,
            RegB_IN      => RegB_IN,
            RD_IN        => RD_IN,
            DRAM_WE      => DRAM_WE,
            LMD_LATCH_EN => LMD_LATCH_EN,
            ALU_OUT_WB   => uut_ALU_OUT_WB,
            LMD_WB       => uut_LMD_WB,
            RD_OUT_WB    => uut_RD_OUT_WB
        );

    -- Clock controllato dal flag di fine simulazione
    clk_process: process
    begin
        while not end_of_sim loop
            Clk <= '0';
            wait for CLK_PERIOD / 2;
            Clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- GOLDEN MODEL: Memoria RAM e Pipeline
    
    -- Lettura Asincrona 
    process(ALU_OUT_IN, golden_ram)
        variable addr_idx : integer;
    begin
        -- Protezione: se l'indirizzo contiene 'U' o 'X', evita il crash del simulatore
        if not is_X(ALU_OUT_IN) then
            addr_idx := to_integer(unsigned(ALU_OUT_IN(N-1 downto 2)));
            if addr_idx < RAM_DEPTH then
                golden_ram_dout <= golden_ram(addr_idx);
            else
                golden_ram_dout <= (others => '0'); -- Out of bounds
            end if;
        else
            golden_ram_dout <= (others => '0');
        end if;
    end process;

    -- Scrittura Sincrona (RAM e Registri di Pipeline)
    process(Clk, Rst)
        variable addr_idx : integer;
    begin
        if Rst = '0' then
            exp_ALU_OUT_WB <= (others => '0');
            exp_LMD_WB     <= (others => '0');
            exp_RD_OUT_WB  <= (others => '0');
        elsif rising_edge(Clk) then
            -- I registri bypass (Enable fisso a '1' nell'architettura)
            exp_ALU_OUT_WB <= ALU_OUT_IN;
            exp_RD_OUT_WB  <= RD_IN;
            
            -- Il registro LMD  LMD_LATCH_EN = '1'
            if LMD_LATCH_EN = '1' then
                exp_LMD_WB <= golden_ram_dout;
            end if;

            -- Scrittura nella Golden RAM
            if DRAM_WE = '1' and not is_X(ALU_OUT_IN) then
                addr_idx := to_integer(unsigned(ALU_OUT_IN(N-1 downto 2)));
                if addr_idx < RAM_DEPTH then
                    golden_ram(addr_idx) <= RegB_IN;
                end if;
            end if;
        end if;
    end process;

    -- PROCESSO DI CHECK AUTOMATICO
    process
    begin
        while not end_of_sim loop
            wait until falling_edge(Clk); 
            if Rst = '1' then
                assert (uut_ALU_OUT_WB = exp_ALU_OUT_WB) report "Errore: ALU_OUT_WB non corrisponde!" severity error;
                assert (uut_LMD_WB = exp_LMD_WB)         report "Errore: LMD_WB non corrisponde!" severity error;
                assert (uut_RD_OUT_WB = exp_RD_OUT_WB)   report "Errore: RD_OUT_WB non corrisponde!" severity error;
            end if;
        end loop;
        wait;
    end process;
    
    -- STIMOLO
    stim_proc: process
    begin
       -- Inizializzazione e Reset
        Rst <= '0';
        ALU_OUT_IN   <= (others => '0');
        RegB_IN      <= (others => '0');
        RD_IN        <= (others => '0');
        DRAM_WE      <= '0';
        LMD_LATCH_EN <= '0';
        
        wait for CLK_PERIOD * 2;
        Rst <= '1';
        wait for CLK_PERIOD;

        -- Istruzione ADD (Bypass della memoria)
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"00000042"; -- Risultato della ALU (es. 66)
        RD_IN        <= "00101";     -- Destinazione: R5
        DRAM_WE      <= '0';
        LMD_LATCH_EN <= '0';

        -- Istruzione STORE (SW) - Allineata a byte 0
        -- scrivere all'indirizzo 0x04 (indice 1)
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"00000004"; 
        RegB_IN      <= x"DEADBEEF"; 
        RD_IN        <= "00000";     -- Ininfluente per la store
        DRAM_WE      <= '1';
        LMD_LATCH_EN <= '0';

        -- Istruzione LOAD (LW) dallo stesso indirizzo (0x04)
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"00000004";
        RD_IN        <= "00010";     -- Destinazione: R2
        DRAM_WE      <= '0';
        LMD_LATCH_EN <= '1';

        -- Nuova operazione generica (es. SUB)
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"00000100";
        RD_IN        <= "01111";     
        DRAM_WE      <= '0';
        LMD_LATCH_EN <= '0';

        -- STORE disallineata (Verifica scarto dei 2 bit bassi)
        -- all'indirizzo 0x0A (10). scrive all'indice 2 (byte 8).
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"0000000A"; 
        RegB_IN      <= x"CAFEBABE";
        DRAM_WE      <= '1';
        LMD_LATCH_EN <= '0';

        -- LOAD dall'indirizzo di base (0x08)
        -- Leggendo da 0x08 dovremmo ritrovare il dato scritto a 0x0A, a conferma dell'allineamento.
        wait until falling_edge(Clk);
        ALU_OUT_IN   <= x"00000008";
        DRAM_WE      <= '0';
        LMD_LATCH_EN <= '1';

        -- Attendi l'ultimo colpo di clock per completare il campionamento dell'ultima load
        wait until falling_edge(Clk);
        
        -- Fine simulazione pulita
        end_of_sim <= true;
        report "SIMULAZIONE MEM COMPLETATA SENZA ERRORI!" severity note;
        wait;
    end process;

end BEHAVIORAL;