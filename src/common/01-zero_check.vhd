library ieee;
use ieee.std_logic_1164.all;

-- Blocco (BEQZ / BNEZ) condition check
entity zero_check is
    generic (
        NBIT : integer := 32
    );
    port (
        D_IN     : in  std_logic_vector(NBIT-1 downto 0); --(RegA)
        OPCODE   : in  std_logic_vector(5 downto 0);      -- Opcode 
        COND_OUT : out std_logic                          -- '1' se la condizione è vera
    );
end zero_check;

architecture BEHAVIORAL of zero_check is
    signal is_zero : std_logic;
begin
    -- Controlla se il dato in ingresso è esattamente zero
    is_zero <= '1' when (D_IN = x"00000000") else '0';

    -- L'Opcode del BEQZ è 0x04 (000100) -> Bit 0 = '0'
    -- L'Opcode del BNEZ è 0x05 (000101) -> Bit 0 = '1'
    COND_OUT <= is_zero when (OPCODE(0) = '0') else not(is_zero);

end BEHAVIORAL;
