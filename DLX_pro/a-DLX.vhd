library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all;

-- ==========================================================================
--  DLX-pro top-level
--
--  Cinque stadi (IF, ID, EX, MEM, WB), quattro registri di pipeline
--  (IF/ID, ID/EX, EX/MEM, MEM/WB), Control Unit hardwired con pipeline
--  interna dei segnali di controllo (cw1/cw2/cw3), Branch Prediction (BTB),
--  I-Cache 4-way + IRAM sincrona con handshake, DRAM sincrona,
--  Forwarding Unit e Hazard Detection Unit.
--
--  Il file NON descrive logica: colleziona segnali e li instrada. Ogni
--  blocco funzionale e' definito nei file numerati 01-* .. 07-*.
-- ==========================================================================

entity DLX is
  generic (
    IR_SIZE  : integer := 32;
    PC_SIZE  : integer := 32;
    REG_ADDR : integer := 5
  );
  port (
    Clk : in std_logic;
    Rst : in std_logic;   -- active low
    TEST_PC_OUT : out std_logic_vector(PC_SIZE-1 downto 0);
    TEST_ALU_OUT : out std_logic_vector(IR_SIZE-1 downto 0)
  );
end DLX;

architecture STRUCTURAL of DLX is

  -- ---------- Component declarations ----------
  component IFStage
    generic (IR_SIZE : integer := 32; PC_SIZE : integer := 32);
    port (
      Clk                 : in  std_logic;
      Rst                 : in  std_logic;
      PC_LATCH_EN         : in  std_logic;
      mispredict_in       : in  std_logic;
      update_en_in        : in  std_logic;
      actual_taken_in     : in  std_logic;
      recovery_address_in : in  std_logic_vector(PC_SIZE-1 downto 0);
      pc_update_in        : in  std_logic_vector(PC_SIZE-1 downto 0);
      PC_OUT              : out std_logic_vector(PC_SIZE-1 downto 0);
      NPC_OUT             : out std_logic_vector(PC_SIZE-1 downto 0);
      IR_OUT              : out std_logic_vector(IR_SIZE-1 downto 0);
      TAKEN_OUT           : out std_logic;
      cache_miss_out      : out std_logic
    );
  end component;

  component IF_ID_reg
    generic (N : integer := 32);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      en        : in  std_logic;
      clear     : in  std_logic;
      pc_in     : in  std_logic_vector(N-1 downto 0);
      npc_in    : in  std_logic_vector(N-1 downto 0);
      ir_in     : in  std_logic_vector(N-1 downto 0);
      taken_in  : in  std_logic;
      pc_out    : out std_logic_vector(N-1 downto 0);
      npc_out   : out std_logic_vector(N-1 downto 0);
      ir_out    : out std_logic_vector(N-1 downto 0);
      taken_out : out std_logic
    );
  end component;

  component IDStage
    generic (IR_SIZE : integer := 32; N : integer := 32; REG_ADDR : integer := 5);
    port (
      Clk              : in  std_logic;
      Rst              : in  std_logic;
      jump_en          : in  std_logic;
      eq_cond          : in  std_logic;
      IR_IN            : in  std_logic_vector(IR_SIZE-1 downto 0);
      NPC_IN           : in  std_logic_vector(N-1 downto 0);
      PC_IN            : in  std_logic_vector(N-1 downto 0);
      taken_in         : in  std_logic;
      mispredict_out   : out std_logic;
      update_en_out    : out std_logic;
      actual_taken_out : out std_logic;
      recovery_addr_out: out std_logic_vector(N-1 downto 0);
      pc_update_out    : out std_logic_vector(N-1 downto 0);
      RF_WE            : in  std_logic;
      WB_DATA          : in  std_logic_vector(N-1 downto 0);
      WB_DEST_REG      : in  std_logic_vector(REG_ADDR-1 downto 0);
      FWD_ID_A         : in  std_logic_vector(1 downto 0);
      EXMEM_ALU_OUT_IN : in  std_logic_vector(N-1 downto 0);
      WB_DATA_IN       : in  std_logic_vector(N-1 downto 0);
      RegA_OUT         : out std_logic_vector(N-1 downto 0);
      RegB_OUT         : out std_logic_vector(N-1 downto 0);
      RegIMM_OUT       : out std_logic_vector(N-1 downto 0);
      NPC_OUT          : out std_logic_vector(N-1 downto 0);
      RD_OUT           : out std_logic_vector(REG_ADDR-1 downto 0);
      RS1_OUT          : out std_logic_vector(REG_ADDR-1 downto 0);
      RS2_OUT          : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  component ID_EX_reg
    generic (N : integer := 32; REG_ADDR : integer := 5);
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      en         : in  std_logic;
      clear      : in  std_logic;
      rega_in    : in  std_logic_vector(N-1 downto 0);
      regb_in    : in  std_logic_vector(N-1 downto 0);
      regimm_in  : in  std_logic_vector(N-1 downto 0);
      npc_in     : in  std_logic_vector(N-1 downto 0);
      rd_in      : in  std_logic_vector(REG_ADDR-1 downto 0);
      rs1_in     : in  std_logic_vector(REG_ADDR-1 downto 0);
      rs2_in     : in  std_logic_vector(REG_ADDR-1 downto 0);
      rega_out   : out std_logic_vector(N-1 downto 0);
      regb_out   : out std_logic_vector(N-1 downto 0);
      regimm_out : out std_logic_vector(N-1 downto 0);
      npc_out    : out std_logic_vector(N-1 downto 0);
      rd_out     : out std_logic_vector(REG_ADDR-1 downto 0);
      rs1_out    : out std_logic_vector(REG_ADDR-1 downto 0);
      rs2_out    : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  component EXStage
    generic (N : integer := 32);
    port (
      RegA_IN       : in  std_logic_vector(N-1 downto 0);
      RegB_IN       : in  std_logic_vector(N-1 downto 0);
      RegIMM_IN     : in  std_logic_vector(N-1 downto 0);
      NPC_IN        : in  std_logic_vector(N-1 downto 0);
      FWD_EX_MEM_IN : in  std_logic_vector(N-1 downto 0);
      FWD_MEM_WB_IN : in  std_logic_vector(N-1 downto 0);
      MUXA_SEL      : in  std_logic;
      MUXB_SEL      : in  std_logic;
      ALU_OPCODE    : in  aluOp;
      FORWARD_A     : in  std_logic_vector(1 downto 0);
      FORWARD_B     : in  std_logic_vector(1 downto 0);
      ALU_OUT       : out std_logic_vector(N-1 downto 0);
      DATA_TO_STORE : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component EX_MEM_reg
    generic (N : integer := 32; REG_ADDR : integer := 5);
    port (
      clk               : in  std_logic;
      rst               : in  std_logic;
      en                : in  std_logic;
      clear             : in  std_logic;
      alu_out_in        : in  std_logic_vector(N-1 downto 0);
      data_to_store_in  : in  std_logic_vector(N-1 downto 0);
      rd_in             : in  std_logic_vector(REG_ADDR-1 downto 0);
      alu_out_out       : out std_logic_vector(N-1 downto 0);
      data_to_store_out : out std_logic_vector(N-1 downto 0);
      rd_out            : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  component MEMStage
    generic (N : integer := 32; REG_ADDR : integer := 5);
    port (
      Clk            : in  std_logic;
      Rst            : in  std_logic;
      ALU_OUT_IN     : in  std_logic_vector(N-1 downto 0);
      RegB_IN        : in  std_logic_vector(N-1 downto 0);
      RD_IN          : in  std_logic_vector(REG_ADDR-1 downto 0);
      DRAM_WE        : in  std_logic;
      ALU_OUT_MEM_WB : out std_logic_vector(N-1 downto 0);
      LMD_MEM_WB     : out std_logic_vector(N-1 downto 0);
      RD_MEM_WB      : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  component MEM_WB_reg
    generic (N : integer := 32; REG_ADDR : integer := 5);
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      en          : in  std_logic;
      clear       : in  std_logic;
      alu_out_in  : in  std_logic_vector(N-1 downto 0);
      lmd_in      : in  std_logic_vector(N-1 downto 0);
      rd_in       : in  std_logic_vector(REG_ADDR-1 downto 0);
      alu_out_out : out std_logic_vector(N-1 downto 0);
      lmd_out     : out std_logic_vector(N-1 downto 0);
      rd_out      : out std_logic_vector(REG_ADDR-1 downto 0)
    );
  end component;

  component WBStage
    generic (N : integer := 32);
    port (
      ALU_OUT_IN  : in  std_logic_vector(N-1 downto 0);
      LMD_IN      : in  std_logic_vector(N-1 downto 0);
      WB_MUX_SEL  : in  std_logic;
      WB_DATA_OUT : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component forwarding_unit
    generic (REG_ADDR : integer := 5);
    port (
      ID_EX_Rs1    : in  std_logic_vector(REG_ADDR-1 downto 0);
      ID_EX_Rs2    : in  std_logic_vector(REG_ADDR-1 downto 0);
      EX_MEM_Rd    : in  std_logic_vector(REG_ADDR-1 downto 0);
      EX_MEM_RF_WE : in  std_logic;
      MEM_WB_Rd    : in  std_logic_vector(REG_ADDR-1 downto 0);
      MEM_WB_RF_WE : in  std_logic;
      FORWARD_A    : out std_logic_vector(1 downto 0);
      FORWARD_B    : out std_logic_vector(1 downto 0)
    );
  end component;

  component forwarding_id
    generic (REG_ADDR : integer := 5);
    port (
      ID_Rs1            : in  std_logic_vector(REG_ADDR-1 downto 0);
      EX_MEM_Rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
      EX_MEM_RF_WE      : in  std_logic;
      EX_MEM_WB_MUX_SEL : in  std_logic;
      MEM_WB_Rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
      MEM_WB_RF_WE      : in  std_logic;
      IS_BRANCH         : in  std_logic;
      FWD_ID_A          : out std_logic_vector(1 downto 0)
    );
  end component;

  component hazard_detector
    port (
      ID_Rs1             : in  std_logic_vector(4 downto 0);
      ID_Rs2             : in  std_logic_vector(4 downto 0);
      EX_Rd              : in  std_logic_vector(4 downto 0);
      EX_RF_WE           : in  std_logic;
      EX_WB_MUX_SEL      : in  std_logic;
      EQ_COND            : in  std_logic;
      MEM_Rd             : in  std_logic_vector(4 downto 0);
      MEM_RF_WE          : in  std_logic;
      MEM_WB_MUX_SEL     : in  std_logic;
      load_use_alarm     : out std_logic;
      branch_stall_alarm : out std_logic
    );
  end component;

  component dlx_cu
    generic (
      MICROCODE_MEM_SIZE : integer := 64;
      FUNC_SIZE          : integer := 11;
      OP_CODE_SIZE       : integer := 6;
      IR_SIZE            : integer := 32;
      CW_SIZE            : integer := 7
    );
    port (
      Clk                : in  std_logic;
      Rst                : in  std_logic;
      IR_IN              : in  std_logic_vector(IR_SIZE - 1 downto 0);
      cache_miss_in      : in  std_logic;
      load_use_alarm     : in  std_logic;
      mispredict_in      : in  std_logic;
      branch_stall_alarm : in  std_logic;
      PC_EN              : out std_logic;
      IF_ID_EN           : out std_logic;
      IF_ID_CLEAR        : out std_logic;
      ID_EX_EN           : out std_logic;
      ID_EX_CLEAR        : out std_logic;
      EX_MEM_EN          : out std_logic;
      EX_MEM_CLEAR       : out std_logic;
      MEM_WB_EN          : out std_logic;
      MEM_WB_CLEAR       : out std_logic;
      JUMP_EN            : out std_logic;
      EQ_COND            : out std_logic;
      MUXA_SEL           : out std_logic;
      MUXB_SEL           : out std_logic;
      ALU_OPCODE         : out aluOp;
      EX_RF_WE_OUT       : out std_logic;
      EX_WB_MUX_SEL_OUT  : out std_logic;
      MEM_RF_WE_OUT      : out std_logic;
      MEM_WB_MUX_SEL_OUT : out std_logic;
      DRAM_WE            : out std_logic;
      WB_MUX_SEL         : out std_logic;
      RF_WE              : out std_logic
    );
  end component;

  -- ---------- Segnali di interconnessione ----------

  -- IF -> IF/ID
  signal if_pc, if_npc, if_ir : std_logic_vector(IR_SIZE-1 downto 0);
  signal if_taken             : std_logic;
  signal if_cache_miss        : std_logic;

  -- IF/ID -> ID
  signal ifid_pc, ifid_npc, ifid_ir : std_logic_vector(IR_SIZE-1 downto 0);
  signal ifid_taken                 : std_logic;

  -- ID -> ID/EX
  signal id_rega, id_regb, id_regimm, id_npc : std_logic_vector(IR_SIZE-1 downto 0);
  signal id_rd, id_rs1, id_rs2               : std_logic_vector(REG_ADDR-1 downto 0);

  -- ID -> IF (feedback branch prediction)
  signal id_mispredict, id_update_en, id_actual_taken : std_logic;
  signal id_recovery_addr, id_pc_update               : std_logic_vector(IR_SIZE-1 downto 0);

  -- ID/EX -> EX
  signal idex_rega, idex_regb, idex_regimm, idex_npc : std_logic_vector(IR_SIZE-1 downto 0);
  signal idex_rd, idex_rs1, idex_rs2                 : std_logic_vector(REG_ADDR-1 downto 0);

  -- EX -> EX/MEM
  signal ex_alu_out, ex_data_to_store : std_logic_vector(IR_SIZE-1 downto 0);

  -- EX/MEM -> MEM (e forwarding)
  signal exmem_alu_out, exmem_data : std_logic_vector(IR_SIZE-1 downto 0);
  signal exmem_rd                  : std_logic_vector(REG_ADDR-1 downto 0);

  -- MEM -> MEM/WB
  signal mem_alu_out, mem_lmd : std_logic_vector(IR_SIZE-1 downto 0);
  signal mem_rd               : std_logic_vector(REG_ADDR-1 downto 0);

  -- MEM/WB -> WB
  signal memwb_alu_out, memwb_lmd : std_logic_vector(IR_SIZE-1 downto 0);
  signal memwb_rd                 : std_logic_vector(REG_ADDR-1 downto 0);

  -- WB -> RF (in ID)
  signal wb_data : std_logic_vector(IR_SIZE-1 downto 0);

  -- Forwarding / Hazard
  signal fwd_a, fwd_b            : std_logic_vector(1 downto 0);
  signal fwd_id_a                : std_logic_vector(1 downto 0);
  signal hd_load_use             : std_logic;
  signal hd_branch_stall         : std_logic;

  -- CU signals
  signal cu_pc_en                                          : std_logic;
  signal cu_ifid_en, cu_ifid_clear                         : std_logic;
  signal cu_idex_en, cu_idex_clear                         : std_logic;
  signal cu_exmem_en, cu_exmem_clear                       : std_logic;
  signal cu_memwb_en, cu_memwb_clear                       : std_logic;
  signal cu_jump_en, cu_eq_cond                            : std_logic;
  signal cu_muxa, cu_muxb                                  : std_logic;
  signal cu_alu_op                                         : aluOp;
  signal cu_ex_rf_we, cu_ex_wb_muxsel                      : std_logic;
  signal cu_mem_rf_we, cu_mem_wb_muxsel                    : std_logic;
  signal cu_dram_we                                        : std_logic;
  signal cu_wb_muxsel, cu_rf_we                            : std_logic;

begin

  -- ============================ CONTROL UNIT ============================
  CU_I: dlx_cu
    port map (
      Clk                => Clk,
      Rst                => Rst,
      IR_IN              => ifid_ir,        -- decodifica su istruzione latchata in IF/ID
      cache_miss_in      => if_cache_miss,
      load_use_alarm     => hd_load_use,
      mispredict_in      => id_mispredict,
      branch_stall_alarm => hd_branch_stall,
      PC_EN              => cu_pc_en,
      IF_ID_EN           => cu_ifid_en,   IF_ID_CLEAR  => cu_ifid_clear,
      ID_EX_EN           => cu_idex_en,   ID_EX_CLEAR  => cu_idex_clear,
      EX_MEM_EN          => cu_exmem_en,  EX_MEM_CLEAR => cu_exmem_clear,
      MEM_WB_EN          => cu_memwb_en,  MEM_WB_CLEAR => cu_memwb_clear,
      JUMP_EN            => cu_jump_en,
      EQ_COND            => cu_eq_cond,
      MUXA_SEL           => cu_muxa,
      MUXB_SEL           => cu_muxb,
      ALU_OPCODE         => cu_alu_op,
      EX_RF_WE_OUT       => cu_ex_rf_we,
      EX_WB_MUX_SEL_OUT  => cu_ex_wb_muxsel,
      MEM_RF_WE_OUT      => cu_mem_rf_we,
      MEM_WB_MUX_SEL_OUT => cu_mem_wb_muxsel,
      DRAM_WE            => cu_dram_we,
      WB_MUX_SEL         => cu_wb_muxsel,
      RF_WE              => cu_rf_we
    );

  -- ============================ IF STAGE ============================
  IF_I: IFStage
    generic map (IR_SIZE => IR_SIZE, PC_SIZE => PC_SIZE)
    port map (
      Clk                 => Clk,
      Rst                 => Rst,
      PC_LATCH_EN         => cu_pc_en,
      mispredict_in       => id_mispredict,
      update_en_in        => id_update_en,
      actual_taken_in     => id_actual_taken,
      recovery_address_in => id_recovery_addr,
      pc_update_in        => id_pc_update,
      PC_OUT              => if_pc,
      NPC_OUT             => if_npc,
      IR_OUT              => if_ir,
      TAKEN_OUT           => if_taken,
      cache_miss_out      => if_cache_miss
    );

  -- ============================ IF/ID REGISTER ============================
  IFID_I: IF_ID_reg
    generic map (N => IR_SIZE)
    port map (
      clk       => Clk,
      rst       => Rst,
      en        => cu_ifid_en,
      clear     => cu_ifid_clear,
      pc_in     => if_pc,
      npc_in    => if_npc,
      ir_in     => if_ir,
      taken_in  => if_taken,
      pc_out    => ifid_pc,
      npc_out   => ifid_npc,
      ir_out    => ifid_ir,
      taken_out => ifid_taken
    );

  -- ============================ ID STAGE ============================
  ID_I: IDStage
    generic map (IR_SIZE => IR_SIZE, N => IR_SIZE, REG_ADDR => REG_ADDR)
    port map (
      Clk               => Clk,
      Rst               => Rst,
      jump_en           => cu_jump_en,
      eq_cond           => cu_eq_cond,
      IR_IN             => ifid_ir,
      NPC_IN            => ifid_npc,
      PC_IN             => ifid_pc,
      taken_in          => ifid_taken,
      mispredict_out    => id_mispredict,
      update_en_out     => id_update_en,
      actual_taken_out  => id_actual_taken,
      recovery_addr_out => id_recovery_addr,
      pc_update_out     => id_pc_update,
      RF_WE             => cu_rf_we,
      WB_DATA           => wb_data,
      WB_DEST_REG       => memwb_rd,
      FWD_ID_A          => fwd_id_a,
      EXMEM_ALU_OUT_IN  => exmem_alu_out,
      WB_DATA_IN        => wb_data,
      RegA_OUT          => id_rega,
      RegB_OUT          => id_regb,
      RegIMM_OUT        => id_regimm,
      NPC_OUT           => id_npc,
      RD_OUT            => id_rd,
      RS1_OUT           => id_rs1,
      RS2_OUT           => id_rs2
    );

  -- ============================ ID/EX REGISTER ============================
  IDEX_I: ID_EX_reg
    generic map (N => IR_SIZE, REG_ADDR => REG_ADDR)
    port map (
      clk        => Clk,
      rst        => Rst,
      en         => cu_idex_en,
      clear      => cu_idex_clear,
      rega_in    => id_rega,
      regb_in    => id_regb,
      regimm_in  => id_regimm,
      npc_in     => id_npc,
      rd_in      => id_rd,
      rs1_in     => id_rs1,
      rs2_in     => id_rs2,
      rega_out   => idex_rega,
      regb_out   => idex_regb,
      regimm_out => idex_regimm,
      npc_out    => idex_npc,
      rd_out     => idex_rd,
      rs1_out    => idex_rs1,
      rs2_out    => idex_rs2
    );

  -- ============================ HAZARD DETECTOR ============================
  --  Guarda Rs1/Rs2 in ID (combinatori dell'IDStage) e Rd delle istruzioni
  --  attualmente in EX (idex_rd) e MEM (exmem_rd). I write-enable e i
  --  WB_MUX_SEL vengono dalla pipeline interna alla CU.
  HD_I: hazard_detector
    port map (
      ID_Rs1             => id_rs1,
      ID_Rs2             => id_rs2,
      EX_Rd              => idex_rd,
      EX_RF_WE           => cu_ex_rf_we,
      EX_WB_MUX_SEL      => cu_ex_wb_muxsel,
      EQ_COND            => cu_eq_cond,
      MEM_Rd             => exmem_rd,
      MEM_RF_WE          => cu_mem_rf_we,
      MEM_WB_MUX_SEL     => cu_mem_wb_muxsel,
      load_use_alarm     => hd_load_use,
      branch_stall_alarm => hd_branch_stall
    );

  -- ============================ FORWARDING UNIT (EX) ============================
  FWD_I: forwarding_unit
    generic map (REG_ADDR => REG_ADDR)
    port map (
      ID_EX_Rs1    => idex_rs1,
      ID_EX_Rs2    => idex_rs2,
      EX_MEM_Rd    => exmem_rd,
      EX_MEM_RF_WE => cu_mem_rf_we,   -- WE dell'istruzione ora in stadio MEM
      MEM_WB_Rd    => memwb_rd,
      MEM_WB_RF_WE => cu_rf_we,       -- WE dell'istruzione ora in stadio WB
      FORWARD_A    => fwd_a,
      FORWARD_B    => fwd_b
    );

  -- ============================ FORWARDING UNIT (ID) ============================
  -- Alimenta il MUX davanti a zero_check per la branch resolution in Decode.
  FWD_ID_I: forwarding_id
    generic map (REG_ADDR => REG_ADDR)
    port map (
      ID_Rs1            => id_rs1,
      EX_MEM_Rd         => exmem_rd,
      EX_MEM_RF_WE      => cu_mem_rf_we,
      EX_MEM_WB_MUX_SEL => cu_mem_wb_muxsel,  -- '1' = LOAD in MEM
      MEM_WB_Rd         => memwb_rd,
      MEM_WB_RF_WE      => cu_rf_we,
      IS_BRANCH         => cu_eq_cond,        -- attivo solo per BEQZ/BNEZ
      FWD_ID_A          => fwd_id_a
    );

  -- ============================ EX STAGE ============================
  EX_I: EXStage
    generic map (N => IR_SIZE)
    port map (
      RegA_IN       => idex_rega,
      RegB_IN       => idex_regb,
      RegIMM_IN     => idex_regimm,
      NPC_IN        => idex_npc,
      FWD_EX_MEM_IN => exmem_alu_out, -- risultato ALU 1 ciclo fa
      FWD_MEM_WB_IN => wb_data,       -- dato che sta per essere scritto nel RF
      MUXA_SEL      => cu_muxa,
      MUXB_SEL      => cu_muxb,
      ALU_OPCODE    => cu_alu_op,
      FORWARD_A     => fwd_a,
      FORWARD_B     => fwd_b,
      ALU_OUT       => ex_alu_out,
      DATA_TO_STORE => ex_data_to_store
    );

  -- ============================ EX/MEM REGISTER ============================
  EXMEM_I: EX_MEM_reg
    generic map (N => IR_SIZE, REG_ADDR => REG_ADDR)
    port map (
      clk               => Clk,
      rst               => Rst,
      en                => cu_exmem_en,
      clear             => cu_exmem_clear,
      alu_out_in        => ex_alu_out,
      data_to_store_in  => ex_data_to_store,
      rd_in             => idex_rd,
      alu_out_out       => exmem_alu_out,
      data_to_store_out => exmem_data,
      rd_out            => exmem_rd
    );

  -- ============================ MEM STAGE ============================
  MEM_I: MEMStage
    generic map (N => IR_SIZE, REG_ADDR => REG_ADDR)
    port map (
      Clk            => Clk,
      Rst            => Rst,
      ALU_OUT_IN     => exmem_alu_out,
      RegB_IN        => exmem_data,
      RD_IN          => exmem_rd,
      DRAM_WE        => cu_dram_we,
      ALU_OUT_MEM_WB => mem_alu_out,
      LMD_MEM_WB     => mem_lmd,
      RD_MEM_WB      => mem_rd
    );

  -- ============================ MEM/WB REGISTER ============================
  MEMWB_I: MEM_WB_reg
    generic map (N => IR_SIZE, REG_ADDR => REG_ADDR)
    port map (
      clk         => Clk,
      rst         => Rst,
      en          => cu_memwb_en,
      clear       => cu_memwb_clear,
      alu_out_in  => mem_alu_out,
      lmd_in      => mem_lmd,
      rd_in       => mem_rd,
      alu_out_out => memwb_alu_out,
      lmd_out     => memwb_lmd,
      rd_out      => memwb_rd
    );

  -- ============================ WB STAGE ============================
  WB_I: WBStage
    generic map (N => IR_SIZE)
    port map (
      ALU_OUT_IN  => memwb_alu_out,
      LMD_IN      => memwb_lmd,
      WB_MUX_SEL  => cu_wb_muxsel,
      WB_DATA_OUT => wb_data
      );
  TEST_PC_OUT <= if_pc;
  TEST_ALU_OUT <= ex_alu_out;

end STRUCTURAL;
