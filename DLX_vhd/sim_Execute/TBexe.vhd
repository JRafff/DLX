library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all; 

entity tb_EXStage is
end tb_EXStage;

architecture BEHAVIORAL of tb_EXStage is

    constant N        : integer := 32;
    constant REG_ADDR : integer := 5;
    constant CLK_PERIOD : time := 10 ns;

    component EXStage
        generic (
            N        : integer := 32;
            REG_ADDR : integer := 5
        );
        port (
            Clk              : in std_logic;
            Rst              : in std_logic;
            RegA_IN          : in std_logic_vector(N-1 downto 0);
            RegB_IN          : in std_logic_vector(N-1 downto 0);
            RegIMM_IN        : in std_logic_vector(N-1 downto 0);
            JUMP_TARGET_IN   : in std_logic_vector(N-1 downto 0);  
            NPC_IN           : in std_logic_vector(N-1 downto 0);
            OPCODE_IN        : in std_logic_vector(5 downto 0);
            RD_IN            : in std_logic_vector(REG_ADDR-1 downto 0);
            MUXA_SEL         : in std_logic;
            MUXB_SEL         : in std_logic;
            ALU_OPCODE       : in aluOp;
            ALU_OUTREG_EN    : in std_logic;
            EQ_COND          : in std_logic;
            BRANCH_TAKEN_OUT : out std_logic;
            ALU_OUT_MEM      : out std_logic_vector(N-1 downto 0);
            RegB_OUT_MEM     : out std_logic_vector(N-1 downto 0);
            JUMP_TARGET_OUT  : out std_logic_vector(N-1 downto 0);
            RD_OUT_MEM       : out std_logic_vector(REG_ADDR-1 downto 0)
        );
    end component;

    signal Clk              : std_logic := '0';
    signal Rst              : std_logic := '1'; -- Partiamo con Rst disattivo (Active-Low)
    signal RegA_IN          : std_logic_vector(N-1 downto 0) := (others => '0');
    signal RegB_IN          : std_logic_vector(N-1 downto 0) := (others => '0');
    signal RegIMM_IN        : std_logic_vector(N-1 downto 0) := (others => '0');
    signal JUMP_TARGET_IN   : std_logic_vector(N-1 downto 0) := (others => '0');
    signal NPC_IN           : std_logic_vector(N-1 downto 0) := (others => '0');
    signal OPCODE_IN        : std_logic_vector(5 downto 0)   := (others => '0');
    signal RD_IN            : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');
    
    signal MUXA_SEL         : std_logic := '0';
    signal MUXB_SEL         : std_logic := '0';
    signal ALU_OPCODE       : aluOp := NOP; 
    signal ALU_OUTREG_EN    : std_logic := '0';
    signal EQ_COND          : std_logic := '0';

    signal uut_BRANCH_TAKEN_OUT : std_logic;
    signal uut_ALU_OUT_MEM      : std_logic_vector(N-1 downto 0);
    signal uut_RegB_OUT_MEM     : std_logic_vector(N-1 downto 0);
    signal uut_JUMP_TARGET_OUT  : std_logic_vector(N-1 downto 0);
    signal uut_RD_OUT_MEM       : std_logic_vector(REG_ADDR-1 downto 0);

    -- GOLDEN MODEL
    signal exp_mux_a            : std_logic_vector(N-1 downto 0);
    signal exp_mux_b            : std_logic_vector(N-1 downto 0);
    signal exp_alu_comb         : std_logic_vector(N-1 downto 0);
    signal exp_is_zero          : std_logic;
    signal exp_cond_true        : std_logic;
    
    signal exp_BRANCH_TAKEN_OUT : std_logic;
    signal exp_JUMP_TARGET_OUT  : std_logic_vector(N-1 downto 0);
    signal exp_ALU_OUT_MEM      : std_logic_vector(N-1 downto 0) := (others => '0');
    signal exp_RegB_OUT_MEM     : std_logic_vector(N-1 downto 0) := (others => '0');
    signal exp_RD_OUT_MEM       : std_logic_vector(REG_ADDR-1 downto 0) := (others => '0');

    -- Flag per terminare la simulazione pulita
    signal end_of_sim           : boolean := false;

begin

    UUT: EXStage
        port map (
            Clk              => Clk,
            Rst              => Rst,
            RegA_IN          => RegA_IN,
            RegB_IN          => RegB_IN,
            RegIMM_IN        => RegIMM_IN,
            JUMP_TARGET_IN   => JUMP_TARGET_IN,
            NPC_IN           => NPC_IN,
            OPCODE_IN        => OPCODE_IN,
            RD_IN            => RD_IN,
            MUXA_SEL         => MUXA_SEL,
            MUXB_SEL         => MUXB_SEL,
            ALU_OPCODE       => ALU_OPCODE,
            ALU_OUTREG_EN    => ALU_OUTREG_EN,
            EQ_COND          => EQ_COND,
            BRANCH_TAKEN_OUT => uut_BRANCH_TAKEN_OUT,
            ALU_OUT_MEM      => uut_ALU_OUT_MEM,
            RegB_OUT_MEM     => uut_RegB_OUT_MEM,
            JUMP_TARGET_OUT  => uut_JUMP_TARGET_OUT,
            RD_OUT_MEM       => uut_RD_OUT_MEM
        );

    -- Clock (si ferma quando end_of_sim diventa true)
    clk_process : process
    begin
        while not end_of_sim loop
            Clk <= '0';
            wait for CLK_PERIOD/2;
            Clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- GOLDEN MODEL
    exp_mux_a <= RegA_IN when (MUXA_SEL = '0') else NPC_IN;
    exp_mux_b <= RegB_IN when (MUXB_SEL = '0') else RegIMM_IN;

    process(exp_mux_a, exp_mux_b, ALU_OPCODE)
        variable a_int, b_int : integer;
        variable res_sig      : signed(N-1 downto 0);
    begin
        a_int := to_integer(signed(exp_mux_a));
        b_int := to_integer(signed(exp_mux_b));
        res_sig := (others => '0');

        case ALU_OPCODE is
            when ADDS => res_sig := signed(exp_mux_a) + signed(exp_mux_b);
            when SUBS => res_sig := signed(exp_mux_a) - signed(exp_mux_b);
            when ANDS => res_sig := signed(exp_mux_a and exp_mux_b);
            when ORS  => res_sig := signed(exp_mux_a or exp_mux_b);
            when XORS => res_sig := signed(exp_mux_a xor exp_mux_b);
            when LLS  => res_sig := shift_left(signed(exp_mux_a), to_integer(unsigned(exp_mux_b(4 downto 0))));
            when LRS  => res_sig := shift_right(signed(exp_mux_a), to_integer(unsigned(exp_mux_b(4 downto 0))));
            when SGES => if a_int >= b_int then res_sig := to_signed(1, N); else res_sig := to_signed(0, N); end if;
            when SLES => if a_int <= b_int then res_sig := to_signed(1, N); else res_sig := to_signed(0, N); end if;
            when SNES => if a_int /= b_int then res_sig := to_signed(1, N); else res_sig := to_signed(0, N); end if;
            when others => res_sig := (others => '0');
        end case;

        exp_alu_comb <= std_logic_vector(res_sig);
    end process;

    exp_is_zero   <= '1' when (RegA_IN = x"00000000") else '0';
    exp_cond_true <= exp_is_zero when (OPCODE_IN(0) = '0') else not(exp_is_zero);
    exp_BRANCH_TAKEN_OUT <= EQ_COND and exp_cond_true;
    exp_JUMP_TARGET_OUT  <= JUMP_TARGET_IN;

    process(Clk, Rst)
    begin
        if Rst = '0' then
            exp_ALU_OUT_MEM  <= (others => '0');
            exp_RegB_OUT_MEM <= (others => '0');
            exp_RD_OUT_MEM   <= (others => '0');
        elsif rising_edge(Clk) then
            if ALU_OUTREG_EN = '1' then
                exp_ALU_OUT_MEM  <= exp_alu_comb;
                exp_RegB_OUT_MEM <= RegB_IN;
                exp_RD_OUT_MEM   <= RD_IN;
            end if;
        end if;
    end process;
    
    -- CHECK AUTOMATICO
    process
    begin
        while not end_of_sim loop
            wait until falling_edge(Clk); 
            if Rst = '1' then
                assert (uut_BRANCH_TAKEN_OUT = exp_BRANCH_TAKEN_OUT) report "Errore: BRANCH_TAKEN_OUT non corrisponde!" severity error;
                assert (uut_JUMP_TARGET_OUT = exp_JUMP_TARGET_OUT) report "Errore: JUMP_TARGET_OUT non corrisponde!" severity error;
                assert (uut_ALU_OUT_MEM = exp_ALU_OUT_MEM) report "Errore: ALU_OUT_MEM non corrisponde!" severity error;
                assert (uut_RegB_OUT_MEM = exp_RegB_OUT_MEM) report "Errore: RegB_OUT_MEM non corrisponde!" severity error;
                assert (uut_RD_OUT_MEM = exp_RD_OUT_MEM) report "Errore: RD_OUT_MEM non corrisponde!" severity error;
            end if;
        end loop;
        wait;
    end process;
    
    -- STIMOLO
    stim_proc: process
    begin
        -- Reset attivo basso
        Rst <= '0';
        wait for CLK_PERIOD * 2;
        Rst <= '1';
        wait for CLK_PERIOD;

        -- R-Type (ADD)
        RegA_IN       <= std_logic_vector(to_signed(10, 32)); 
        RegB_IN       <= std_logic_vector(to_signed(5, 32)); 
        RD_IN         <= "00001";     
        MUXA_SEL      <= '0';
        MUXB_SEL      <= '0';
        ALU_OPCODE    <= ADDS;
        EQ_COND       <= '0';
        ALU_OUTREG_EN <= '1';
        wait for CLK_PERIOD;

        -- I-Type (SLLI)
        RegA_IN       <= x"00000001"; 
        RegIMM_IN     <= std_logic_vector(to_signed(4, 32)); 
        RegB_IN       <= x"DEADBEEF"; 
        RD_IN         <= "00010";     
        MUXA_SEL      <= '0';
        MUXB_SEL      <= '1'; 
        ALU_OPCODE    <= LLS; 
        wait for CLK_PERIOD;

        -- SLE
        RegA_IN       <= std_logic_vector(to_signed(5, 32)); 
        RegB_IN       <= std_logic_vector(to_signed(10, 32)); 
        RD_IN         <= "00011";     
        MUXA_SEL      <= '0';
        MUXB_SEL      <= '0';
        ALU_OPCODE    <= SLES; 
        wait for CLK_PERIOD;

        -- Branch BEQZ
        RegA_IN       <= x"00000000"; 
        OPCODE_IN     <= "000100";    
        JUMP_TARGET_IN<= x"000000F0"; 
        EQ_COND       <= '1';
        ALU_OPCODE    <= NOP;
        wait for CLK_PERIOD;

        -- JAL
        NPC_IN        <= x"00000400";
        RegIMM_IN     <= x"00000000"; 
        MUXA_SEL      <= '1';         
        MUXB_SEL      <= '1';         
        ALU_OPCODE    <= ADDS;
        EQ_COND       <= '0';
        wait for CLK_PERIOD;

        -- Fine simulazione pulita
        end_of_sim <= true;
        report "SIMULAZIONE COMPLETATA SENZA ERRORI!" severity note;
        wait;
    end process;

end BEHAVIORAL;