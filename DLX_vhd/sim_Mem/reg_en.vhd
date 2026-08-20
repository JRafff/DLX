library ieee;
use ieee.std_logic_1164.all;

-- Generic register with synchronous enable and asynchronous, active-low reset.
-- Matches the reset polarity used by Cu_v2 (Rst = '0' -> reset).
entity reg_en is
  generic (NBIT : integer := 32);
  port (
    Clk : in  std_logic;
    Rst : in  std_logic;                              -- active low
    EN  : in  std_logic;                              -- load enable
    D   : in  std_logic_vector(NBIT-1 downto 0);
    Q   : out std_logic_vector(NBIT-1 downto 0)
  );
end reg_en;

architecture BEHAVIORAL of reg_en is
begin
  P: process (Clk, Rst)
  begin
    if Rst = '0' then
      Q <= (others => '0');
    elsif rising_edge(Clk) then
      if EN = '1' then
        Q <= D;
      end if;
    end if;
  end process;
end BEHAVIORAL;

configuration CFG_REG_EN_BEH of reg_en is
  for BEHAVIORAL
  end for;
end configuration;
