library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity branch_resolution is
    port (
        jump_en_in : in  std_logic;
        eq_cond : in  std_logic;
        taken_in : in  std_logic;
        zero_checker_in : in  std_logic;
        actual_taken_out : out std_logic;
        update_en_out : out std_logic;
        mispredict_out : out std_logic
    );
end entity;

architecture bh of branch_resolution is 
    signal branch_true : std_logic;
    signal actual_taken_sig : std_logic;
begin
    branch_true      <= eq_cond and zero_checker_in;
    actual_taken_sig <= branch_true or jump_en_in;
    
    actual_taken_out <= actual_taken_sig;
    update_en_out    <= jump_en_in or eq_cond;
    mispredict_out   <= taken_in xor actual_taken_sig;
end bh;