# ============================================================================
#  sim_dlx.do  --  ModelSim automation script for the DLX-pro top-level TB
#
#  How to use it (from ModelSim's Transcript):
#      cd .../DLX_project/PRO/DLX_vhd
#      do sim_dlx.do
#
#  If you change any .vhd, just re-run the same command.
# ============================================================================

# ---- 0. Housekeeping ------------------------------------------------------
quit -sim

# Safety check: test.asm.mem must sit next to the .do (IRAM opens it relatively)
if { ![file exists test.asm.mem] } {
    echo "ERROR: test.asm.mem not found in [pwd]. Copy it here and re-run."
    return
}

# ---- 1. Work library ------------------------------------------------------
if { ![file exists work] } {
    vlib work
    vmap work work
}

# ---- 2. Compilation (order matters, hierarchical bottom-up) ---------------
# Ordering prefix as per the guide: a-DLX.vhd, a.a-CU.vhd, a.b-IFStage.vhd,
# a.b-IFStage.core/ (sub-modules), etc.
echo "======== Compiling package ========"
vcom -quiet 000-globals.vhd

echo "======== Compiling generic primitives (01-*) ========"
vcom -quiet 01-reg_en.vhd
vcom -quiet 01-G_block.vhd
vcom -quiet 01-PG_block.vhd
vcom -quiet 01-pg_network.vhd
vcom -quiet 01-koggle_stone_adder.vhd
vcom -quiet 01-shifter.vhd
vcom -quiet 01-logic.vhd
vcom -quiet 01-comparator_eq.vhd
vcom -quiet 01-zero_check.vhd
vcom -quiet 01-ADD_SUB.vhd

echo "======== Compiling IF-stage sub-modules (a.b-IFStage.core/) ========"
vcom -quiet a.b-IFStage.core/a.b.a-PC_sel.vhd
vcom -quiet a.b-IFStage.core/a.b.b-BTB.vhd
vcom -quiet a.b-IFStage.core/a.b.c-Icache.vhd
vcom -quiet a.b-IFStage.core/a.b.d-IRAM.vhd

echo "======== Compiling ID-stage sub-modules (a.c-IDStage.core/) ========"
vcom -quiet a.c-IDStage.core/a.c.a-RF.vhd
vcom -quiet a.c-IDStage.core/a.c.b-ImmGen.vhd
vcom -quiet a.c-IDStage.core/a.c.c-branch_resolution.vhd

echo "======== Compiling EX-stage sub-modules (a.d-EXStage.core/) ========"
vcom -quiet a.d-EXStage.core/a.d.a-ALU.vhd

echo "======== Compiling MEM-stage sub-modules (a.e-MEMStage.core/) ========"
vcom -quiet a.e-MEMStage.core/a.e.a-DRAM.vhd

echo "======== Compiling pipeline registers (a.g..a.j) ========"
vcom -quiet a.g-IF_ID_reg.vhd
vcom -quiet a.h-ID_EX_reg.vhd
vcom -quiet a.i-EX_MEM_reg.vhd
vcom -quiet a.j-MEM_WB_reg.vhd

echo "======== Compiling pipeline stages (a.b..a.f) ========"
vcom -quiet a.b-IFStage.vhd
vcom -quiet a.c-IDStage.vhd
vcom -quiet a.d-EXStage.vhd
vcom -quiet a.e-MEMStage.vhd
vcom -quiet a.f-WBStage.vhd

echo "======== Compiling forwarding + hazard (a.k, a.l, a.m) ========"
vcom -quiet a.k-forwarding_unit.vhd
vcom -quiet a.l-forwarding_id.vhd
vcom -quiet a.m-hazard_detector.vhd

echo "======== Compiling Control Unit (a.a-CU.vhd) ========"
vcom -quiet a.a-CU.vhd

echo "======== Compiling top-level and testbench ========"
vcom -quiet a-DLX.vhd
vcom -quiet test_bench/TB_DLX.vhd

# ---- 3. Load the simulation -----------------------------------------------
echo "======== Loading  ========"
vsim -t 100ps -voptargs="+acc" work.tb_dlx

# ---- 4. Wave window setup -------------------------------------------------
onerror {resume}
quietly WaveActivateNextPane {} 0

# ---- Reference / clock / reset
add wave -divider "Clock & Reset"
add wave -label CLK sim:/tb_dlx/Clk
add wave -label RST sim:/tb_dlx/Rst

# ---- Fetch
add wave -divider "IF stage"
add wave -radix hex -label PC              sim:/tb_dlx/U1/if_pc
add wave -radix hex -label IR              sim:/tb_dlx/U1/if_ir
add wave -label     TAKEN(BTB)             sim:/tb_dlx/U1/if_taken
add wave -label     CACHE_MISS             sim:/tb_dlx/U1/if_cache_miss

# ---- IF/ID
add wave -divider "IF/ID reg"
add wave -radix hex -label IFID_PC         sim:/tb_dlx/U1/ifid_pc
add wave -radix hex -label IFID_IR         sim:/tb_dlx/U1/ifid_ir
add wave -label     IFID_TAKEN             sim:/tb_dlx/U1/ifid_taken

# ---- Decode
add wave -divider "ID stage"
add wave -radix hex -label ID_RegA         sim:/tb_dlx/U1/id_rega
add wave -radix hex -label ID_RegB         sim:/tb_dlx/U1/id_regb
add wave -radix hex -label ID_Imm          sim:/tb_dlx/U1/id_regimm
add wave -label     ID_Rs1                 sim:/tb_dlx/U1/id_rs1
add wave -label     ID_Rs2                 sim:/tb_dlx/U1/id_rs2
add wave -label     ID_Rd                  sim:/tb_dlx/U1/id_rd
add wave -label     ID_MISPREDICT          sim:/tb_dlx/U1/id_mispredict
add wave -label     ID_ACTUAL_TAKEN        sim:/tb_dlx/U1/id_actual_taken
add wave -label     FWD_ID_A               sim:/tb_dlx/U1/fwd_id_a

# ---- ID/EX
add wave -divider "ID/EX reg"
add wave -radix hex -label IDEX_RegA       sim:/tb_dlx/U1/idex_rega
add wave -radix hex -label IDEX_RegB       sim:/tb_dlx/U1/idex_regb
add wave -radix hex -label IDEX_Imm        sim:/tb_dlx/U1/idex_regimm
add wave -label     IDEX_Rd                sim:/tb_dlx/U1/idex_rd
add wave -label     IDEX_Rs1               sim:/tb_dlx/U1/idex_rs1
add wave -label     IDEX_Rs2               sim:/tb_dlx/U1/idex_rs2

# ---- Execute
add wave -divider "EX stage"
add wave -radix hex -label EX_ALU_OUT      sim:/tb_dlx/U1/ex_alu_out
add wave -label     FWD_A                  sim:/tb_dlx/U1/fwd_a
add wave -label     FWD_B                  sim:/tb_dlx/U1/fwd_b

# ---- EX/MEM
add wave -divider "EX/MEM reg"
add wave -radix hex -label EXMEM_ALU_OUT   sim:/tb_dlx/U1/exmem_alu_out
add wave -label     EXMEM_Rd               sim:/tb_dlx/U1/exmem_rd

# ---- Memory
add wave -divider "MEM stage"
add wave -radix hex -label MEM_LMD         sim:/tb_dlx/U1/mem_lmd

# ---- MEM/WB
add wave -divider "MEM/WB reg"
add wave -radix hex -label MEMWB_ALU_OUT   sim:/tb_dlx/U1/memwb_alu_out
add wave -radix hex -label MEMWB_LMD       sim:/tb_dlx/U1/memwb_lmd
add wave -label     MEMWB_Rd               sim:/tb_dlx/U1/memwb_rd

# ---- WB
add wave -divider "WB -> RF"
add wave -radix hex -label WB_DATA         sim:/tb_dlx/U1/wb_data

# ---- Hazard & control
add wave -divider "Hazard & CU alarms"
add wave -label LOAD_USE      sim:/tb_dlx/U1/hd_load_use
add wave -label BRANCH_STALL  sim:/tb_dlx/U1/hd_branch_stall

add wave -divider "CU pipe regs (control words)"
add wave -radix bin -label CW   sim:/tb_dlx/U1/CU_I/cw
add wave -radix bin -label CW1  sim:/tb_dlx/U1/CU_I/cw1
add wave -radix bin -label CW2  sim:/tb_dlx/U1/CU_I/cw2
add wave -radix bin -label CW3  sim:/tb_dlx/U1/CU_I/cw3
add wave -label ALU_OP_i        sim:/tb_dlx/U1/CU_I/aluOpcode_i
add wave -label ALU_OP1         sim:/tb_dlx/U1/CU_I/aluOpcode1

add wave -divider "CU pipe enables/clears"
add wave -label PC_EN       sim:/tb_dlx/U1/cu_pc_en
add wave -label IFID_EN     sim:/tb_dlx/U1/cu_ifid_en
add wave -label IFID_CLR    sim:/tb_dlx/U1/cu_ifid_clear
add wave -label IDEX_EN     sim:/tb_dlx/U1/cu_idex_en
add wave -label IDEX_CLR    sim:/tb_dlx/U1/cu_idex_clear
add wave -label EXMEM_EN    sim:/tb_dlx/U1/cu_exmem_en
add wave -label MEMWB_EN    sim:/tb_dlx/U1/cu_memwb_en

# Register File registers (to verify test_pro_stress.asm final values)
add wave -divider "Register File (R1..R10)"
add wave -radix decimal -label R1  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(1)
add wave -radix decimal -label R2  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(2)
add wave -radix decimal -label R3  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(3)
add wave -radix decimal -label R4  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(4)
add wave -radix decimal -label R5  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(5)
add wave -radix decimal -label R6  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(6)
add wave -radix decimal -label R7  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(7)
add wave -radix decimal -label R8  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(8)
add wave -radix decimal -label R9  sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(9)
add wave -radix decimal -label R10 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(10)

add wave -divider "Register File (R11..R23)"
add wave -radix decimal -label R11 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(11)
add wave -radix decimal -label R12 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(12)
add wave -radix decimal -label R13 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(13)
add wave -radix decimal -label R14 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(14)
add wave -radix decimal -label R15 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(15)
add wave -radix decimal -label R16 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(16)
add wave -radix decimal -label R17 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(17)
add wave -radix decimal -label R18 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(18)
add wave -radix decimal -label R19 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(19)
add wave -radix decimal -label R20 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(20)
add wave -radix decimal -label R21 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(21)
add wave -radix decimal -label R22 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(22)
add wave -radix decimal -label R23 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(23)

add wave -divider "Register File (R24..R31)"
add wave -radix decimal -label R24 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(24)
add wave -radix decimal -label R25 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(25)
add wave -radix decimal -label R26 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(26)
add wave -radix decimal -label R27 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(27)
add wave -radix decimal -label R28 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(28)
add wave -radix decimal -label R29 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(29)
add wave -radix hex     -label R31 sim:/tb_dlx/U1/ID_I/RF_I/REGISTERS(31)

# DRAM: first three words used by the program (M[0]=30, M[4]=100, M[8]=r31)
add wave -divider "DRAM[0..2]"
add wave -radix decimal -label DRAM_0 sim:/tb_dlx/U1/MEM_I/DRAM_I/DRAM_mem(0)
add wave -radix decimal -label DRAM_1 sim:/tb_dlx/U1/MEM_I/DRAM_I/DRAM_mem(1)
add wave -radix hex     -label DRAM_2 sim:/tb_dlx/U1/MEM_I/DRAM_I/DRAM_mem(2)

configure wave -namecolwidth  220
configure wave -valuecolwidth 110
configure wave -justifyvalue  right
configure wave -signalnamewidth 1

# ---- 5. Run + zoom --------------------------------------------------------
echo "======== Running ========"
run 4000 ns
wave zoom range 0ns 4000ns

echo ""
echo "==================================================================="
echo "  Simulation done. Look at the wave window."
echo "  Program: test_pro_stress.asm (45 instructions)."
echo "  Expected features (in time order):"
echo "    1) Back-to-back R-type chain  -> FWD_A/FWD_B = 10 (EX/MEM)"
echo "    2) I-type chain + set-compare -> no bubbles"
echo "    3) LOAD_USE high for 1 cycle after LW -> IDEX_CLR + FWD 01"
echo "    4) BRANCH_STALL high on BEQZ with Rs1 in EX"
echo "    5) Backward loop 4x: 1st iter MISPREDICT, then BTB taken -> no bubble"
echo "    6) j, jal -> MISPREDICT + IFID_CLR; R31 saved in DRAM[2]"
echo "    7) Halt on end_prog (PC stable)"
echo "  Expected final values: R5=7 R6=20 R7=20 R8=30 R9=20 R10=640"
echo "                         R24=30 R25=40 R26=100 R27=70 R28=0 R29=4"
echo "                         DRAM[0]=30  DRAM[1]=100  DRAM[2]=R31 saved"
echo "==================================================================="
