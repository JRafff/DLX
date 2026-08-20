Durante i 2 ns di reset iniziali tutti i registri vengono azzerati. Poi vengono caricati dei valori in r1 = 100, r2 = -7, r5 = 42.

Viene servito add r3, r1, r2 (opcode 0x00, RS1=1, RS2=2, RD=3, FUNC=0x20). Al CLK dopo 
RegA_OUT = 100 e RegB_OUT = -7. RD_OUT = 3 e opcode ed NPC vengono correttamente propagati.

Viene servito addi r6, r1, 10 (opcode 0x08). Al CLK dopo RegA_OUT = 100 e RegIMM = 10. 
RD_OUT = 6

Viene servito andi r7, r1, 0xFFFF (opcode 0x0C). RegIMM = 0x0000FFFF. 

Viene servito jal imm26=200 (opcode 0x03). Enable stile JAL: RegA=0, RegB=0, RegIMM=1.
RegIMM = 0 ed RD = 31. JUMP_TARGET = 0x40 (NPC) + 200 = 0x108