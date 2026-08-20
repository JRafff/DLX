library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RF is
  generic (
    N        : integer := 32;
    REG_ADDR : integer := 5
  );
  port (
    CLK     : in  std_logic;
    RESET   : in  std_logic;
    WR      : in  std_logic;
    ADD_WR  : in  std_logic_vector(REG_ADDR-1 downto 0);
    ADD_RD1 : in  std_logic_vector(REG_ADDR-1 downto 0);
    ADD_RD2 : in  std_logic_vector(REG_ADDR-1 downto 0);
    DATAIN  : in  std_logic_vector(N-1 downto 0);
    OUT1    : out std_logic_vector(N-1 downto 0);
    OUT2    : out std_logic_vector(N-1 downto 0)
  );
end RF;

architecture BEHAVIORAL of RF is

  constant NREG : integer := 2**REG_ADDR;
  type   REG_ARRAY is array (0 to NREG-1) of std_logic_vector(N-1 downto 0);
  signal REGISTERS : REG_ARRAY := (others => (others => '0'));

begin

  WR_P: process (CLK, RESET)
  begin
    if RESET = '0' then
      REGISTERS <= (others => (others => '0'));
    elsif rising_edge(CLK) then
      if WR = '1' and unsigned(ADD_WR) /= 0 then
        REGISTERS(to_integer(unsigned(ADD_WR))) <= DATAIN;
      end if;
    end if;
  end process WR_P;

  OUT1 <= (others => '0') when unsigned(ADD_RD1) = 0
          else REGISTERS(to_integer(unsigned(ADD_RD1)));
  OUT2 <= (others => '0') when unsigned(ADD_RD2) = 0
          else REGISTERS(to_integer(unsigned(ADD_RD2)));

end BEHAVIORAL;

configuration CFG_RF_BEH of RF is
  for BEHAVIORAL
  end for;
end configuration;
