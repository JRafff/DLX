; Inizializzazione (I-Type)
addi r1, r0, #0     ; r1 = 0
nop
nop
nop
addi r2, r0, #5     ; r2 = 5
nop
nop
nop

; Branch NON preso
beqz r2, errore     ; r2 è 5, la condizione è falsa. Non salta.
nop
nop
nop

; Aritmetica (R-Type)
add r3, r2, r2      ; r3 = 5 + 5 = 10
nop
nop
nop

; Memoria (Store e Load)
sw 0(r1), r3        ; M[0] = 10
nop
nop
nop
lw r4, 0(r1)        ; r4 = M[0] = 10
nop
nop
nop

; Aritmetica (R-Type)
sub r5, r4, r2      ; r5 = 10 - 5 = 5
nop
nop
nop

; Branch PRESO
beqz r1, salto      ; r1 è 0, la condizione è vera. Salta.
nop
nop
nop

errore:
; Se finisce qui, un salto ha fallito
addi r31, r0, #99   
nop
nop
nop
j fine
nop
nop
nop

salto:
; Salto incondizionato (Jump)
j fine
nop
nop
nop

fine:
nop
nop
nop