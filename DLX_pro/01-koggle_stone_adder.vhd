library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;
use ieee.math_real.all;

entity koggle_stone_adder is 
generic (
    N : integer := 32;
    lev : integer := 5   -- log2(32) = 5
);
port (
    A : in std_logic_vector(N-1 downto 0);
    B : in std_logic_vector(N-1 downto 0);
    cin : in std_logic;
    S : out std_logic_vector(N-1 downto 0);
    cout : out std_logic
);
end entity;

architecture str of koggle_stone_adder is
    type matrix_array is array(0 to lev) of std_logic_vector(N-1 downto 0);
    signal P_net, G_net : matrix_array;

    component pg_network 
    generic (N : integer);
    port (
        A : in std_logic_vector(N-1 downto 0);
        B : in std_logic_vector(N-1 downto 0);
        cin : in std_logic;
        P : out std_logic_vector(N-1 downto 0);
        G : out std_logic_vector(N-1 downto 0)
    );
    end component;

    component PG_block
    port(
        Pik : in std_logic;
        Gik : in std_logic;
        Pkj : in std_logic;
        Gkj : in std_logic;
        Pij : out std_logic;
        Gij : out std_logic
    );
    end component;

    component G_block
    port(
        Pik : in std_logic;
        Gik : in std_logic;
        Gkj : in std_logic;
        Gij : out std_logic
    );
    end component;

begin

    pg_net: pg_network generic map(N => N)
    port map(A => A, B => B, cin => cin, P => P_net(0), G => G_net(0));

    network: for i in 0 to lev-1 generate
        constant step : integer := 2**i;
    begin

        steps: for j in 0 to N-1 generate

            pass_through: if j < step generate
                P_net(i+1)(j) <= P_net(i)(j);
                G_net(i+1)(j) <= G_net(i)(j);
            end generate pass_through;

            place_block: if j >= step generate
    
                gblock: if (j - step) = 0 generate
                    G: G_block 
                    port map (
                        Pik => P_net(i)(j),
                        Gik => G_net(i)(j),
                        Gkj => G_net(i)(j - step),
                        Gij => G_net(i+1)(j)
                    );
                    P_net(i+1)(j) <= '0';
                end generate gblock;
    
                pgblock: if (j - step) > 0 generate
                    PG: PG_block
                    port map (
                        Pik => P_net(i)(j),
                        Gik => G_net(i)(j),
                        Pkj => P_net(i)(j - step),
                        Gkj => G_net(i)(j - step),
                        Pij => P_net(i+1)(j),
                        Gij => G_net(i+1)(j)
                    );
                end generate pgblock;
    
            end generate place_block;

        end generate steps;
    end generate network;

    S(0) <= P_net(0)(0) xor cin;
    gen_sum: for j in 1 to N-1 generate
        S(j) <= P_net(0)(j) xor G_net(lev)(j-1);
    end generate gen_sum;
    
    cout <= G_net(lev)(N-1);

end str;