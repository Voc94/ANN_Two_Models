library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
  generic (
    CLK_FREQ  : integer := 100_000_000;
    BAUD_RATE : integer := 9600
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    rx       : in  std_logic;
    data_out : out std_logic_vector(7 downto 0);
    data_valid : out std_logic
  );
end entity;

architecture RTL of uart_rx is
  constant BAUD_TICKS : integer := CLK_FREQ / BAUD_RATE;
  type state_type is (IDLE, START, DATA, STOP);
  signal state      : state_type := IDLE;
  signal baud_count : integer range 0 to BAUD_TICKS-1 := 0;
  signal bit_count  : integer range 0 to 7 := 0;
  signal rx_shift   : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_sync_1, rx_sync_2 : std_logic := '1';
  signal data_valid_reg : std_logic := '0';
begin

  -- Double synchronizer for rx
  process(clk)
  begin
    if rising_edge(clk) then
      rx_sync_1 <= rx;
      rx_sync_2 <= rx_sync_1;
    end if;
  end process;

  -- UART receiver state machine
  process(clk, rst)
  begin
    if rst = '1' then
      state      <= IDLE;
      baud_count <= 0;
      bit_count  <= 0;
      rx_shift   <= (others => '0');
      data_valid_reg <= '0';
    elsif rising_edge(clk) then
      data_valid_reg <= '0'; -- pulse valid only for one clk
      case state is
        when IDLE =>
          if rx_sync_2 = '0' then
            state <= START;
            baud_count <= BAUD_TICKS/2;
          end if;
        when START =>
          if baud_count = 0 then
            state <= DATA;
            baud_count <= BAUD_TICKS-1;
            bit_count <= 0;
          else
            baud_count <= baud_count - 1;
          end if;
        when DATA =>
          if baud_count = 0 then
            rx_shift(bit_count) <= rx_sync_2;
            if bit_count = 7 then
              state <= STOP;
            else
              bit_count <= bit_count + 1;
            end if;
            baud_count <= BAUD_TICKS-1;
          else
            baud_count <= baud_count - 1;
          end if;
        when STOP =>
          if baud_count = 0 then
            state <= IDLE;
            data_valid_reg <= '1';
          else
            baud_count <= baud_count - 1;
          end if;
        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

  data_out   <= rx_shift;
  data_valid <= data_valid_reg;

end architecture;
