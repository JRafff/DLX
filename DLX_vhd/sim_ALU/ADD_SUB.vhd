library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ADD_SUB is
    generic(
        Nbit : integer := 32
    );
    port (
        nADD_sub : in  std_logic; -- 0 = add, 1 = sub
        A        : in  std_logic_vector(Nbit-1 downto 0);
        B        : in  std_logic_vector(Nbit-1 downto 0); 
        S        : out std_logic_vector(Nbit-1 downto 0); 
        cout     : out std_logic; -- AGGIUNTO ; QUI
        -- flags
        N        : out std_logic;
        V        : out std_logic;
        Z        : out std_logic  
    );
end entity;

architecture str of ADD_SUB IS
    
    signal b_xor : std_logic_vector(Nbit-1 downto 0);
    signal S_int : std_logic_vector(Nbit-1 downto 0); 
    
    component koggle_stone_adder is
        generic (
            N : integer := 32 
        );
        port (
            A    : in  std_logic_vector(N-1 downto 0);
            B    : in  std_logic_vector(N-1 downto 0);
            cin  : in  std_logic;
            S    : out std_logic_vector(N-1 downto 0);
            cout : out std_logic
        );
    end component;

begin

    add_sub_gen: for i in 0 to Nbit-1 generate
        b_xor(i) <= B(i) xor nADD_sub;
    end generate add_sub_gen;

    adder: koggle_stone_adder 
        generic map (
            N => Nbit
        )
        port map (
            A    => A,
            B    => b_xor,
            cin  => nADD_sub, 
            S    => S_int, 
            cout => cout
        );
    
  
    S <= S_int;
    
    --flags
    N <= S_int(Nbit-1); -- sign flag
    V <= (A(Nbit-1) xnor b_xor(Nbit-1)) and (A(Nbit-1) xor S_int(Nbit-1)); --overflow flag
    Z <= '1' when S_int = (Nbit-1 downto 0 => '0') else '0';  --zero flag

end str;