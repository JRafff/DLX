library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity pg_network is 
generic (N : integer := 32);
port (
    A : in std_logic_vector(N-1 downto 0);
    B : in std_logic_vector(N-1 downto 0);
    cin : in std_logic;
    P : out std_logic_vector(N-1 downto 0);
    G : out std_logic_vector(N-1 downto 0)
);
end entity;

architecture bh of pg_network is
    begin
        network: for i in 0 to N-1 generate
            first: if i = 0 generate
                G(i) <= (A(i) and B(i)) or ((A(i) xor B(i)) and cin); --i consider Cin inside the pg network
                P(i) <= A(i) xor B(i);
            end generate first;
            other: if i > 0 generate
                G(i) <= A(i) and B(i);
                P(i) <= A(i) xor B(i);
            end generate other;

        end generate network;
    end bh;