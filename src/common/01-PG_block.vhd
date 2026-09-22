library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity PG_block is 
port (
    Pik : in std_logic;
    Gik : in std_logic;
    Pkj : in std_logic;
    Gkj : in std_logic;
    Pij : out std_logic;
    Gij : out std_logic
);
end entity;

architecture bh of PG_block is
    begin
        Pij <= Pik and Pkj;
        Gij <= Gik or (Pik and Gkj);
    end bh;