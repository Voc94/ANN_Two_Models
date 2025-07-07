library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
  generic (
    CLK_FREQ  : integer := 100_000_000;
    BAUD_RATE : integer := 9600
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    tx_start : in  std_logic;
    data_in  : in  std_logic_vector(7 downto 0);
    tx       : out std_logic;
    tx_busy  : out std_logic
  );
end entity;

architecture RTL of uart_tx is
  constant BAUD_TICKS : integer := CLK_FREQ / BAUD_RATE;
  type state_type is (IDLE, START, DATA, STOP);
  signal state      : state_type := IDLE;
  signal baud_count : integer range 0 to BAUD_TICKS-1 := 0;
  signal bit_count  : integer range 0 to 7 := 0;
  signal data_buf   : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_reg     : std_logic := '1';
  signal tx_busy_reg: std_logic := '0';
begin

  process(clk, rst)
  begin
    if rst = '1' then
      state       <= IDLE;
      baud_count  <= 0;
      bit_count   <= 0;
      tx_reg      <= '1';
      tx_busy_reg <= '0';
    elsif rising_edge(clk) then
      case state is
        when IDLE =>
          tx_reg      <= '1';
          tx_busy_reg <= '0';
          if tx_start = '1' then
            state     <= START;
            data_buf  <= data_in;
            baud_count<= BAUD_TICKS-1;
            tx_busy_reg <= '1';
          end if;
        when START =>
          tx_reg <= '0';
          if baud_count = 0 then
            state <= DATA;
            baud_count <= BAUD_TICKS-1;
            bit_count <= 0;
          else
            baud_count <= baud_count - 1;
          end if;
        when DATA =>
          tx_reg <= data_buf(bit_count);
          if baud_count = 0 then
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
          tx_reg <= '1';
          if baud_count = 0 then
            state <= IDLE;
          else
            baud_count <= baud_count - 1;
          end if;
        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

  tx      <= tx_reg;
  tx_busy <= tx_busy_reg;
end architecture;
