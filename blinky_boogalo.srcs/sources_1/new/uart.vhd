library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart is
  generic (
    CLK_FREQ  : integer := 100_000_000;
    BAUD_RATE : integer := 9600
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    rx       : in  std_logic;
    tx       : out std_logic;
    -- RX signals
    data_out : out std_logic_vector(7 downto 0);
    data_valid : out std_logic;
    -- TX signals
    tx_start : in  std_logic;
    data_in  : in  std_logic_vector(7 downto 0);
    tx_busy  : out std_logic
  );
end entity;

architecture RTL of uart is
  -- Internal signals
  signal rx_data      : std_logic_vector(7 downto 0);
  signal rx_valid     : std_logic;
  signal tx_line      : std_logic;
  signal tx_busy_sig  : std_logic;
begin
  -- RX instance
  uart_rx_inst: entity work.uart_rx
    generic map (
      CLK_FREQ  => CLK_FREQ,
      BAUD_RATE => BAUD_RATE
    )
    port map (
      clk        => clk,
      rst        => rst,
      rx         => rx,
      data_out   => rx_data,
      data_valid => rx_valid
    );

  -- TX instance
  uart_tx_inst: entity work.uart_tx
    generic map (
      CLK_FREQ  => CLK_FREQ,
      BAUD_RATE => BAUD_RATE
    )
    port map (
      clk      => clk,
      rst      => rst,
      tx_start => tx_start,
      data_in  => data_in,
      tx       => tx_line,
      tx_busy  => tx_busy_sig
    );

  -- Outputs
  data_out  <= rx_data;
  data_valid <= rx_valid;
  tx        <= tx_line;
  tx_busy   <= tx_busy_sig;

end architecture;
