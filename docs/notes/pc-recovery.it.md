Errore nel recupero dopo una misprediction

Problema. Quando la BTB predice un branch come "taken" ma il branch, risolto in ID, non salta (tipicamente all'ultima iterazione di un loop), la CPU rileva correttamente la misprediction (mispredict = taken_in XOR actual_taken) e svuota l'IF/ID. Il PC però riparte dall'indirizzo sbagliato: viene ricaricato con il target del branch invece che con l'istruzione successiva. Il loop quindi non termina.

Causa. L'unico indirizzo di recupero che la Decode produce è NPC + IMM, cioè il target. Questo è corretto solo quando la BTB aveva predetto "not taken" e il branch salta. Nel caso opposto l'indirizzo corretto è NPC (PC del branch + 4), che il mux PC_sel non aveva a disposizione.

Correzione. Al mux PC_sel sono stati aggiunti due ingressi: actual_taken e l'NPC del branch, ricavato come pc_update_in + 4. In caso di misprediction il mux sceglie il target se actual_taken = 1, altrimenti l'NPC del branch. La priorità diventa:

mispredict e actual_taken: target (recovery)
mispredict e non actual_taken: NPC del branch
taken (BTB): target predetto
altrimenti: PC + 4

Il filo verso la BTB (Actual_Target) resta invariato e contiene sempre il target, quindi la BTB non viene corrotta. La modifica riguarda solo PC_sel e il suo port map in IFStage.