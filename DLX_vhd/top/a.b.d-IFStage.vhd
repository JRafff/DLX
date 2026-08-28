library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IFStage is
  generic (
    IR_SIZE : integer := 32;
    PC_SIZE : integer := 32
  );
  port (
    Clk                 : in  std_logic;
    Rst                 : in  std_logic; -- active low
    
    -- Control signals dalla CU
    PC_LATCH_EN         : in  std_logic;
    
    -- Feedback signals from Decode (Branch Prediction)
    mispredict_in       : in  std_logic;
    update_en_in        : in  std_logic;
    actual_taken_in     : in  std_logic;
    recovery_address_in : in  std_logic_vector(PC_SIZE-1 downto 0);
    pc_update_in        : in  std_logic_vector(PC_SIZE-1 downto 0);
    
    -- Outputs verso il registro IF/ID (esterno)
    PC_OUT              : out std_logic_vector(PC_SIZE-1 downto 0); 
    NPC_OUT             : out std_logic_vector(PC_SIZE-1 downto 0); 
    IR_OUT              : out std_logic_vector(IR_SIZE-1 downto 0); 
    
    -- Output verso la Control Unit / Hazard Unit
    cache_miss_out      : out std_logic 
  );
end IFStage;

architecture STRUCTURAL of IFStage is

  component reg_en
    generic (NBIT : integer := 32);
    port (
      Clk : in  std_logic;
      Rst : in  std_logic;
      EN  : in  std_logic;
      D   : in  std_logic_vector(NBIT-1 downto 0);
      Q   : out std_logic_vector(NBIT-1 downto 0)
    );
  end component;
  
  component pc_mux
    generic (N : integer := 32);
    port (
        npc_in              : in  std_logic_vector(N-1 downto 0);
        predicted_target_in : in  std_logic_vector(N-1 downto 0);
        recovery_address_in : in  std_logic_vector(N-1 downto 0);
        mispredict_in       : in  std_logic;
        taken_in            : in  std_logic;
        next_pc_out         : out std_logic_vector(N-1 downto 0)
    );
  end component;

  component BTB
    generic (N : integer := 32);
    port (
        clk              : in  std_logic;
        PC_in            : in  std_logic_vector(N-1 downto 0); 
        Predicted_target : out std_logic_vector(N-1 downto 0); 
        taken            : out std_logic;
        PC_update        : in  std_logic_vector(N-1 downto 0);
        update_en        : in  std_logic; 
        Actual_Taken     : in  std_logic; 
        Actual_Target    : in  std_logic_vector(N-1 downto 0)
    );
  end component;

  component Icache
    generic (N : integer := 32);
    port (
        clk             : in  std_logic;
        pc_in           : in  std_logic_vector(N-1 downto 0); 
        instr_out       : out std_logic_vector(N-1 downto 0);
        hit             : out std_logic;
        ram_read_en_out : out std_logic;
        ram_ready_in    : in  std_logic;
        ram_data_in     : in  std_logic_vector(N-1 downto 0);
        pc_out          : out std_logic_vector(N-1 downto 0) 
    );
  end component;

  component IRAM
    generic (
        RAM_DEPTH : integer := 64;
        I_SIZE    : integer := 32
    );
    port (
        Clk     : in  std_logic; 
        Rst     : in  std_logic;
        Read_EN : in  std_logic; 
        Addr    : in  std_logic_vector(I_SIZE - 1 downto 0);
        Dout    : out std_logic_vector(I_SIZE - 1 downto 0);
        Ready   : out std_logic  
    );
  end component;

  -- Segnali PC
  signal PC_reg       : std_logic_vector(PC_SIZE-1 downto 0); 
  signal PC_plus4     : std_logic_vector(PC_SIZE-1 downto 0); 
  signal PC_next      : std_logic_vector(PC_SIZE-1 downto 0); 
  
  -- Segnali I-Cache / I-RAM
  signal cache_hit    : std_logic;
  signal cache_instr  : std_logic_vector(IR_SIZE-1 downto 0);
  signal ram_read_req : std_logic;
  signal ram_ready    : std_logic;
  signal ram_data     : std_logic_vector(IR_SIZE-1 downto 0);
  signal ram_addr     : std_logic_vector(PC_SIZE-1 downto 0);

  -- Segnali BTB
  signal btb_target   : std_logic_vector(PC_SIZE-1 downto 0);
  signal btb_taken    : std_logic;

begin

  -- Notifica la CU se la pipeline deve essere stallata a causa della memoria
  cache_miss_out <= not cache_hit;

  -- Sommatore Behavioral (+ 4)
  PC_plus4 <= std_logic_vector(unsigned(PC_reg) + 4);

  U_PC_MUX: pc_mux
    generic map (N => PC_SIZE)
    port map (
      npc_in              => PC_plus4,
      predicted_target_in => btb_target,
      recovery_address_in => recovery_address_in,
      mispredict_in       => mispredict_in,
      taken_in            => btb_taken,
      next_pc_out         => PC_next
    );

  U_BTB: BTB
    generic map (N => PC_SIZE)
    port map (
      clk              => Clk,
      PC_in            => PC_reg,
      Predicted_target => btb_target,
      taken            => btb_taken,
      PC_update        => pc_update_in,
      update_en        => update_en_in,
      Actual_Taken     => actual_taken_in,
      Actual_Target    => recovery_address_in
    );

  U_ICACHE: Icache
    generic map (N => PC_SIZE)
    port map (
      clk             => Clk,
      pc_in           => PC_reg,
      instr_out       => cache_instr,
      hit             => cache_hit,
      ram_read_en_out => ram_read_req,
      ram_ready_in    => ram_ready,
      ram_data_in     => ram_data,
      pc_out          => ram_addr
    );

  U_IRAM: IRAM
    generic map (RAM_DEPTH => 64, I_SIZE => 32)
    port map (
      Clk     => Clk,
      Rst     => Rst,
      Read_EN => ram_read_req,
      Addr    => ram_addr,
      Dout    => ram_data,
      Ready   => ram_ready
    );

  -- Registro Program Counter controllato dalla CU
  PC_R: reg_en
    generic map (NBIT => PC_SIZE)
    port map (
      Clk => Clk, 
      Rst => Rst, 
      EN  => PC_LATCH_EN, 
      D   => PC_next, 
      Q   => PC_reg
    );

  -- uscite sul reg di pipe
  IR_OUT  <= cache_instr;
  NPC_OUT <= PC_plus4;
  PC_OUT  <= PC_reg;

end STRUCTURAL;