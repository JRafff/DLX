# ============================================================================
#  sim_id.do  --  standalone testbench for the DLX ID stage (DP_v4_decode)
#  Run from the DP_v4_decode/ folder:  do sim_id.do
#
#  The ID stage instantiates: RF + ImmGen + jump-target adder (RCA_GENERIC)
#  + 7 pipeline registers (reg_en) at the ID/EX boundary.
# ============================================================================

quit -sim

if { ![file exists work] } {
    vlib work
    vmap work work
}

echo "======== Compiling ========"

# ---- packages --------------------------------------------------------------
vcom -quiet 000-globals.vhd

# ---- combinational building blocks ----------------------------------------
vcom -quiet a.b.b-RF.vhd
vcom -quiet a.b.c-ImmGen.vhd

# ---- Kogge-Stone adder (used by the jump-target adder in ID) --------------
vcom -quiet G_block.vhd
vcom -quiet PG_block.vhd
vcom -quiet pg_network.vhd
vcom -quiet koggle_stone_adder.vhd

# ---- pipeline register + ID stage -----------------------------------------
vcom -quiet reg_en.vhd
vcom -quiet a.b.e-IDStage.vhd

# ---- testbench --------------------------------------------------------------
vcom -quiet test_bench/TB_IDStage.vhd

echo "======== Loading  ========"
vsim -t 100ps -voptargs="+acc" work.tb_idstage

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -label CLK sim:/tb_idstage/Clk
add wave -label RST sim:/tb_idstage/Rst

add wave -divider "CU control (ID)"
add wave -label RegA_EN   sim:/tb_idstage/RegA_LATCH_EN
add wave -label RegB_EN   sim:/tb_idstage/RegB_LATCH_EN
add wave -label RegIMM_EN sim:/tb_idstage/RegIMM_LATCH_EN

add wave -divider "WB write port"
add wave -label RF_WE       sim:/tb_idstage/RF_WE
add wave -radix uns -label WB_DEST_REG sim:/tb_idstage/WB_DEST_REG
add wave -radix dec -label WB_DATA     sim:/tb_idstage/WB_DATA

add wave -divider "ID inputs"
add wave -radix hex -label IR_IN  sim:/tb_idstage/IR_IN
add wave -radix hex -label NPC_IN sim:/tb_idstage/NPC_IN

add wave -divider "ID outputs (latched to EX)"
add wave -radix dec -label RegA_OUT       sim:/tb_idstage/RegA_OUT
add wave -radix dec -label RegB_OUT       sim:/tb_idstage/RegB_OUT
add wave -radix hex -label RegIMM_OUT     sim:/tb_idstage/RegIMM_OUT
add wave -radix hex -label JUMP_TARGET_OUT sim:/tb_idstage/JUMP_TARGET_OUT
add wave -radix hex -label NPC_OUT        sim:/tb_idstage/NPC_OUT
add wave -radix hex -label OPCODE_OUT     sim:/tb_idstage/OPCODE_OUT
add wave -radix uns -label RD_OUT         sim:/tb_idstage/RD_OUT

add wave -divider "ID internals"
add wave -radix hex -label opcode  sim:/tb_idstage/DUT/opcode
add wave -radix uns -label rs1     sim:/tb_idstage/DUT/rs1
add wave -radix uns -label rs2     sim:/tb_idstage/DUT/rs2
add wave -radix uns -label rd_sel  sim:/tb_idstage/DUT/rd_sel
add wave -radix dec -label rf_out1 sim:/tb_idstage/DUT/rf_out1
add wave -radix dec -label rf_out2 sim:/tb_idstage/DUT/rf_out2
add wave -radix hex -label imm_raw   sim:/tb_idstage/DUT/imm_raw
add wave -radix hex -label imm_muxB  sim:/tb_idstage/DUT/imm_muxB
add wave -radix hex -label jt_comb   sim:/tb_idstage/DUT/jump_target_comb
add wave -label aux_en   sim:/tb_idstage/DUT/aux_en

configure wave -namecolwidth  220
configure wave -valuecolwidth 130
configure wave -signalnamewidth 1

echo "======== Running ========"
run 40 ns
wave zoom full
echo "IDStage sim done."
