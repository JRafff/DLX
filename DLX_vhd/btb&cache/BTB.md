# Branch Prediction: BTB, Risoluzione e PC MUX

Questo documento descrive l'architettura e il funzionamento della logica di previsione dei salti (Branch Prediction) implementata per il processore DLX. Il sistema è progettato per minimizzare gli stalli nella pipeline causate dalle istruzioni di salto, prevedendone in anticipo la destinazione e l'esito.

Il sottosistema è suddiviso in tre componenti principali che collaborano attivamente tra gli stadi di Fetch e Decode.

---

## Branch Target Buffer (BTB)

La BTB (Branch Target Buffer) è il cuore del sistema. Il suo scopo è memorizzare le informazioni storiche sui salti già incontrati dal processore, in modo da poterne prevedere il comportamento futuro.

Strutturalmente, la BTB è un array (tabella) di **64 locazioni**. Ogni singola locazione (modellata come un `record` in VHDL) contiene quattro campi fondamentali:

1. **Valid:** Un bit che indica se la casella contiene dati significativi.


2. **Tag:** 24 bit per identificare univocamente l'indirizzo dell'istruzione di salto.


3. **Target:** L'indirizzo di destinazione a 32 bit calcolato in esecuzioni precedenti.


4. **History:** Un contatore a 2 bit che funge da predittore (2-bit saturating counter).



Il funzionamento della BTB si divide in due fasi distinte gestite da due processi VHDL separati:

### 1.1 Fase di Fetch: La Predizione (Lettura Combinatoria)

Durante lo stadio di prelievo (Fetch) delle istruzioni, la BTB "spia" il Program Counter in ingresso ed esegue una ricerca in modo totalmente asincrono e istantaneo (processo combinatorio):

* **Indicizzazione:** L'indice per accedere alla tabella (da 0 a 63) viene estratto prelevando i bit dal `7` al `2` del Program Counter (PC) attuale.


* **Verifica Hit:** Il Tag salvato nella casella indicizzata viene confrontato con i bit dal `31` all'`8` del PC in ingresso. Se i Tag corrispondono e il bit Valid è a `'1'`, si verifica un *Hit*.


* **Emissione della Predizione:** Se c'è un Hit, l'algoritmo valuta lo storico: la predizione `taken` (salta) viene alzata a `'1'` *se e solo se* il bit più significativo del contatore storico (il bit 1) è a `'1'`. Questo bit discrimina tra gli stati "salta" (*Weakly* o *Strongly Taken*) e "non salta" (*Weakly* o *Strongly Not Taken*).


* **Emissione del Target:** Contemporaneamente, l'indirizzo di destinazione salvato (`Predicted_target`) viene fornito in uscita, pronto per essere utilizzato nel ciclo successivo se la predizione è *taken*.



### 1.2 Fase di Decode: L'Apprendimento (Scrittura Sincrona)

L'aggiornamento (o apprendimento) della memoria BTB avviene nello stadio di Decode. Questo processo è rigorosamente **sincrono** e scatta sul fronte di salita del clock quando il segnale `update_en` (Enable) è alto.

L'algoritmo di aggiornamento si basa sulla Macchina a Stati del **contatore saturante a 2 bit**, che aggiunge isteresi (inerzia) alle previsioni per non farsi ingannare da variazioni improvvise:

* **Rafforzamento Taken:** Se il salto è stato effettivamente preso nella realtà (`Actual_Taken = '1'`), il contatore si incrementa (+1). Si ferma saturando al valore massimo "11" (*Strongly Taken*).


* **Rafforzamento Not Taken:** Se il salto non è stato preso (`Actual_Taken = '0'`), il contatore si decrementa (-1). Si ferma saturando al valore minimo "00" (*Strongly Not Taken*).


* **Gestione dei Miss (Nuovi Inserimenti):** Nel caso in cui la casella letta non contenga un Tag corrispondente (o non sia valida), significa che è la prima volta che il processore incontra questo specifico salto. In questo caso, il dato precedente viene sovrascritto e il contatore viene inizializzato con uno stato "debole":


* "10" (*Weakly Taken*) se l'esito reale calcolato ora è '1'.


* "01" (*Weakly Not Taken*) se l'esito reale calcolato ora è '0'.





---

## 2. Unità di Risoluzione del Branch (`branch_resolution`)

Questo modulo puramente combinatorio risiede nello stadio di Decode. Funge da "giudice" del sistema, calcolando la verità assoluta e confrontandola con le promesse della BTB. Le sue responsabilità sono:

1. **Calcolo della Verità (`actual_taken_out`):** Determina l'esito reale del salto valutando i segnali provenienti dalla Control Unit e dalla ALU. Un salto è realmente preso se si verificano le condizioni del Branch (`eq_cond` AND `zero_checker_in`) oppure se c'è un comando di Jump incondizionato (`jump_en_in`).


2. **Rilevamento dell'Errore (`mispredict_out`):** È il compito più critico. Genera un segnale di allarme altissimo eseguendo una semplice porta **XOR** tra la predizione passata formulata dalla BTB (`taken_in`) e la realtà appena calcolata (`actual_taken_sig`). Se sono diversi (es. predizione = 1 ma realtà = 0, o viceversa), il segnale si alza a '1'.


3. **Trigger per l'Aggiornamento (`update_en_out`):** Fornisce alla BTB il segnale di abilitazione alla scrittura (Enable) ogniqualvolta si incontri un'istruzione di salto o diramazione (`jump_en_in` OR `eq_cond`), indipendentemente dal suo esito.



---

## 3. Multiplexer del Program Counter (`pc_mux`)

Il `pc_mux` è posizionato all'inizio del Datapath, nello stadio di Fetch, e controlla fisicamente quale sarà il prossimo indirizzo inserito nel Program Counter. È implementato come un Multiplexer (MUX) guidato da una logica a **priorità rigida**:

1. **Priorità Massima - Il Recupero da Errore:**
Se l'Unità di Risoluzione alza l'allarme (`mispredict_in = '1'`), il MUX scarta tutto e seleziona immediatamente l'indirizzo di recupero (`recovery_address_in`) per riportare la pipeline sulla traiettoria corretta.


2. **Priorità Media - La Predizione:**
Se non ci sono errori in corso, ma la BTB "ordina" di saltare al termine del Fetch (`taken_in = '1'`), il MUX asseconda la previsione e seleziona il target previsto (`predicted_target_in`).


3. **Priorità Bassa - L'Avanzamento Normale:**
In assenza di salti, allarmi o predizioni, il MUX esegue il suo compito di default: fa avanzare il processore all'istruzione successiva selezionando `npc_in` (PC + 4).

