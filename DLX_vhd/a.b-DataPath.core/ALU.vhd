library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity alu is
    generic(
        Nbit: integer := 32
    );
    port(
        A : in std_logic_vector(Nbit-1 downto 0);
        B : in std_logic_vector(Nbit-1 downto 0);
        ALU_OPCODE : in aluOp;
        Alu_out : out std_logic_vector(Nbit-1 downto 0)

    );
end entity;

architecture str of alu is
    -- signals and components
    signal out_adder   : std_logic_vector(31 downto 0);
    signal out_shifter : std_logic_vector(31 downto 0);
    signal out_logic, out_compare_neq : std_logic_vector(31 downto 0);

    signal flag_N,flag_Z,flag_V : std_logic;
    --Fili per i controlli 
    signal ctrl_add_sub   : std_logic;
    signal ctrl_left_right: std_logic;
    signal ctrl_logic: std_logic_vector(1 downto 0);

    component ADD_SUB 
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
end component;

component comparator_eq 
    generic(
        Nbit : integer := 32
    );
    port (
        A        : in  std_logic_vector(Nbit-1 downto 0);
        B        : in  std_logic_vector(Nbit-1 downto 0); 
        eq_out   : out std_logic_vector(Nbit-1 downto 0)  
    );
end component;

component shifter is 
    generic(
        Nbit : integer := 32 
    );
    port(
        nLeft_right : in  std_logic; -- 0 = left, 1 = right
        A           : in  std_logic_vector(Nbit-1 downto 0);
        B           : in  std_logic_vector(Nbit-1 downto 0); 
        shift_out   : out std_logic_vector(Nbit-1 downto 0)  
    );
end component;

component logic is 
    generic(
        Nbit : integer := 32 
    );
    port(
        logic_sel : in  std_logic_vector(1 downto 0); -- 2 bit per 4 operazioni
        A         : in  std_logic_vector(Nbit-1 downto 0);
        B         : in  std_logic_vector(Nbit-1 downto 0); 
        logic_out : out std_logic_vector(Nbit-1 downto 0)  
    );
end component;

    begin

        ADDER: ADD_SUB port map (
        nADD_sub => ctrl_add_sub,
        A        => A,
        B        => B,
        S        => out_adder,
        cout     => open,      -- Il sintetizzatore lo taglierÃ  via!
        N        => flag_N,
        Z        => flag_Z,
        V        => flag_V
        );
        LOGICs: logic 
        generic map (
            Nbit => 32
        )
        port map (
            A    => A,
            B    => B,
            logic_sel  => ctrl_logic, -- Guidato dal MUX dell'Opcode
            logic_out    => out_logic   -- Esce e va al MUX
        );

        COMPARE_EQ: comparator_eq 
        generic map (
            Nbit => 32
        )
        port map (
            A      => A,
            B      => B,
            eq_out => out_compare_neq -- Esce e va al MUX
        );
        SHIFTERs: shifter 
        generic map (
            Nbit => 32
        )
        port map (
            nLeft_right => ctrl_left_right, -- Guidato dal MUX dell'Opcode
            A           => A,
            B           => B,
            shift_out   => out_shifter      -- Esce e va al MUX
        );


        alu_proc: process(ALU_OPCODE, out_adder, out_logic, out_shifter, out_compare_neq, flag_N, flag_V, flag_Z)
        begin
            ctrl_add_sub    <= '0'; 
            ctrl_logic      <= "00";
            ctrl_left_right <= '0';
            ALU_OUT         <= (others => '0');

            case ALU_OPCODE is
                
                when NOP =>
                    ctrl_add_sub    <= '0'; 
                    ctrl_logic      <= "00";
                    ctrl_left_right <= '0';
                    ALU_OUT         <= (others => '0');

                when ADDS =>
                    ctrl_add_sub <= '0';        
                    ALU_OUT      <= out_adder;  
                when SUBS =>
                    ctrl_add_sub <= '1';        
                    ALU_OUT      <= out_adder;  


                when ANDS =>
                    ctrl_logic <= "00";        
                    ALU_OUT      <= out_logic;  
                when ORS =>
                    ctrl_logic <= "01";        
                    ALU_OUT      <= out_logic; 
                when XORS =>
                    ctrl_logic <= "10";        
                    ALU_OUT      <= out_logic; 
                    
                    
                when LLS =>
                    ctrl_left_right <= '0';        
                    ALU_OUT      <= out_shifter; 
                when LRS =>
                    ctrl_left_right <= '1';        
                    ALU_OUT      <= out_shifter; 
                

                when SGES =>
                    ctrl_add_sub <= '1';        
                    ALU_OUT(Nbit-1 downto 1) <= (others => '0');  
                    ALU_OUT(0) <= not (flag_N xor flag_V);
                when SLES =>
                    ctrl_add_sub <= '1';        
                    ALU_OUT(Nbit-1 downto 1) <= (others => '0');  
                    ALU_OUT(0) <= (flag_N xor flag_V) or flag_Z;


                when SNES =>
                    ALU_OUT      <= out_compare_neq; --equal da controllare

                when others =>
                    ALU_OUT <= (others => '0');
                
                
            end case;
        end process alu_proc;

    end str;