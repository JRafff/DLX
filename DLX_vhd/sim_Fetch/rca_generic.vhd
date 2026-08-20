library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all;
use WORK.constants.all; -- libreria WORK user-defined

-- Ripple Carry Adder parametrizzato su NBIT. 
-- Calcola la somma S = A + B + Ci e fornisce il carry out Co
entity RCA_GENERIC is 
	generic (
    NBIT : integer:= numBit);
	Port (	
    A :	In	std_logic_vector(NBIT-1 downto 0);
		B :	In	std_logic_vector(NBIT-1 downto 0);
		Ci : In	std_logic;
		S :	Out	std_logic_vector(NBIT-1 downto 0);
		Co :	Out	std_logic);
end RCA_GENERIC; 

architecture STRUCTURAL of RCA_GENERIC is

-- L'architettura strutturale utilizza il costrutto 'generate' per 
-- istanziare parametricamente N Full-Adder (FA) in cascata.
-- Il riporto (Carry) viene propagato dall'i-esimo stadio al successivo
-- tramite il segnale di appoggio CTMP.

  signal STMP : std_logic_vector(NBIT-1 downto 0);
  signal CTMP : std_logic_vector(NBIT downto 0);

  component FA 
  Port ( 
    A:	In	std_logic;
	  B:	In	std_logic;
	  Ci:	In	std_logic;
	  S:	Out	std_logic;
	  Co:	Out	std_logic);
  end component; 

begin

  CTMP(0) <= Ci;
  S <= STMP;
  Co <= CTMP(NBIT);
  -- Generazione iterativa degli N Full-Adder
  ADDER1: for I in 1 to NBIT generate
    FAI : FA 
	  generic map (DFAS => DRCAS, DFAC => DRCAC) 
	  Port Map (A(I-1), B(I-1), CTMP(I-1), STMP(I-1), CTMP(I)); 
  end generate;
end STRUCTURAL;

-- L'architettura comportamentale esegue l'addizione ad alto livello.
-- Gli operandi vengono estesi di un bit usando la concatenazione ('0' &)
-- per permettere il calcolo automatico del Carry-Out in un vettore
-- temporaneo di dimensione NBIT+1.
architecture BEHAVIORAL of RCA_GENERIC is
signal RES_TMP : std_logic_vector(NBIT downto 0);
begin
  
  -- Sommiamo A, B e il carry in (Ci) estendendo tutto a NBIT+1
  -- Usiamo '0' & A per passare da NBIT a NBIT+1
  RES_TMP <= ('0' & A) + ('0' & B) + Ci;

  -- Assegniamo i primi NBIT bit alla somma S
  S <= RES_TMP(NBIT-1 downto 0);

  -- Il bit MSB è il nostro Carry Out
  Co <= RES_TMP(NBIT);
  
end BEHAVIORAL;

configuration CFG_RCA_GENERIC_STRUCTURAL of RCA_GENERIC is
  for STRUCTURAL 
    for ADDER1
      for all : FA
        use configuration WORK.CFG_FA_BEHAVIORAL;
      end for;
    end for;
  end for;
end CFG_RCA_GENERIC_STRUCTURAL;

configuration CFG_RCA_GENERIC_BEHAVIORAL of RCA_GENERIC is
  for BEHAVIORAL 
  end for;
end CFG_RCA_GENERIC_BEHAVIORAL;
