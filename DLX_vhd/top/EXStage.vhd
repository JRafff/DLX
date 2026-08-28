library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all; 

entity EXStage is
    generic (
        N : integer := 32
    );
    port (
        -- da id_exe
        RegA_IN        : in  std_logic_vector(N-1 downto 0); -- Dato base dal RF
        RegB_IN        : in  std_logic_vector(N-1 downto 0); -- Dato base dal RF
        RegIMM_IN      : in  std_logic_vector(N-1 downto 0); -- Immediato esteso
        NPC_IN         : in  std_logic_vector(N-1 downto 0); -- Next PC (usato per JAL)
        -- forwarding
        FWD_EX_MEM_IN  : in  std_logic_vector(N-1 downto 0); -- Risultato appena calcolato in EX
        FWD_MEM_WB_IN  : in  std_logic_vector(N-1 downto 0); -- Risultato proveniente dalla Memoria/WB
        -- Dalla Control Unit
        MUXA_SEL       : in  std_logic; -- 0 -> RegA, 1 -> NPC
        MUXB_SEL       : in  std_logic; -- 0 -> RegB, 1 -> IMM
        ALU_OPCODE     : in  aluOp;     -- Operazione da eseguire   
        -- Dalla Forwarding Unit
        FORWARD_A      : in  std_logic_vector(1 downto 0); -- Selettore MUX FWD A
        FORWARD_B      : in  std_logic_vector(1 downto 0); -- Selettore MUX FWD B


        ALU_OUT        : out std_logic_vector(N-1 downto 0);
        DATA_TO_STORE  : out std_logic_vector(N-1 downto 0)  -- RegB dopo il forwarding (per le SW)
    );
end EXStage;

architecture STRUCTURAL of EXStage is

    -- ALU
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

    -- Segnali intermedi per la cascata di MUX
    signal a_fwd       : std_logic_vector(N-1 downto 0);
    signal b_fwd       : std_logic_vector(N-1 downto 0);
    
    signal alu_mux_a   : std_logic_vector(N-1 downto 0);
    signal alu_mux_b   : std_logic_vector(N-1 downto 0);

begin

    -- forwarding muxs
    with FORWARD_A select
        a_fwd <= FWD_EX_MEM_IN when "10", -- Dato calcolato 1 ciclo fa (in MEM)
                 FWD_MEM_WB_IN when "01", -- Dato calcolato 2 cicli fa (in WB)
                 RegA_IN       when others; -- Nessun hazard, usa il dato letto dal RF

    -- Selezione dato per l'ingresso B
    with FORWARD_B select
        b_fwd <= FWD_EX_MEM_IN when "10",
                 FWD_MEM_WB_IN when "01",
                 RegB_IN       when others;

-- store
    DATA_TO_STORE <= b_fwd;


    -- MUX comandati dalla Control Unit che finiscono nell'alu
    alu_mux_a <= NPC_IN    when (MUXA_SEL = '1') else a_fwd;
    alu_mux_b <= RegIMM_IN when (MUXB_SEL = '1') else b_fwd;


    ALU_I: alu
        generic map (Nbit => N)
        port map (
            A          => alu_mux_a,
            B          => alu_mux_b,
            ALU_OPCODE => ALU_OPCODE,
            Alu_out    => ALU_OUT
        );

end STRUCTURAL;