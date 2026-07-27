library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all; 

entity tb_alu is
end entity;

architecture tb of tb_alu is

    signal A_tb          : std_logic_vector(31 downto 0) := (others => '0');
    signal B_tb          : std_logic_vector(31 downto 0) := (others => '0');
    signal ALU_OPCODE_tb : aluOp := NOP;
    signal ALU_OUT_tb    : std_logic_vector(31 downto 0);
    
    signal golden_out    : std_logic_vector(31 downto 0) := (others => '0');

    constant PERIOD      : time := 10 ns;

begin

    -- Istanziazione della ALU
    UUT: entity work.alu
        generic map (
            Nbit => 32
        )
        port map (
            A          => A_tb,
            B          => B_tb,
            ALU_OPCODE => ALU_OPCODE_tb,
            Alu_out    => ALU_OUT_tb
        );

    -- PROCESSO GOLDEN MODEL 
    golden_proc: process(A_tb, B_tb, ALU_OPCODE_tb)
        variable a_int, b_int : integer;
        variable res_sig      : signed(31 downto 0);
    begin
        a_int := to_integer(signed(A_tb));
        b_int := to_integer(signed(B_tb));
        res_sig := (others => '0');

        case ALU_OPCODE_tb is
            when ADDS =>
                res_sig := signed(A_tb) + signed(B_tb);
            when SUBS =>
                res_sig := signed(A_tb) - signed(B_tb);
            when ANDS =>
                res_sig := signed(A_tb and B_tb);
            when ORS =>
                res_sig := signed(A_tb or B_tb);
            when XORS =>
                res_sig := signed(A_tb xor B_tb);
            when LLS =>
                -- Esempio di shift logico a sinistra (prende i bit bassi di B)
                res_sig := shift_left(signed(A_tb), to_integer(unsigned(B_tb(4 downto 0))));
            when LRS =>
                res_sig := shift_right(signed(A_tb), to_integer(unsigned(B_tb(4 downto 0))));
            when SGES =>
                if a_int >= b_int then res_sig := to_signed(1, 32); else res_sig := to_signed(0, 32); end if;
            when SLES =>
                if a_int <= b_int then res_sig := to_signed(1, 32); else res_sig := to_signed(0, 32); end if;
            when SNES =>
                if a_int /= b_int then res_sig := to_signed(1, 32); else res_sig := to_signed(0, 32); end if;
            when others =>
                res_sig := (others => '0');
        end case;

        golden_out <= std_logic_vector(res_sig);
    end process;

   stimulus: process
    begin
        -- Inizializzazione 
        ALU_OPCODE_tb <= NOP;
        A_tb <= x"00000000";
        B_tb <= x"00000000";
        wait for PERIOD;

        -- 1. ADDS base -> 10 + 5 = 15
        A_tb          <= std_logic_vector(to_signed(10, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= ADDS;
        wait for PERIOD;

        -- 2. ADDS con Negativi -> -20 + 15 = -5
        A_tb          <= std_logic_vector(to_signed(-20, 32));
        B_tb          <= std_logic_vector(to_signed(15, 32));
        ALU_OPCODE_tb <= ADDS;
        wait for PERIOD;

        -- 3. SUBS base -> 10 - 5 = 5
        A_tb          <= std_logic_vector(to_signed(10, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= SUBS;
        wait for PERIOD;

        -- 4. SUBS con Negativi -> -10 - (-15) = 5
        A_tb          <= std_logic_vector(to_signed(-10, 32));
        B_tb          <= std_logic_vector(to_signed(-15, 32));
        ALU_OPCODE_tb <= SUBS;
        wait for PERIOD;

        -- 5. ANDS -> 0xFF00 & 0x0FF0
        A_tb          <= x"0000FF00";
        B_tb          <= x"00000FF0";
        ALU_OPCODE_tb <= ANDS;
        wait for PERIOD;

        -- 6. ORS -> 0xF0F0 | 0x0F0F
        A_tb          <= x"0000F0F0";
        B_tb          <= x"00000F0F";
        ALU_OPCODE_tb <= ORS;
        wait for PERIOD;

        -- 7. XORS -> 0xFFFF xor 0x0FF0
        A_tb          <= x"0000FFFF";
        B_tb          <= x"00000FF0";
        ALU_OPCODE_tb <= XORS;
        wait for PERIOD;

        -- 8. LLS (Shift a sinistra) -> 0x00000001 << 4 = 0x10
        A_tb          <= x"00000001";
        B_tb          <= std_logic_vector(to_signed(4, 32));
        ALU_OPCODE_tb <= LLS;
        wait for PERIOD;

        -- 9. LRS (Shift a destra) -> 0x000000F0 >> 4 = 0xF
        A_tb          <= x"000000F0";
        B_tb          <= std_logic_vector(to_signed(4, 32));
        ALU_OPCODE_tb <= LRS;
        wait for PERIOD;

        -- 10. SGES (Vero) -> 10 >= 5 (Dovrebbe dare 1)
        A_tb          <= std_logic_vector(to_signed(10, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= SGES;
        wait for PERIOD;

        -- 11. SGES (Falso) -> 3 >= 5 (Dovrebbe dare 0)
        A_tb          <= std_logic_vector(to_signed(3, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= SGES;
        wait for PERIOD;

        -- 12. SLES (Vero con uguali) -> 5 <= 5 (Dovrebbe dare 1)
        A_tb          <= std_logic_vector(to_signed(5, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= SLES;
        wait for PERIOD;

        -- 13. SLES (Falso) -> 12 <= 5 (Dovrebbe dare 0)
        A_tb          <= std_logic_vector(to_signed(12, 32));
        B_tb          <= std_logic_vector(to_signed(5, 32));
        ALU_OPCODE_tb <= SLES;
        wait for PERIOD;

        -- 14. SNES (Uguali, quindi Not-Equal dà 0) -> 10 != 10
        A_tb          <= std_logic_vector(to_signed(10, 32));
        B_tb          <= std_logic_vector(to_signed(10, 32));
        ALU_OPCODE_tb <= SNES;
        wait for PERIOD;

        -- 15. SNES (Diversi, quindi Not-Equal dà 1) -> 10 != 20
        A_tb          <= std_logic_vector(to_signed(10, 32));
        B_tb          <= std_logic_vector(to_signed(20, 32));
        ALU_OPCODE_tb <= SNES;
        wait for PERIOD;

        -- Fine della simulazione
        ALU_OPCODE_tb <= NOP;
        wait; 
    end process;

end tb;