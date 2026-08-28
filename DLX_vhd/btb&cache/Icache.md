#   I-Cache & I-RAM

Questo modulo implementa il sottosistema di memoria per il fetch delle istruzioni del processore DLX. È composto da una **Cache Istruzioni (I-Cache)** associativa a 4 vie e da una **Memoria Principale Sincrona (I-RAM)** con latenza simulata, interfacciate tramite un protocollo di handshake completo.

---

## Architettura della I-Cache

La I-Cache è progettata per massimizzare le prestazioni tramite un accesso in lettura puramente combinatorio, garantendo latenza zero in caso di *Hit*, pur mantenendo un aggiornamento di stato rigorosamente sincrono.

* **Tipologia:** 4-Way Set Associative.
* **Capacità:** 16 Blocchi (4 Set $\times$ 4 Vie).
* **Dimensione Blocco:** 1 Parola (32 bit).
* **Decodifica Indirizzo (32 bit):**
* `Tag`: 28 bit (bit 31-4)
* `Index`: 2 bit (bit 3-2) -> Mappa su 4 Set
* `Offset`: 2 bit (bit 1-0) -> Ignorati (allineamento alla word)


### Algoritmo di Rimpiazzo: Tree-PLRU (Pseudo-LRU)

Per minimizzare l'hardware, la cache non usa un "True LRU", ma un approccio **Pseudo-LRU ad albero binario** che richiede solo 3 bit di stato per ogni Set.
Ogni volta che una "Via" viene letta o scritta, i 3 bit vengono aggiornati per puntare lontano dalla via appena utilizzata, "proteggendola" e garantendo che, in caso di Miss, venga sovrascritta la via usata meno di recente. L'aggiornamento dei bit PLRU avviene in modo sicuro (sincrono) sul fronte di salita del clock.

---

## ⏳ I-RAM e Protocollo di Handshake (Gestione del Miss)

La memoria principale (I-RAM) è stata aggiornata per simulare una latenza realistica (3 cicli di clock). Quando la Cache non trova l'istruzione (Miss), si innesca il seguente handshake:

1. **Miss Rilevato:** La Cache abbassa `hit = '0'` e alza la richiesta alla memoria `ram_read_en_out = '1'`, inviando il PC mancante.
2. **Latenza RAM:** La I-RAM riceve la richiesta e inizia a contare 3 cicli di clock. Durante questo tempo, l'istruzione non è disponibile.
3. **Dato Pronto:** Al 3° ciclo, la RAM mette l'istruzione sul bus `ram_data_in` e alza `ram_ready_in = '1'`.
4. **Scrittura in Cache:** Al colpo di clock successivo, la Cache rileva il `ready`, individua la "Vittima" tramite l'albero PLRU, vi scrive dentro il nuovo dato e aggiorna i bit PLRU.
5. **Risveglio Combinatorio:** Appena il dato è scritto in memoria, la logica combinatoria della Cache rileva l'Hit istantaneamente: emette l'istruzione, rialza `hit = '1'` e abbassa `ram_read_en_out`.
6. **Reset:** La RAM vede spegnersi la richiesta e azzera i suoi segnali di controllo, pronta per un nuovo ciclo.


## Lo Stallo della Pipeline

Affinché l'intero meccanismo di handshake funzioni senza corrompere l'esecuzione del programma, il Datapath del processore deve rispettare una regola ferrea:

> **IL PROGRAM COUNTER (PC) NON DEVE AVANZARE DURANTE UN MISS.**

Il processo combinatorio della Cache dipende direttamente dal `pc_in`. Se il PC cambiasse mentre la Cache sta aspettando i 3 cicli della RAM, la memoria riceverebbe un indirizzo corrotto e scriverebbe il dato nel Set sbagliato.


## Prossimi Passi: Modifiche alla Control Unit

Il prossimo step di sviluppo richiede di intervenire sulla logica di controllo (Control Unit / Datapath Top-Level) del processore per gestire l'arresto (Stall/Freeze) della pipeline in caso di Miss.

Quando il segnale `hit` proveniente dalla I-Cache è uguale a `'0'`, la Control Unit **DEVE** forzare i seguenti comportamenti:

* `PC_Write = '0'`: Disabilitare l'abilitazione alla scrittura del registro Program Counter (congelare il PC attuale).
* `IF_ID_Write = '0'`: Congelare il registro di pipeline IF/ID per non far propagare "spazzatura" (istruzioni nulle) nello stadio di Decode.
* *(Opzionale ma consigliato)*: Inserire una NOP (bolla) nella pipeline per gli stadi successivi, o semplicemente mettere in pausa l'intera pipeline fino al ripristino di `hit = '1'`.

---