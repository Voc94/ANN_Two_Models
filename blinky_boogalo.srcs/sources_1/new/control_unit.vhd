library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_cfg_pkg.all;

entity control_unit is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    start_btn     : in  std_logic;
    norm_done     : in  std_logic;
    ann_done      : in  std_logic;
    -- Outputs
    norm_start    : out std_logic;
    start_debug   : out std_logic;
    start_ann     : out std_logic;
    state_out     : out std_logic_vector(3 downto 0)
  );
end entity;

architecture Behavioral of control_unit is

  type state_t is (
    STATE_INIT,
    STATE_NORMALIZE,
    STATE_WAIT_DEBUG,
    STATE_DEBUG,
    STATE_ANN,
    STATE_FINISHED
  );

  signal state, next_state : state_t := STATE_INIT;
  signal prev_start        : std_logic := '0';
  signal start_ann_pulse   : std_logic := '0';

begin

  -- Synchronous state register and pulse generation
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state            <= STATE_INIT;
        prev_start       <= '0';
        start_ann_pulse  <= '0';
      else
        state       <= next_state;
        prev_start  <= start_btn;

        -- Generate 1-cycle pulse for start_ann
        if state /= STATE_ANN and next_state = STATE_ANN then
          start_ann_pulse <= '1';
        else
          start_ann_pulse <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Combinational next state logic and output defaults
  process(state, start_btn, prev_start, norm_done, ann_done)
  begin
    -- Default output values
    norm_start  <= '0';
    start_debug <= '0';

    case state is
      when STATE_INIT =>
        if start_btn = '1' then
          norm_start <= '1';
          next_state <= STATE_NORMALIZE;
        else
          next_state <= STATE_INIT;
        end if;

      when STATE_NORMALIZE =>
        if norm_done = '1' then
          next_state <= STATE_WAIT_DEBUG;
        else
          next_state <= STATE_NORMALIZE;
        end if;

      when STATE_WAIT_DEBUG =>
        if start_btn = '0' then
          next_state <= STATE_DEBUG;
        else
          next_state <= STATE_WAIT_DEBUG;
        end if;

      when STATE_DEBUG =>
        start_debug <= '1';
        if start_btn = '1' and prev_start = '0' then
          next_state <= STATE_ANN;
        else
          next_state <= STATE_DEBUG;
        end if;

      when STATE_ANN =>
        if ann_done = '1' then
          next_state <= STATE_FINISHED;
        else
          next_state <= STATE_ANN;
        end if;

      when STATE_FINISHED =>
        next_state <= STATE_FINISHED;

      when others =>
        next_state <= STATE_INIT;
    end case;
  end process;

  -- Output assignments
  start_ann <= start_ann_pulse;
  state_out <= std_logic_vector(to_unsigned(state_t'pos(state), 4));

end architecture;
