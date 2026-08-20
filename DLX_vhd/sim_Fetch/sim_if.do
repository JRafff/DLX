# ============================================================================
#  sim_if.do  --  standalone testbench for the DLX IF stage (DP_v3)
#  Run from the DP_v3/ folder:  do sim_if.do
#
#  Uses a ripple-carry adder (rca_generic.vhd + fa.vhd) for the PC+4 sum.
#  The IRAM reads test.asm.mem from the current directory.
# ============================================================================

quit -sim

if { ![file exists work] } {
    vlib work
    vmap work work
}

echo "======== Compiling ========"
# ---- shared constants ------------------------------------------------------
vcom -quiet constants.vhd

# ---- Ripple-Carry Adder (Full Adder + RCA_GENERIC, BEHAVIORAL arch) -------
vcom -quiet fa.vhd
vcom -quiet rca_generic.vhd

# ---- IF stage building blocks ----------------------------------------------
vcom -quiet reg_en.vhd
vcom -quiet a.c-IRAM.vhd
vcom -quiet a.b.d-IFStage.vhd

# ---- testbench --------------------------------------------------------------
vcom -quiet test_bench/TB_IF.vhd

echo "======== Loading  ========"
vsim -t 100ps -voptargs="+acc" work.tb_if

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -label CLK sim:/tb_if/Clk
add wave -label RST sim:/tb_if/Rst

add wave -divider "CU control"
add wave -label PC_LATCH_EN  sim:/tb_if/PC_LATCH_EN
add wave -label IR_LATCH_EN  sim:/tb_if/IR_LATCH_EN
add wave -label NPC_LATCH_EN sim:/tb_if/NPC_LATCH_EN
add wave -label PC_SEL       sim:/tb_if/PC_SEL

add wave -divider "IF outputs"
add wave -radix hex -label PC_OUT  sim:/tb_if/PC_OUT
add wave -radix hex -label NPC_OUT sim:/tb_if/NPC_OUT
add wave -radix hex -label IR_OUT  sim:/tb_if/IR_OUT

add wave -divider "IRAM"
add wave -radix hex -label IRAM_DOut sim:/tb_if/IRAM_DOut
add wave -radix hex -label JUMP_TARGET sim:/tb_if/JUMP_TARGET

add wave -divider "IF internals"
add wave -radix hex -label PC_reg   sim:/tb_if/DUT/PC_reg
add wave -radix hex -label PC_plus4 sim:/tb_if/DUT/PC_plus4
add wave -radix hex -label PC_next  sim:/tb_if/DUT/PC_next

configure wave -namecolwidth  200
configure wave -valuecolwidth 130
configure wave -signalnamewidth 1

echo "======== Running ========"
run 20 ns
wave zoom full
echo "IFStage sim done."
