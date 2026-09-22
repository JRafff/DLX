library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Icache is -- 4 ways set associative
    generic (
        N : integer := 32
    );
    port (
        clk : in std_logic;
        pc_in : in  std_logic_vector(N-1 downto 0); -- PC 
        instr_out : out std_logic_vector(N-1 downto 0);
        hit : out std_logic;
        -- scrittura in caso miss
        ram_read_en_out : out std_logic;
        ram_ready_in : in std_logic;
        ram_data_in : in std_logic_vector(N-1 downto 0);
        pc_out : out std_logic_vector(N-1 downto 0) -- PC 
    );
end entity;

architecture behavioral of Icache is 
-- definiamo la cache
type cache_entry is record
    valid : std_logic;
    tag : std_logic_vector(27 downto 0); -- 4 set, 4 ways, 2 bit di offset, 2 di index e 28 di index
    data : std_logic_vector(N-1 downto 0); -- istruzione
end record;

type cache_set is array (0 to 3) of cache_entry; -- 4 set (entries)
type cache_mem is array (0 to 3) of cache_set; -- cache intera 4 ways
signal I_cache : cache_mem := (others => (others => (
        valid => '0',
        tag   => (others => '0'),
        data  => (others => '0')
    )));
--array di 3 bit per l'algoritmo di replacing pseudo LRU, 3 bit per ognuno dei 4 set
type plru_array is array (0 to 3) of std_logic_vector(2 downto 0);
signal plru_bits : plru_array := (others => "000");

--segnali interni tra i processi
signal hit_sig : std_logic;
signal hit_way : integer range 0 to 3;

begin

--processo combinatorio asincrono di lettura
read_comb : process(pc_in, I_cache)
variable c_index : integer;
variable c_sets : cache_set;
variable hit_missn : std_logic;
begin
    hit_missn := '0';
    hit <= '0';
    hit_sig <= '0';
    ram_read_en_out <= '0';
    pc_out <= (others => '0');
    instr_out <= (others => '0');
    hit_way <= 0;

    c_index := to_integer(unsigned(pc_in(3 downto 2))); --index
    c_sets := I_cache(c_index); -- qui ho i 4 set 

    for i in 0 to 3 loop 
        if (c_sets(i).valid = '1') and (c_sets(i).tag = pc_in(31 downto 4)) then
            instr_out <= c_sets(i).data ;
            hit <= '1';
            hit_sig <= '1';
            hit_missn := '1';
            hit_way <= i;
        end if;
    end loop;
    
    if hit_missn /= '1' then
        -- caso miss
        hit <= '0';
        hit_sig <= '0';
        hit_missn := '0';
        ram_read_en_out <= '1';
        pc_out <= pc_in;
    end if;

end process;

-- gestisco in modo sincrono l'aggiornamento del vettore plru e la scrittura in caso miss 
update_and_write : process(clk)
variable c_index : integer;
variable plru : std_logic_vector(2 downto 0);
variable victim_way : integer range 0 to 3;
begin
    if rising_edge(clk) then
        -- Calcoliamo l'indice e leggiamo il plru all'inizio del colpo di clock per entrambi i casi
        c_index := to_integer(unsigned(pc_in(3 downto 2)));
        plru := plru_bits(c_index);

        -- caso hit
        if hit_sig = '1' then
            if hit_way = 0 then
                plru := plru or "110";
            end if;
            if hit_way = 1 then
                plru := (plru or "100") and "101";
            end if;
            if hit_way = 2 then
                plru := (plru or "001") and "011";
            end if;
            if hit_way = 3 then
                plru := plru and "010";
            end if;

            plru_bits(c_index) <= plru;
            
        -- caso miss (corretto a hit_sig = '0')
        elsif hit_sig = '0' and ram_ready_in = '1' then
            -- navigo l'albero plru
            -- Radice = plru(2): coerente con le maschere di update qui sotto,
            -- dove way0/way1 (sinistra) impostano il bit2 a '1' e way2/way3
            -- (destra) lo azzerano. Con la vecchia radice plru(0) le vie 2 e 3
            -- non venivano mai selezionate come vittima (restavano sempre
            -- valid='0'): la cache si comportava come una 2-way invece che 4-way.
            if plru(2) = '0' then -- Vado a Sinistra
                if plru(1) = '0' then
                    victim_way := 0;
                else
                    victim_way := 1;
                end if;
            else -- Vado a Destra
                if plru(0) = '0' then
                    victim_way := 2;
                else
                    victim_way := 3;
                end if;
            end if;
            
            -- aggiorno la cache e scrivo i dati 
            I_cache(c_index)(victim_way).valid <= '1';
            I_cache(c_index)(victim_way).tag   <= pc_in(31 downto 4);
            I_cache(c_index)(victim_way).data  <= ram_data_in;

            -- aggiorno il plru vector
            if victim_way = 0 then
                plru := plru or "110";
            end if;
            if victim_way = 1 then
                plru := (plru or "100") and "101";
            end if;
            if victim_way = 2 then
                plru := (plru or "001") and "011";
            end if;
            if victim_way = 3 then
                plru := plru and "010";
            end if;

            plru_bits(c_index) <= plru;
            
        end if;
    end if;
end process;

end behavioral;