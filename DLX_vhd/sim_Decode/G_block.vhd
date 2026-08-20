library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity G_block is 
port (
    Pik : in std_logic;
    Gik : in std_logic;
    Gkj : in std_logic;
    Gij : out std_logic
);
end entity;

architecture bh of G_block is
    begin
        Gij <= Gik or (Pik and Gkj);
    end bh;