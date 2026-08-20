library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all; 

-- Execute stage 
entity EXStage is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;                           

        -- Dati in ingresso (dal registro ID/EX)
        RegA_IN        : in std_logic_vector(N-1 downto 0);
        RegB_IN        : in std_logic_vector(N-1 downto 0);
        RegIMM_IN      : in std_logic_vector(N-1 downto 0);
        JUMP_TARGET_IN : in std_logic_vector(N-1 downto 0);  
        NPC_IN         : in std_logic_vector(N-1 downto 0);
        OPCODE_IN      : in std_logic_vector(5 downto 0);
        RD_IN          : in std_logic_vector(REG_ADDR-1 downto 0);

        -- Segnali di Controllo 
        MUXA_SEL       : in std_logic;
        MUXB_SEL       : in std_logic;
        ALU_OPCODE     : in aluOp;
        ALU_OUTREG_EN  : in std_logic;
        EQ_COND        : in std_logic; -- '1' se è un branch 

        -- Uscita verso la decode  (Per il MUX del PC_SEL)
        BRANCH_TAKEN_OUT : out std_logic;

        -- Uscite verso MEM (Latched at end of EX)
        ALU_OUT_MEM       : out std_logic_vector(N-1 downto 0);
        RegB_OUT_MEM      : out std_logic_vector(N-1 downto 0);
        JUMP_TARGET_OUT   : out std_logic_vector(N-1 downto 0);
        RD_OUT_MEM        : out std_logic_vector(REG_ADDR-1 downto 0)
    );
end EXStage;

architecture STRUCTURAL of EXStage is

    component alu
        generic(
            Nbit: integer := 32
        );
        port(
            A          : in  std_logic_vector(Nbit-1 downto 0);
            B          : in  std_logic_vector(Nbit-1 downto 0);
            ALU_OPCODE : in  aluOp;
            Alu_out    : out std_logic_vector(Nbit-1 downto 0)
        );
    end component;

    component zero_check
        generic (NBIT : integer := 32);
        port (
            D_IN     : in  std_logic_vector(NBIT-1 downto 0);
            OPCODE   : in  std_logic_vector(5 downto 0);
            COND_OUT : out std_logic
        );
    end component;

    component reg_en
        generic (NBIT : integer := 32);
        port (
            Clk : in  std_logic;
            Rst : in  std_logic;
            EN  : in  std_logic;
            D   : in  std_logic_vector(NBIT-1 downto 0);
            Q   : out std_logic_vector(NBIT-1 downto 0)
        );
    end component;

    -- Segnali interni per i MUX e per la ALU
    signal mux_a_out  : std_logic_vector(N-1 downto 0);
    signal mux_b_out  : std_logic_vector(N-1 downto 0);
    signal alu_result : std_logic_vector(N-1 downto 0);
    
    -- Segnale interno per l'uscita dello Zero Checker
    signal cond_true  : std_logic;

begin

    mux_a_out <= RegA_IN when (MUXA_SEL = '0') else NPC_IN;
    mux_b_out <= RegB_IN when (MUXB_SEL = '0') else RegIMM_IN;

    ALU_I: alu
        generic map (Nbit => N)
        port map (
            A          => mux_a_out,
            B          => mux_b_out,
            ALU_OPCODE => ALU_OPCODE,
            Alu_out    => alu_result
        );

    ZC_I: zero_check
        generic map (NBIT => N)
        port map (
            D_IN     => RegA_IN,
            OPCODE   => OPCODE_IN,
            COND_OUT => cond_true
        );

    -- L'uscita BRANCH_TAKEN_OUT e l'indirizzo calcolato nella decode tornano indietro allo stadio IF.
    BRANCH_TAKEN_OUT <= EQ_COND and cond_true;
    JUMP_TARGET_OUT <= JUMP_TARGET_IN;

    
    -- Salva il risultato della ALU
    ALU_RES_R: reg_en
        generic map (NBIT => N)
        port map (Clk => Clk, Rst => Rst, EN => ALU_OUTREG_EN, D => alu_result, Q => ALU_OUT_MEM);

    REGB_R: reg_en
        generic map (NBIT => N)
        port map (Clk => Clk, Rst => Rst, EN => ALU_OUTREG_EN, D => RegB_IN, Q => RegB_OUT_MEM);

    RD_R: reg_en
        generic map (NBIT => REG_ADDR)
        port map (Clk => Clk, Rst => Rst, EN => ALU_OUTREG_EN, D => RD_IN, Q => RD_OUT_MEM);

end STRUCTURAL;

