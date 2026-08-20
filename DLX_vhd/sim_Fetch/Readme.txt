Durante i 2 ns iniziali:

Tutti i registri (PC_reg, IR, NPC) sono forzati a 0 dal reset asincrono di reg_en.
L'IRAM viene riempita col contenuto di test.asm.mem (il process FILL_MEM_P scatta su Rst).
Nel testbench vengono usate CW d'esempio senza significato (AAAAAA1, BBBBBB2 ...)


Dopo il rilascio del reset, Il PC avanza ad ogni ciclo.
L'IR viene aggiornato correttamente dalla parola letta dall'IRAM.
Il NPC latcha PC+4 perchè Il PC+4 adder somma correttamente.

Dopo un controllo per dimostrare che i vari enable sono indipendenti, ho dettato JUMP_TARGET a 0x020 e messo PC_SEL a 1 per simulare un branch taken. PC va correttamente a 0x20 e poi ricomincia la sequenza di +4

