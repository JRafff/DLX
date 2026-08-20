library ieee;
use ieee.std_logic_1164.all;

package myTypes is

	type aluOp is (		-- Possible ALU Opcodes
		NOP, 			-- No operation

		-- Arithmetic (signed)
		ADDS, 			-- Add Signed     : add, addi, lw, sw, j, jal, beqz, bnez (target/address)
		SUBS,			-- Sub Signed     : sub, subi

		-- Logic
		ANDS,			-- Bitwise AND    : and, andi
		ORS,			-- Bitwise OR     : or,  ori
		XORS,			-- Bitwise XOR    : xor, xori

		-- Shift
		LLS, 			-- Logical Left Shift  : sll, slli
		LRS, 			-- Logical Right Shift : srl, srli

		-- Set-compare (signed): result = "0...01" if condition holds, else zero
		SGES,			-- Set if Greater-or-Equal Signed : sge, sgei
		SLES,			-- Set if Less-or-Equal Signed    : sle, slei
		SNES			-- Set if Not-Equal               : sne, snei

			);

end myTypes;
