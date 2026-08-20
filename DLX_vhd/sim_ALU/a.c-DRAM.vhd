library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

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

  type RAMtype is array (0 to RAM_DEPTH - 1) of integer;
  signal DRAM_mem : RAMtype;

begin  

  -- processo scrittura sincrona
  RW: process (Clk, Addr)
  begin
  

      Dout <= conv_std_logic_vector(DRAM_mem(conv_integer(unsigned(Addr(D_SIZE-1 downto 2)))), D_SIZE);

    if (rising_edge(Clk)) then
      if (WM = '1') then
        DRAM_mem(conv_integer(unsigned(Addr(D_SIZE-1 downto 2)))) <= conv_integer(unsigned(Din));
      end if;
    end if;

  end process RW;

end DRam_Bhe;