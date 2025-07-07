library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Import configuration package
library work;
use work.cnn_cfg_pkg.all;

entity uart_cmd is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    uart_rx       : in  std_logic;
    uart_tx       : out std_logic;
    led           : out std_logic_vector(3 downto 0);

    -- BRAM interface
    bram_we       : out std_logic;
    bram_wr_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
    bram_rd_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    bram_addr     : buffer unsigned(ADDR_WIDTH-1 downto 0)
  );
end entity;

architecture RTL of uart_cmd is

  signal rx_data       : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rx_valid      : std_logic;
  signal tx_start      : std_logic := '0';
  signal tx_data       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal tx_busy       : std_logic;

  signal cmd_reg       : std_logic_vector(7 downto 0) := (others => '0');

  type state_type is (
    WAIT_CMD,
    RECV_IMAGE,
    PREP_READ,
    SEND_IMAGE,
    WAIT_TX
  );
  signal state         : state_type := WAIT_CMD;

begin

  uart_inst: entity work.uart
    generic map (
      CLK_FREQ  => CLK_FREQ,
      BAUD_RATE => BAUD_RATE
    )
    port map (
      clk        => clk,
      rst        => rst,
      rx         => uart_rx,
      tx         => uart_tx,
      data_out   => rx_data,
      data_valid => rx_valid,
      tx_start   => tx_start,
      data_in    => tx_data,
      tx_busy    => tx_busy
    );

  process(clk, rst)
  begin
    if rst = '1' then
      state        <= WAIT_CMD;
      bram_addr    <= (others => '0');
      tx_start     <= '0';
      bram_we      <= '0';
      bram_wr_data <= (others => '0');
      cmd_reg      <= (others => '0');
      led          <= (others => '0');

    elsif rising_edge(clk) then
      tx_start <= '0';
      bram_we  <= '0';

      case state is
        when WAIT_CMD =>
          if rx_valid = '1' then
            cmd_reg <= rx_data;
            if rx_data = CMD_WRITE_IMAGE then
              bram_addr <= (others => '0');
              state <= RECV_IMAGE;
              led(0) <= '1';
            elsif rx_data = CMD_READ_IMAGE then
              bram_addr <= (others => '0');
              state <= PREP_READ;
              led(1) <= '1';
            end if;
          end if;

        when RECV_IMAGE =>
          if rx_valid = '1' then
            bram_wr_data <= rx_data;
            bram_we <= '1';
            if bram_addr = to_unsigned(IMG_SIZE - 1, ADDR_WIDTH) then
              state <= WAIT_CMD;
              led <= (others => '0');
            else
              bram_addr <= bram_addr + 1;
            end if;
          end if;

        when PREP_READ =>
          state <= SEND_IMAGE;

        when SEND_IMAGE =>
          if tx_busy = '0' then
            tx_data  <= bram_rd_data;
            tx_start <= '1';
            if bram_addr = to_unsigned(IMG_SIZE - 1, ADDR_WIDTH) then
              state <= WAIT_TX;
            else
              bram_addr <= bram_addr + 1;
              state <= PREP_READ;
            end if;
          end if;

        when WAIT_TX =>
          if tx_busy = '0' then
            state <= WAIT_CMD;
            led <= (others => '0');
          end if;

        when others =>
          state <= WAIT_CMD;
      end case;
    end if;
  end process;

end architecture;
