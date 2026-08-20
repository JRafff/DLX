library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Data memory for DLX
entity DRAM is
  generic (
    RAM_DEPTH : integer := 128;
    D_SIZE    : integer := 32
  );
  port (
    Clk  : in  std_logic; 
    Rst  : in  std_logic; 
    WM   : in  std_logic; -- Write Memory enable
    Addr : in  std_logic_vector(D_SIZE - 1 downto 0);
    Din  : in  std_logic_vector(D_SIZE - 1 downto 0);
    Dout : out std_logic_vector(D_SIZE - 1 downto 0)
  );
end DRAM;

architecture DRam_Bhe of DRAM is 

  type RAMtype is array (0 to RAM_DEPTH - 1) of std_logic_vector(D_SIZE-1 downto 0);
  signal DRAM_mem : RAMtype := (others => (others => '0'));

begin  

  -- Scrittura Sincrona
  RW: process (Clk, Rst)
    variable addr_idx : integer;
  begin
    if (Rst = '0') then  
      for i in 0 to RAM_DEPTH - 1 loop
        DRAM_mem(i) <= (others => '0');
      end loop;
    elsif (rising_edge(Clk)) then
      if (WM = '1') and not is_X(Addr) then
        addr_idx := to_integer(unsigned(Addr(6 downto 2))); -- Gestisce fino a 128 parole (RAM_DEPTH)
        if addr_idx < RAM_DEPTH then
          DRAM_mem(addr_idx) <= Din;
        end if;
      end if;
    end if;
  end process RW;

  -- Lettura Asincrona protetta da is_X e dai limiti della memoria
  process(Addr, DRAM_mem)
    variable addr_idx : integer;
  begin
    if not is_X(Addr) then
      addr_idx := to_integer(unsigned(Addr(6 downto 2)));
      if addr_idx < RAM_DEPTH then
        Dout <= DRAM_mem(addr_idx);
      else
        Dout <= (others => '0');
      end if;
    else
      Dout <= (others => '0'); -- Se l'indirizzo è instabile/X, azzera l'uscita ed evita le linee rosse
    end if;
  end process;

end DRam_Bhe;