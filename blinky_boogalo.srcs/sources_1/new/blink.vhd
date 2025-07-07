library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity blink is
  generic (
    IMG_W    : integer := 16; -- image width
    IMG_H    : integer := 16; -- image height
    CLK_FREQ : integer := 100_000_000;
    BAUD_RATE: integer := 9600
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    uart_rx : in  std_logic;
    uart_tx : out std_logic;
    led     : out std_logic -- maybe on when validation is complete?
  );
end entity;

architecture RTL of blink is
  constant IMG_SIZE : integer := IMG_W * IMG_H;
  type img_array_t is array(0 to IMG_SIZE-1) of std_logic_vector(7 downto 0);

  signal rx_data    : std_logic_vector(7 downto 0);
  signal rx_valid   : std_logic;
  signal tx_start   : std_logic := '0';
  signal tx_data    : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy    : std_logic;
  signal uart_tx_i  : std_logic;

  -- Image buffer
  signal img_buf    : img_array_t := (others => (others => '0'));
  signal img_idx    : integer range 0 to IMG_SIZE := 0;
  signal send_idx   : integer range 0 to IMG_SIZE := 0;
  signal state      : integer range 0 to 3 := 0; -- 0: waiting RX, 1: wait TX ready, 2: sending, 3: done

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
      tx         => uart_tx_i,
      data_out   => rx_data,
      data_valid => rx_valid,
      tx_start   => tx_start,
      data_in    => tx_data,
      tx_busy    => tx_busy
    );

  uart_tx <= uart_tx_i;

  process(clk, rst)
  begin
    if rst = '1' then
      img_idx  <= 0;
      send_idx <= 0;
      state    <= 0;
      led      <= '0';
      tx_start <= '0';
    elsif rising_edge(clk) then
      case state is
        when 0 => -- Receiving image
          if rx_valid = '1' and img_idx < IMG_SIZE then
            img_buf(img_idx) <= rx_data;
            img_idx <= img_idx + 1;
            if img_idx = IMG_SIZE - 1 then
              send_idx <= 0;
              state <= 1; -- ready to send
            end if;
          end if;
          tx_start <= '0';
          led <= '0';

        when 1 => -- Wait for TX not busy
          if tx_busy = '0' then
            tx_data <= img_buf(send_idx);
            tx_start <= '1';
            state <= 2;
          end if;
          led <= '0';

        when 2 => -- Sending image back
          tx_start <= '0'; -- Pulse
          if tx_busy = '0' then
            if send_idx < IMG_SIZE - 1 then
              send_idx <= send_idx + 1;
              state <= 1;
            else
              state <= 3; -- Done
              led <= '1'; -- LED ON when finished
            end if;
          end if;

        when 3 => -- Finished
          tx_start <= '0';
          led <= '1';

        when others =>
          state <= 0;
      end case;
    end if;
  end process;
end architecture;
