library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;

-- Instruction memory for DLX-pro.
-- Rispetto alla versione basic e' sincrona con handshake: quando la I-cache
-- alza Read_EN, la RAM impiega LATENCY cicli prima di alzare Ready e mettere
-- il dato su Dout. Coerente con l'algoritmo descritto in Icache.md.
--
-- La memoria e' caricata da test.asm.mem al reset (Rst attivo basso).
entity IRAM is
  generic (
    RAM_DEPTH : integer := 64;
    I_SIZE    : integer := 32;
    LATENCY   : integer := 3
  );
  port (
    Clk     : in  std_logic;
    Rst     : in  std_logic;                              -- active low
    Read_EN : in  std_logic;
    Addr    : in  std_logic_vector(I_SIZE - 1 downto 0);  -- byte address
    Dout    : out std_logic_vector(I_SIZE - 1 downto 0);
    Ready   : out std_logic
  );
end IRAM;

architecture behavioral of IRAM is

  type RAMtype is array (0 to RAM_DEPTH - 1) of std_logic_vector(I_SIZE-1 downto 0);
  signal IRAM_mem : RAMtype := (others => (others => '0'));

  -- Piccola FSM di handshake
  type state_t is (IDLE, WAITING, DONE);
  signal state       : state_t := IDLE;
  signal wait_count  : integer range 0 to LATENCY := 0;
  signal data_reg    : std_logic_vector(I_SIZE-1 downto 0) := (others => '0');
  signal ready_reg   : std_logic := '0';

begin

  -- Caricamento della memoria al reset
  FILL_MEM_P: process (Rst)
    file mem_fp : text;
    variable file_line : line;
    variable index     : integer := 0;
    variable tmp_data  : std_logic_vector(I_SIZE-1 downto 0);
  begin
    if (Rst = '0') then
      index := 0;
      file_open(mem_fp, "test.asm.mem", READ_MODE);
      while (not endfile(mem_fp)) and index < RAM_DEPTH loop
        readline(mem_fp, file_line);
        hread(file_line, tmp_data);
        IRAM_mem(index) <= tmp_data;
        index := index + 1;
      end loop;
      file_close(mem_fp);
    end if;
  end process FILL_MEM_P;

  -- Handshake sincrono. Al ricevimento di Read_EN='1', aspetta LATENCY
  -- cicli e poi alza Ready per un ciclo con il dato letto sull'uscita.
  HS: process(Clk, Rst)
    variable addr_idx : integer;
  begin
    if (Rst = '0') then
      state      <= IDLE;
      wait_count <= 0;
      data_reg   <= (others => '0');
      ready_reg  <= '0';
    elsif rising_edge(Clk) then
      case state is
        when IDLE =>
          ready_reg <= '0';
          if Read_EN = '1' then
            wait_count <= 1;
            state <= WAITING;
          end if;

        when WAITING =>
          if wait_count = LATENCY then
            addr_idx := conv_integer(unsigned(Addr(I_SIZE-1 downto 2)));
            if addr_idx >= 0 and addr_idx < RAM_DEPTH then
              data_reg <= IRAM_mem(addr_idx);
            else
              data_reg <= (others => '0');
            end if;
            ready_reg <= '1';
            state <= DONE;
          else
            wait_count <= wait_count + 1;
          end if;

        when DONE =>
          -- La cache scrive il dato al fronte successivo, poi abbassa Read_EN.
          ready_reg <= '0';
          if Read_EN = '0' then
            state <= IDLE;
          end if;
      end case;
    end if;
  end process HS;

  Dout  <= data_reg;
  Ready <= ready_reg;

end behavioral;
