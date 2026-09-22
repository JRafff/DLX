; =============================================================================
;  test_pro_stress.asm  --  DLX-PRO feature stress test
; -----------------------------------------------------------------------------
;  Author : Raffaele Negri  (github.com/JRafff)
;  Date   : 2026-09-15
;
;  Purpose:
;     Exercise, in a single program, every relevant feature of the BASIC DLX
;     (R/I-type ALU, load/store, jump, conditional branches, nop) plus the
;     optimizations introduced in the PRO version:
;       * EX/MEM  -> EX  forwarding (back-to-back RAW, 1 cycle ahead)
;       * MEM/WB  -> EX  forwarding (RAW at distance 2, after an LW)
;       * Load-use hazard    -> 1-cycle stall + MEM/WB forwarding
;       * Branch stall alarm -> BEQZ/BNEZ with Rs1 written by EX or by LW in MEM
;       * BTB + 2-bit predictor -> backward-loop training + initial mispredict
;       * PLRU 4-way I-cache -> later loop iterations all hit (no IRAM latency)
;       * IF/ID flush on mispredict (j, jal, beqz taken on the first pass)
;
;  ISA actually decoded by the CU (see src/core/a.a-CU.vhd):
;     R-type : add, sub, and, or, xor, sll, srl, sne, sle, sge
;     I-type : addi, subi, andi, ori, xori, slli, srli, snei, slei, sgei
;     Mem    : lw, sw
;     Ctrl   : j, jal, beqz, bnez, nop
;     (jr/jalr are NOT supported: jal is only a demonstration and the
;      subroutine returns with an explicit jump.)
;
;  DRAM layout in use (RAM_DEPTH = 128, addresses on bits [6:2]):
;     r3 = 0  -> base
;     M[0]    scratch for the SW/LW hazard
;     M[4]    scratch for the load-use chain
;     M[8]    save slot for the return address (r31) after jal
;
;  How to check the behavior (in ModelSim / setmentor):
;     - Register File at the end of the program:
;         r1 =10, r2 =20, r3 =0,  r4 =5
;         r5 =7,  r6 =20, r7 =20, r8 =30, r9 =20, r10=640
;         r11=100,r12=50, r13=4,  r14=240,r15=15, r16=80, r17=20
;         r18=1,  r19=1,  r20=1,  r21=1,  r22=1,  r23=1
;         r24=30, r25=40, r26=100,r27=70
;         r28=0,  r29=4   (backward loop executed 4 times)
;         r31=NPC of jal (address of the instruction IMMEDIATELY after the
;             jal in text: dead-code slot flushed but the address is right)
;     - DRAM: M[0]=30, M[4]=100, M[8]=r31
;     - The PC ends parked in the "end_prog: j end_prog" halt-like loop.
;
;  How to build and run (from the repository root):
;     sw/tools/assemble.sh sw/asm/test_pro_stress.asm
;     cp sw/asm/test_pro_stress.mem sim/test.asm.mem
;     cd sim && ./run_ghdl.sh            # or, in ModelSim:  do sim_dlx.do
;
;     The default run length (SIM_CYCLES = 400) already covers this program.
; =============================================================================


; -----------------------------------------------------------------------------
; SECTION 0 - Register init (no RAWs, "clean" values)
; -----------------------------------------------------------------------------
        addi r1,  r0, #10          ; r1 = 10
        addi r2,  r0, #20          ; r2 = 20
        addi r3,  r0, #0           ; r3 = 0    (DRAM base)
        addi r4,  r0, #5           ; r4 = 5    (shift amount / misc)


; -----------------------------------------------------------------------------
; SECTION 1 - Back-to-back R-type chain
;   Every instruction consumes the previous instruction's result.
;   -> Stresses EX/MEM -> EX forwarding (1 cycle ahead) at maximum load.
;   No bubble should appear: if you see any in the waveform, forwarding
;   is not working.
; -----------------------------------------------------------------------------
        add  r5,  r1, r2           ; r5 = 30
        sub  r6,  r5, r1           ; r6 = 20     (EX/MEM fwd on r5)
        and  r7,  r6, r2           ; r7 = 20     (fwd on r6)
        or   r8,  r7, r1           ; r8 = 30     (fwd on r7)
        xor  r9,  r8, r1           ; r9 = 20     (fwd on r8)
        sll  r10, r9, r4           ; r10 = 640   (fwd on r9)


; -----------------------------------------------------------------------------
; SECTION 2 - Chained immediates
;   Same idea, but on the I-type path (MUXB=IMM). Includes immediate
;   shifts and immediate set-compares.
; -----------------------------------------------------------------------------
        addi r11, r0,  #100        ; r11 = 100
        subi r12, r11, #50         ; r12 = 50   (fwd on r11)
        andi r13, r11, #15         ; r13 = 100 & 15 = 4
        ori  r14, r0,  #240        ; r14 = 240
        xori r15, r14, #255        ; r15 = 240 ^ 255 = 15
        slli r16, r1,  #3          ; r16 = 10 << 3 = 80
        srli r17, r16, #2          ; r17 = 80 >> 2 = 20   (fwd on r16)


; -----------------------------------------------------------------------------
; SECTION 3 - Set-compare (all results expected to be 1)
;   Exercises the SGES/SLES/SNES ALU ops in both R-type and I-type forms.
; -----------------------------------------------------------------------------
        sge  r18, r2, r1           ; 20 >= 10 -> 1
        sle  r19, r1, r2           ; 10 <= 20 -> 1
        sne  r20, r1, r2           ; 10 != 20 -> 1
        sgei r21, r2, #10          ; 20 >= 10 -> 1
        slei r22, r1, #10          ; 10 <= 10 -> 1
        snei r23, r1, #0           ; 10 !=  0 -> 1


; -----------------------------------------------------------------------------
; SECTION 4 - Load-Store + LOAD-USE HAZARD
;   LW raises the WB_MUX_SEL flag (=1). If the next instruction uses the
;   loaded value, hazard_detector raises load_use_alarm: the CU stalls PC
;   and IF_ID for one cycle and injects a NOP into EX. In the cycle after
;   the stall, the load sits in MEM/WB and forwarding_unit picks the "01"
;   channel -> the value reaches EX before it hits the RF.
; -----------------------------------------------------------------------------
        sw   0(r3),  r5            ; M[0] = 30
        sw   4(r3),  r11           ; M[4] = 100
        lw   r24, 0(r3)            ; r24 <- 30
        add  r25, r24, r1          ; IMMEDIATE USE -> load-use stall + fwd
        lw   r26, 4(r3)            ; r26 <- 100
        sub  r27, r26, r24         ; IMMEDIATE USE (r26) + RAW on r24 (fwd)


; -----------------------------------------------------------------------------
; SECTION 5 - BRANCH STALL on freshly-written Rs1
;   In the PRO version, branch resolution happens in ID: if the branch's
;   Rs1 is being written by EX (or by a LOAD in MEM), hazard_detector
;   raises branch_stall_alarm. In the waveform you must see a bubble
;   injected toward EX and the fetch stalled for 1 cycle (2 if the source
;   is a LW).
; -----------------------------------------------------------------------------
        addi r5, r0, #0            ; r5 = 0   -> in EX when the beqz arrives
        beqz r5, taken1            ; Rs1 = r5 written in EX -> branch_stall
        addi r5, r0, #999          ; DEAD - runs only if beqz mispredicted not-taken
                                   ; but still flushed on the mispredict
taken1:
        addi r5, r0, #7            ; r5 = 7 (final value)


; -----------------------------------------------------------------------------
; SECTION 6 - BTB training on a BACKWARD loop
;   First iteration: BTB empty -> prediction is not-taken, branch is
;   actually taken -> mispredict -> IF/ID flush -> BTB updated with
;   history "10". From the second iteration on: history climbs to "11"
;   (strongly taken), fetch restarts directly from the predicted target
;   -> no bubble, no penalty. The PLRU I-cache also hits after the first
;   pass. Good for showcasing the 2-bit predictor's effectiveness.
;
;   4 iterations -> r29 = 4, r28 = 0 at the end.
; -----------------------------------------------------------------------------
        addi r28, r0, #4           ; iteration counter
        addi r29, r0, #0           ; accumulator
loop1:
        addi r29, r29, #1          ; acc++            (self-RAW, ok fwd)
        subi r28, r28, #1          ; count--          (self-RAW, ok fwd)
        bnez r28, loop1            ; backward -> BTB training


; -----------------------------------------------------------------------------
; SECTION 7 - Unconditional jumps: J and JAL
;   * J:   mispredicted on the first pass (target not yet in the jump's
;          BTB entry) -> IF/ID flush.
;   * JAL: same, plus writes NPC into R31 (via MUXA=NPC, MUXB=0,
;          WB_MUX=ALU, RF_WE=1 -> cw = "1011001" in the CU).
;
;   NOTE: the CU does not implement jr/jalr, so the "subroutine" returns
;   with an explicit jump. The value of r31 can still be verified by
;   reading M[8] at the end of the simulation.
; -----------------------------------------------------------------------------
        j    skip_dead             ; forward jump
        addi r30, r0, #123         ; DEAD - flushed on mispredict
skip_dead:
        jal  subr                  ; r31 <- NPC ; PC <- subr
        addi r30, r0, #666         ; DEAD - flushed too

subr:
        sw   8(r3), r31            ; save the return address into M[8]
        j    end_prog              ; "manual" return


; -----------------------------------------------------------------------------
; SECTION 8 - HALT
;   Infinite loop on itself: after 1-2 iterations the BTB always
;   predicts taken -> the PC stays put. Handy to freeze the waveform
;   inspection without counting cycles.
; -----------------------------------------------------------------------------
end_prog:
        j    end_prog


; =============================================================================
;  Measured cycle-count breakdown  (GHDL run, counted on the waveform)
;  See README.md, section "Measured performance".
; -----------------------------------------------------------------------------
;    Instructions executed                              :   50
;    Total cycles (reset release -> halt)               :  294
;    of which stalled on I-cache misses                 :  229   (78 %)
;    Load-use stall events                              :    2
;    Branch stall events                                :    5
;    Pipeline flushes (IF_ID_CLEAR)                     :    7
;    ------------------------------------------------------------
;    Raw CPI                                            :  5.88
;    CPI excluding cache-miss stalls                    :  ~1.30
;
;  The two numbers say different things. ~1.30 is what the pipeline itself
;  delivers: forwarding absorbs every RAW dependency in the back-to-back
;  chains at zero cost, and the BTB turns 3 of the 4 loop iterations into
;  zero-penalty taken branches. 5.88 is what the memory system costs: with
;  1-word cache lines there is no spatial locality, so every instruction
;  misses the first time it is fetched, at ~5 cycles each. The cache only
;  pays for itself inside the loop, where iterations 2-4 hit.
; =============================================================================
