library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use std.textio.all;
use ieee.std_logic_textio.all;

-- Instruction memory for DLX
-- Memory filled by a process which reads from a file
-- file name is "test.asm.mem"
entity IRAM is
  generic (
    RAM_DEPTH : integer := 64;
    I_SIZE : integer := 32);
  port (
    Clk     : in  std_logic; --memoria sincrona
    Rst     : in  std_logic;
    Read_EN : in  std_logic; -- Enable in ingresso dalla Cache
    Addr    : in  std_logic_vector(I_SIZE - 1 downto 0);
    Dout    : out std_logic_vector(I_SIZE - 1 downto 0);
    Ready   : out std_logic  -- Segnale di Done verso la Cache
    );

end IRAM;

architecture IRam_Bhe of IRAM is

  type RAMtype is array (0 to RAM_DEPTH - 1) of integer;
  signal IRAM_mem : RAMtype;
  
  -- Contatore per gestire i 3 colpi di clock di latenza
  signal wait_cnt : integer range 0 to 3 := 0;

begin  

  -- Processo Sincrono per gestire la latenza di lettura
  read_process: process(Clk, Rst)
  begin
    if Rst = '0' then
      wait_cnt <= 0;
      Ready <= '0';
      Dout <= (others => '0');
      
    elsif rising_edge(Clk) then
      
      if Read_EN = '1' then
        if wait_cnt < 2 then
          wait_cnt <= wait_cnt + 1;
          Ready <= '0';
          
        elsif wait_cnt = 2 then
          -- Il dato è pronto lo metto in uscita e alzo Ready
          Dout <= conv_std_logic_vector(IRAM_mem(conv_integer(unsigned(Addr(I_SIZE-1 downto 2)))), I_SIZE);
          Ready <= '1';
          wait_cnt <= wait_cnt + 1; -- Porto a 3 per bloccare il contatore
          
        else
          -- Mantengo i dati stabili finché la cache non abbassa Read_EN
          Ready <= '1';
        end if;
        
      else
        -- Se Read_EN torna a 0 (lettura finita), resetto 
        wait_cnt <= 0;
        Ready <= '0';
      end if;
      
    end if;
  end process read_process;

  
  -- Processo originale per riempire la memoria da file
  FILL_MEM_P: process (Rst)
    file mem_fp: text;
    variable file_line : line;
    variable index : integer := 0;
    variable tmp_data_u : std_logic_vector(I_SIZE-1 downto 0);
  begin  -- process FILL_MEM_P
    if (Rst = '0') then
      index := 0;  -- reset the write index so subsequent resets refill from the top
      file_open(mem_fp, "test_all.asm.mem", READ_MODE);
      while (not endfile(mem_fp)) loop
        readline(mem_fp, file_line);
        hread(file_line, tmp_data_u);
        IRAM_mem(index) <= conv_integer(unsigned(tmp_data_u));
        index := index + 1;
      end loop;
      file_close(mem_fp);  -- close so the next Rst pulse can reopen it
    end if;
  end process FILL_MEM_P;

end IRam_Bhe;