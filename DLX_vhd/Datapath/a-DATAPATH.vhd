library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all; 

entity Datapath is
    generic (
        N        : integer := 32;
        REG_ADDR : integer := 5
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;

        -- IRAM
        IRAM_DOut : in  std_logic_vector(N-1 downto 0);
        PC_OUT    : out std_logic_vector(N-1 downto 0);
        
        -- Uscita verso la Control Unit 
        IR_OUT_CU : out std_logic_vector(N-1 downto 0);

        -- SEGNALI DI CONTROLLO DALLA CU

        -- IF Stage Control
        PC_LATCH_EN     : in std_logic;
        IR_LATCH_EN     : in std_logic;
        NPC_LATCH_EN    : in std_logic;
        JUMP_EN         : in std_logic; -
        
        -- ID Stage Control
        RegA_LATCH_EN   : in std_logic;
        RegB_LATCH_EN   : in std_logic;
        RegIMM_LATCH_EN : in std_logic;
        
        -- EX Stage Control
        MUXA_SEL        : in std_logic;
        MUXB_SEL        : in std_logic;
        ALU_OPCODE      : in aluOp;
        ALU_OUTREG_EN   : in std_logic;
        EQ_COND         : in std_logic; -- '1' se è un branch
        
        -- MEM Stage Control
        DRAM_WE         : in std_logic;
        LMD_LATCH_EN    : in std_logic;
        
        -- WB Stage Control
        WB_MUX_SEL      : in std_logic;
        RF_WE           : in std_logic  -- Abilitazione scrittura Register File
    );
end Datapath;

architecture STRUCTURAL of Datapath is
    
    component IFStage
        generic (IR_SIZE : integer := 32; PC_SIZE : integer := 32);
        port (
            Clk          : in  std_logic;
            Rst          : in  std_logic;
            PC_LATCH_EN  : in  std_logic;
            IR_LATCH_EN  : in  std_logic;
            NPC_LATCH_EN : in  std_logic;
            PC_SEL       : in  std_logic;
            IRAM_DOut    : in  std_logic_vector(IR_SIZE-1 downto 0);
            JUMP_TARGET  : in  std_logic_vector(PC_SIZE-1 downto 0);
            PC_OUT       : out std_logic_vector(PC_SIZE-1 downto 0);
            NPC_OUT      : out std_logic_vector(PC_SIZE-1 downto 0);
            IR_OUT       : out std_logic_vector(IR_SIZE-1 downto 0)
        );
    end component;

    component IDStage
        generic (IR_SIZE : integer := 32; N : integer := 32; REG_ADDR : integer := 5);
        port (
            Clk             : in std_logic;
            Rst             : in std_logic;
            RegA_LATCH_EN   : in std_logic;
            RegB_LATCH_EN   : in std_logic;
            RegIMM_LATCH_EN : in std_logic;
            IR_IN           : in std_logic_vector(IR_SIZE-1 downto 0);
            NPC_IN          : in std_logic_vector(N-1 downto 0);
            RF_WE           : in std_logic;
            WB_DATA         : in std_logic_vector(N-1 downto 0);
            WB_DEST_REG     : in std_logic_vector(REG_ADDR-1 downto 0);
            RegA_OUT        : out std_logic_vector(N-1 downto 0);
            RegB_OUT        : out std_logic_vector(N-1 downto 0);
            RegIMM_OUT      : out std_logic_vector(N-1 downto 0);
            JUMP_TARGET_OUT : out std_logic_vector(N-1 downto 0);
            NPC_OUT         : out std_logic_vector(N-1 downto 0);
            OPCODE_OUT      : out std_logic_vector(5 downto 0);
            RD_OUT          : out std_logic_vector(REG_ADDR-1 downto 0)
        );
    end component;

    component EXStage
        generic (N : integer := 32; REG_ADDR : integer := 5);
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

    component MEMStage
        generic (N : integer := 32; REG_ADDR : integer := 5);
        port (
            Clk          : in std_logic;
            Rst          : in std_logic;
            ALU_OUT_IN   : in std_logic_vector(N-1 downto 0);
            RegB_IN      : in std_logic_vector(N-1 downto 0);
            RD_IN        : in std_logic_vector(REG_ADDR-1 downto 0);
            DRAM_WE      : in std_logic;
            LMD_LATCH_EN : in std_logic;
            ALU_OUT_WB   : out std_logic_vector(N-1 downto 0);
            LMD_WB       : out std_logic_vector(N-1 downto 0);
            RD_OUT_WB    : out std_logic_vector(REG_ADDR-1 downto 0)
        );
    end component;

    component WBStage
        generic (N : integer := 32);
        port (
            ALU_OUT_IN  : in std_logic_vector(N-1 downto 0);
            LMD_IN      : in std_logic_vector(N-1 downto 0);
            WB_MUX_SEL  : in std_logic;
            WB_DATA_OUT : out std_logic_vector(N-1 downto 0)
        );
    end component;

    -- SEGNALI 
    
    -- IF -> ID
    signal if_npc_out : std_logic_vector(N-1 downto 0);
    signal if_ir_out  : std_logic_vector(N-1 downto 0);
    signal pc_sel_sig : std_logic;

    -- ID -> EX
    signal id_rega_out        : std_logic_vector(N-1 downto 0);
    signal id_regb_out        : std_logic_vector(N-1 downto 0);
    signal id_regimm_out      : std_logic_vector(N-1 downto 0);
    signal id_jump_target_out : std_logic_vector(N-1 downto 0);
    signal id_npc_out         : std_logic_vector(N-1 downto 0);
    signal id_opcode_out      : std_logic_vector(5 downto 0);
    signal id_rd_out          : std_logic_vector(REG_ADDR-1 downto 0);

    -- EX -> MEM / IF
    signal ex_branch_taken_out : std_logic;
    signal ex_jump_target_out  : std_logic_vector(N-1 downto 0);
    signal ex_alu_out_mem      : std_logic_vector(N-1 downto 0);
    signal ex_regb_out_mem     : std_logic_vector(N-1 downto 0);
    signal ex_rd_out_mem       : std_logic_vector(REG_ADDR-1 downto 0);

    -- MEM -> WB / ID
    signal mem_alu_out_wb : std_logic_vector(N-1 downto 0);
    signal mem_lmd_wb     : std_logic_vector(N-1 downto 0);
    signal mem_rd_out_wb  : std_logic_vector(REG_ADDR-1 downto 0);

    -- WB -> ID
    signal wb_data_out : std_logic_vector(N-1 downto 0);

begin
    -- Il Program Counter salta se l'istruzione è un branch verificato o un jump
    pc_sel_sig <= ex_branch_taken_out or JUMP_EN;
    --IR verso la Control Unit
    IR_OUT_CU <= if_ir_out;

    -
    STAGE_1_IF: IFStage
        generic map (IR_SIZE => N, PC_SIZE => N)
        port map (
            Clk          => Clk,
            Rst          => Rst,
            PC_LATCH_EN  => PC_LATCH_EN,
            IR_LATCH_EN  => IR_LATCH_EN,
            NPC_LATCH_EN => NPC_LATCH_EN,
            PC_SEL       => pc_sel_sig,
            IRAM_DOut    => IRAM_DOut,
            JUMP_TARGET  => ex_jump_target_out, --  da EX
            PC_OUT       => PC_OUT,
            NPC_OUT      => if_npc_out,
            IR_OUT       => if_ir_out
        );

    STAGE_2_ID: IDStage
        generic map (IR_SIZE => N, N => N, REG_ADDR => REG_ADDR)
        port map (
            Clk             => Clk,
            Rst             => Rst,
            RegA_LATCH_EN   => RegA_LATCH_EN,
            RegB_LATCH_EN   => RegB_LATCH_EN,
            RegIMM_LATCH_EN => RegIMM_LATCH_EN,
            IR_IN           => if_ir_out,
            NPC_IN          => if_npc_out,
            RF_WE           => RF_WE,             
            WB_DATA         => wb_data_out,       -- Dal WB Stage
            WB_DEST_REG     => mem_rd_out_wb,     -- Dal MEM Stage
            RegA_OUT        => id_rega_out,
            RegB_OUT        => id_regb_out,
            RegIMM_OUT      => id_regimm_out,
            JUMP_TARGET_OUT => id_jump_target_out,
            NPC_OUT         => id_npc_out,
            OPCODE_OUT      => id_opcode_out,
            RD_OUT          => id_rd_out
        );

    STAGE_3_EX: EXStage
        generic map (N => N, REG_ADDR => REG_ADDR)
        port map (
            Clk              => Clk,
            Rst              => Rst,
            RegA_IN          => id_rega_out,
            RegB_IN          => id_regb_out,
            RegIMM_IN        => id_regimm_out,
            JUMP_TARGET_IN   => id_jump_target_out,
            NPC_IN           => id_npc_out,
            OPCODE_IN        => id_opcode_out,
            RD_IN            => id_rd_out,
            MUXA_SEL         => MUXA_SEL,
            MUXB_SEL         => MUXB_SEL,
            ALU_OPCODE       => ALU_OPCODE,
            ALU_OUTREG_EN    => ALU_OUTREG_EN,
            EQ_COND          => EQ_COND,
            BRANCH_TAKEN_OUT => ex_branch_taken_out,
            ALU_OUT_MEM      => ex_alu_out_mem,
            RegB_OUT_MEM     => ex_regb_out_mem,
            JUMP_TARGET_OUT  => ex_jump_target_out,
            RD_OUT_MEM       => ex_rd_out_mem
        );

    STAGE_4_MEM: MEMStage
        generic map (N => N, REG_ADDR => REG_ADDR)
        port map (
            Clk          => Clk,
            Rst          => Rst,
            ALU_OUT_IN   => ex_alu_out_mem,
            RegB_IN      => ex_regb_out_mem,
            RD_IN        => ex_rd_out_mem,
            DRAM_WE      => DRAM_WE,
            LMD_LATCH_EN => LMD_LATCH_EN,
            ALU_OUT_WB   => mem_alu_out_wb,
            LMD_WB       => mem_lmd_wb,
            RD_OUT_WB    => mem_rd_out_wb
        );

    STAGE_5_WB: WBStage
        generic map (N => N)
        port map (
            ALU_OUT_IN  => mem_alu_out_wb,
            LMD_IN      => mem_lmd_wb,
            WB_MUX_SEL  => WB_MUX_SEL,
            WB_DATA_OUT => wb_data_out
        );

end STRUCTURAL;