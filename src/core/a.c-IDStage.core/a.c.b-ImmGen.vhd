library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Immediate generator for the DLX-basic subset.
-- Reads the opcode of IR to decide sign-extend vs zero-extend for I-type,
-- and to select the J-type 26-bit field for J/JAL.
--
-- IMM_OUT      : full-width extended immediate (used by the jump-target adder)
-- IMM_TO_MUXB  : same as IMM_OUT, but forced to 0 when opcode = 0x03 (JAL),
--                so the ALU trick (ALU = NPC + 0 = NPC) produces the link
--                value written into R31.
entity ImmGen is
  generic (
    IR_SIZE : integer := 32;
    N       : integer := 32
  );
  port (
    IR          : in  std_logic_vector(IR_SIZE-1 downto 0);
    IMM_OUT     : out std_logic_vector(N-1 downto 0);
    IMM_TO_MUXB : out std_logic_vector(N-1 downto 0)
  );
end ImmGen;

architecture BEHAVIORAL of ImmGen is

  signal opcode  : std_logic_vector(5 downto 0);
  signal imm16   : std_logic_vector(15 downto 0);
  signal imm26   : std_logic_vector(25 downto 0);
  signal sign16  : std_logic_vector(N-1 downto 0);
  signal zero16  : std_logic_vector(N-1 downto 0);
  signal sign26  : std_logic_vector(N-1 downto 0);
  signal ext     : std_logic_vector(N-1 downto 0);
  signal is_zero : boolean;
  signal is_jtyp : boolean;
  signal is_jal  : boolean;

begin

  opcode <= IR(IR_SIZE-1 downto IR_SIZE-6);
  imm16  <= IR(15 downto 0);
  imm26  <= IR(25 downto 0);

  sign16 <= std_logic_vector(resize(signed(imm16), N));
  zero16 <= std_logic_vector(resize(unsigned(imm16), N));
  sign26 <= std_logic_vector(resize(signed(imm26), N));

  -- zero-extend for andi / ori / xori
  is_zero <= (opcode = "001100") or  -- 0x0C ANDI
             (opcode = "001101") or  -- 0x0D ORI
             (opcode = "001110");    -- 0x0E XORI

  -- J-type imm26 for J / JAL
  is_jtyp <= (opcode = "000010") or  -- 0x02 J
             (opcode = "000011");    -- 0x03 JAL

  is_jal  <= (opcode = "000011");    -- 0x03 JAL

  ext <= sign26 when is_jtyp else
         zero16 when is_zero else
         sign16;

  IMM_OUT     <= ext;
  IMM_TO_MUXB <= (others => '0') when is_jal else ext;

end BEHAVIORAL;

configuration CFG_IMMGEN_BEH of ImmGen is
  for BEHAVIORAL
  end for;
end configuration;
