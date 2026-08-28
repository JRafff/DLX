# Documentazione: Hazard Detection Unit (`hazard_detector.vhd`)

L'**Hazard Detection Unit** (HDU) è un modulo puramente combinatorio che funge da "sensore" per la pipeline del processore DLX. Il suo compito è monitorare costantemente le istruzioni presenti negli stadi di Decode (ID), Execute (EX) e Memory (MEM) per individuare conflitti sui dati che l'unità di Forwarding non è in grado di risolvere fisicamente.

Quando rileva un conflitto inevitabile, l'HDU non interviene direttamente sui registri, ma alza specifici segnali di "allarme" (`load_use_alarm` e `branch_stall_alarm`) diretti alla Control Unit (CU), la quale si occuperà di congelare il front-end della pipeline (stallo) e inserire bolle (flush/NOP) nel back-end.

---

## 1. Interfaccia dei Segnali (Port Map)

L'HDU estrae informazioni direttamente dal Datapath (indirizzi dei registri) e dalla pipeline di controllo della CU (segnali di write-enable e mux).

| Segnale | Direzione | Origine / Destinazione | Descrizione |
| --- | --- | --- | --- |
| **`ID_Rs1`, `ID_Rs2**` | IN | Datapath (ID) | Indirizzi dei registri sorgente letti dall'istruzione attualmente in Decode. |
| **`EQ_COND`** | IN | Control Unit (ID) | Vale `'1'` se l'istruzione in ID è un salto condizionato (Branch). |
| **`EX_Rd`** | IN | Datapath (EX) | Indirizzo del registro destinazione dell'istruzione in Execute. |
| **`EX_RF_WE`** | IN | Control Unit (EX) | Vale `'1'` se l'istruzione in EX scriverà nel Register File. |
| **`EX_WB_MUX_SEL`** | IN | Control Unit (EX) | Vale `'1'` se l'istruzione in EX prenderà il dato dalla Memoria (identifica una Load). |
| **`MEM_Rd`** | IN | Datapath (MEM) | Indirizzo del registro destinazione dell'istruzione in Memory. |
| **`MEM_RF_WE`** | IN | Control Unit (MEM) | Vale `'1'` se l'istruzione in MEM scriverà nel Register File. |
| **`MEM_WB_MUX_SEL`** | IN | Control Unit (MEM) | Vale `'1'` se l'istruzione in MEM è una Load. |
| **`load_use_alarm`** | OUT | Control Unit | Allarme per stallo da Load-Use standard (1 ciclo). |
| **`branch_stall_alarm`** | OUT | Control Unit | Allarme per stallo anticipato dovuto a un Branch in ID (1 o 2 cicli). |

---

## 2. Logica di Rilevamento Hazard

Il modulo gestisce due categorie distinte di conflitti sui dati.

### A. Load-Use Hazard (Stallo di 1 Ciclo)

Il forwarding non può risolvere la dipendenza se un'istruzione ha bisogno di un dato calcolato da una `LOAD` immediatamente precedente. La `LOAD` recupera il dato dalla RAM solo alla fine dello stadio MEM, ma l'istruzione successiva ne ha bisogno all'inizio dello stadio EX.

**Condizione scatenante:**

* In EX è presente una `LOAD` (`EX_RF_WE = '1'` AND `EX_WB_MUX_SEL = '1'`).
* Il target della Load (`EX_Rd`) coincide con `Rs1` o `Rs2` richiesti in Decode.
* Il target non è `R0` (il registro 0 non genera mai hazard essendo cablato a zero).

**Azione:** Alza `load_use_alarm`. La CU bloccherà PC e IF/ID per 1 ciclo.

### B. Branch Data Hazard (Stallo di 1 o 2 Cicli)

Poiché il DLX risolve i salti condizionati nello stadio di Decode per ridurre le penalità di misprediction, il comparatore `zero_check` in ID necessita del dato sorgente (`Rs1`) con un ciclo di anticipo rispetto alla normale ALU.

Questo genera due scenari critici in cui il normale forwarding verso EX non è sufficiente, controllati quando in ID è presente un Branch (`EQ_COND = '1'`):

1. **Conflitto ALU $\rightarrow$ Branch (Stallo di 1 Ciclo):**
* L'istruzione in EX sta calcolando un risultato tramite la ALU (`EX_RF_WE = '1'`) e il registro destinazione `EX_Rd` è proprio quello richiesto dal Branch (`ID_Rs1`).
* Il Branch deve attendere 1 ciclo affinché il dato passi nel registro EX/MEM e possa essere inoltrato al Decode.


2. **Conflitto LOAD $\rightarrow$ Branch (Stallo di 2 Cicli):**
* L'istruzione in MEM è una `LOAD` (`MEM_RF_WE = '1'` AND `MEM_WB_MUX_SEL = '1'`) e il registro destinazione `MEM_Rd` è quello richiesto dal Branch (`ID_Rs1`).
* Il Branch ha già atteso il primo ciclo (quando la Load era in EX), ma deve attenderne un secondo affinché la Load estragga il dato dalla RAM e lo posizioni nel registro MEM/WB per il forwarding verso il Decode.



**Azione:** Alza `branch_stall_alarm`. La CU bloccherà PC e IF/ID finché la dipendenza non scivola in uno stadio in cui è possibile il forwarding diretto al comparatore in Decode.