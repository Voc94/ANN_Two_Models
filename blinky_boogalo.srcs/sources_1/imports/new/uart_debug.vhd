library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_debug is
  generic (
    ADDR_WIDTH    : integer := 15;
    DATA_WIDTH    : integer := 16
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    uart_rx       : in  std_logic;  -- Unused
    uart_tx       : out std_logic;
    start_read    : in  std_logic;
    num_addresses : in  integer range 1 to 4096;
    bram_addr     : out unsigned(ADDR_WIDTH-1 downto 0);
    bram_rd_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture Behavioral of uart_debug is

  type state_t is (IDLE,WAIT_CMD, SET_ADDR, READ, SEND_HIGH, WAIT_TX_HIGH, SEND_LOW, WAIT_TX_LOW, DONE);
  signal state         : state_t := IDLE;

  signal addr_counter  : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal data_buf      : std_logic_vector(15 downto 0) := (others => '0');

  signal uart_data     : std_logic_vector(7 downto 0) := (others => '0');
  signal uart_start    : std_logic := '0';
  signal tx_busy       : std_logic;
  signal tx_line       : std_logic;
signal rx_data       : std_logic_vector(7 downto 0) := (others => '0');
signal rx_data_valid : std_logic := '0';
signal cmd_received  : std_logic := '0';
begin

  bram_addr <= addr_counter;  -- drive output port from internal signal

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state         <= IDLE;
        addr_counter  <= (others => '0');
        uart_start    <= '0';

      else
        uart_start <= '0';  -- default each cycle

        case state is

          when IDLE =>
            if start_read = '1' then
              addr_counter <= (others => '0');
              state        <= WAIT_CMD;
            end if;
          when WAIT_CMD =>
          -- Wait for rx_data_valid with rx_data = x"30"
          if rx_data_valid = '1' and rx_data = x"30" then
            cmd_received <= '1';
            addr_counter <= (others => '0');
            state <= SET_ADDR;
          elsif start_read = '0' then
            state <= IDLE; -- abort if start_read deasserted
          end if;

          when SET_ADDR =>
            state <= READ;

          when READ =>
            data_buf <= bram_rd_data;
            state    <= SEND_HIGH;

          when SEND_HIGH =>
            if tx_busy = '0' then
              uart_data  <= data_buf(15 downto 8);
              uart_start <= '1';
              state      <= WAIT_TX_HIGH;
            end if;

          when WAIT_TX_HIGH =>
            if tx_busy = '1' then
              state <= WAIT_TX_HIGH;
            else
              state <= SEND_LOW;
            end if;

          when SEND_LOW =>
            if tx_busy = '0' then
              uart_data  <= data_buf(7 downto 0);
              uart_start <= '1';
              state      <= WAIT_TX_LOW;
            end if;

          when WAIT_TX_LOW =>
            if tx_busy = '1' then
              state <= WAIT_TX_LOW;
            else
              if addr_counter = to_unsigned(num_addresses - 1, ADDR_WIDTH) then
                state <= IDLE;  -- Finished sending all addresses
              else
                addr_counter <= addr_counter + 1;
                state        <= SET_ADDR;
              end if;
            end if;

          when others =>
            state <= IDLE;

        end case;
      end if;
    end if;
  end process;

  uart_tx_inst : entity work.uart_tx
    generic map (
      CLK_FREQ  => 100_000_000,
      BAUD_RATE => 115200
    )
    port map (
      clk      => clk,
      rst      => rst,
      tx_start => uart_start,
      data_in  => uart_data,
      tx       => tx_line,
      tx_busy  => tx_busy
    );
uart_rx_inst: entity work.uart_rx
  generic map (
    CLK_FREQ  => 100_000_000,
    BAUD_RATE => 115200
  )
  port map (
    clk        => clk,
    rst        => rst,
    rx         => uart_rx,
    data_out   => rx_data,
    data_valid => rx_data_valid
  );
  uart_tx <= tx_line;

end Behavioral;