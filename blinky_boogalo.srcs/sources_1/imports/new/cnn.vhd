library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_cfg_pkg.all;

-- =====================================================================
-- ENTITY
-- =====================================================================
entity nexys4_top is
port (
clk      : in  std_logic;
rst      : in  std_logic;
uart_rx  : in  std_logic;
uart_tx  : out std_logic;
led      : out std_logic_vector(3 downto 0);
start    : in  std_logic;
seg      : out std_logic_vector(7 downto 0);
an       : out std_logic_vector(7 downto 0)
);
end entity;

-- =====================================================================
-- ARCHITECTURE
-- =====================================================================
architecture Structural of nexys4_top is

-- ========================
-- CLOCK DIVIDER SIGNALS
-- ========================
component clk_divider
generic(WIDTH : integer := 20);
port(
  clk       : in  std_logic;
  rst       : in  std_logic;
  slow_tick : out std_logic
);
end component;

signal slow_tick : std_logic;

-- ========================
-- UART and BRAM SIGNALS
-- ========================
signal bram_addr     : unsigned(ADDR_WIDTH-1 downto 0);
signal bram_wr_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram_rd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram_we       : std_logic;
signal wea_sig       : std_logic_vector(0 downto 0);

signal uart_addr     : unsigned(ADDR_WIDTH-1 downto 0);
signal uart_wr_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal uart_rd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal uart_we       : std_logic;

-- ========================
-- Image Normalize <-> BRAM
-- ========================
signal img_addr      : unsigned(ADDR_WIDTH-1 downto 0);
signal img_wr_data   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal img_we        : std_logic;
signal img_rd_data   : std_logic_vector(DATA_WIDTH-1 downto 0);

-- ========================
-- Normalized BRAM interface
-- ========================
signal norm_addr     : unsigned(12 downto 0);
signal norm_wr_data  : std_logic_vector(15 downto 0);
signal norm_we       : std_logic;
signal norm_rd_data  : std_logic_vector(15 downto 0);
signal norm_done     : std_logic;

signal pp_addr       : unsigned(12 downto 0);
signal pp_wr_data    : std_logic_vector(15 downto 0);
signal pp_we         : std_logic;
signal pp_rd_data    : std_logic_vector(15 downto 0);

-- ========================
-- Debug + ANN + Display
-- ========================
signal uart_debug_addr : unsigned(12 downto 0);
signal debug_tx        : std_logic;
signal uart_cmd_tx     : std_logic;
signal debug_rx, cmd_rx: std_logic;

signal ann_done        : std_logic;
signal ann_addr        : unsigned(12 downto 0);
signal ann_rd_data     : std_logic_vector(15 downto 0);
signal final_class     : unsigned(3 downto 0);

signal led_reg         : std_logic_vector(3 downto 0);

-- ========================
-- Control Unit Interface
-- ========================
signal cu_norm_start   : std_logic;
signal cu_start_debug  : std_logic;
signal cu_start_ann    : std_logic;
signal fsm_state       : std_logic_vector(3 downto 0);

begin

-- ========================
-- UART COMMAND MODULE
-- ========================
uart_cmd_inst: entity work.uart_cmd
port map (
  clk           => clk,
  rst           => rst,
  uart_rx       => cmd_rx,
  uart_tx       => uart_cmd_tx,
  led           => open,
  bram_we       => uart_we,
  bram_wr_data  => uart_wr_data,
  bram_rd_data  => uart_rd_data,
  bram_addr     => uart_addr
);

wea_sig(0) <= bram_we;

-- ========================
-- IMAGE BRAM
-- ========================
image_bram_inst: entity work.blk_mem_gen_0
port map (
  clka   => clk,
  ena    => '1',
  wea    => wea_sig,
  addra  => std_logic_vector(bram_addr),
  dina   => bram_wr_data,
  douta  => bram_rd_data
);

uart_rd_data <= bram_rd_data;
img_rd_data  <= bram_rd_data;

-- BRAM WRITE MUX
bram_mux : process(fsm_state, uart_addr, uart_wr_data, uart_we,
                 img_addr, img_wr_data, img_we)
begin
bram_we      <= uart_we;
bram_wr_data <= uart_wr_data;
bram_addr    <= uart_addr;
if fsm_state = "0001" then
  bram_addr    <= img_addr;
  bram_wr_data <= img_wr_data;
  bram_we      <= img_we;
end if;
end process;

-- ========================
-- CLOCK DIVIDER
-- ========================
clk_div_inst : clk_divider
generic map ( WIDTH => 20 )
port map (
  clk       => clk,
  rst       => rst,
  slow_tick => slow_tick
);

-- ========================
-- CONTROL UNIT
-- ========================
control_unit_inst : entity work.control_unit
port map (
  clk         => clk,
  rst         => rst,
  start_btn   => start,
  norm_done   => norm_done,
  ann_done    => ann_done,
  norm_start  => cu_norm_start,
  start_debug => cu_start_debug,
  start_ann   => cu_start_ann,
  state_out   => fsm_state
);

-- ========================
-- LED DRIVER
-- ========================
led_driver : process(clk, rst)
begin
if rst = '1' then
  led_reg <= "0001";
elsif rising_edge(clk) then
  if slow_tick = '1' then
    case fsm_state is
      when "0000" => led_reg <= "0001"; -- INIT
      when "0001" => led_reg <= "0010"; -- NORMALIZE
      when "0010" => led_reg <= "0011"; -- WAIT_DEBUG
      when "0011" => led_reg <= "0011"; -- DEBUG
      when "0100" => led_reg <= "1111"; -- ANN
      when "0101" => led_reg <= "0110"; -- FINISHED
      when others => led_reg <= "0000";
    end case;
  end if;
end if;
end process;

led <= led_reg;

-- ========================
-- IMAGE NORMALIZATION
-- ========================
img_normalize_inst: entity work.img_normalize
generic map (
  G_IMG_W             => 64,
  G_IMG_H             => 64,
  IMG_BRAM_ADDR       => 13,
  IMG_BRAM_WIDTH      => 8,
  PING_PONG_BRAM_ADDR => 13,
  PING_PONG_BRAM_WIDTH=> 16
)
port map (
  clk             => clk,
  rst             => rst,
  start           => cu_norm_start,
  done            => norm_done,
  img_addr        => img_addr,
  img_din         => open,
  img_dout        => img_rd_data,
  img_we          => img_we,
  ping_pong_addr  => norm_addr,
  ping_pong_din   => norm_wr_data,
  ping_pong_dout  => norm_rd_data,
  ping_pong_we    => norm_we
);

-- ========================
-- NORMALIZED DATA BRAM
-- ========================
normalized_data_bram_inst: entity work.simple_bram
generic map (
  DATA_WIDTH => 16,
  ADDR_WIDTH => 13
)
port map (
  clk   => clk,
  we    => pp_we,
  addr  => pp_addr,
  din   => pp_wr_data,
  dout  => pp_rd_data
);

norm_rd_data <= pp_rd_data;
ann_rd_data  <= pp_rd_data;

-- ========================
-- PING-PONG MUX
-- ========================
ping_pong_mux : process(fsm_state, norm_addr, uart_debug_addr, ann_addr)
begin
pp_we <= '0';
case fsm_state is
  when "0001" =>  -- NORMALIZE
    pp_addr    <= norm_addr;
    pp_wr_data <= norm_wr_data;
    pp_we      <= norm_we;

  when "0011" =>  -- DEBUG
    pp_addr <= uart_debug_addr;

  when "0100" =>  -- ANN
    pp_addr <= ann_addr;

  when others =>
    pp_addr <= (others => '0');
end case;
end process;

-- ========================
-- UART DEBUG
-- ========================
uart_debug_inst: entity work.uart_debug
generic map (
  ADDR_WIDTH => 13,
  DATA_WIDTH => 16
)
port map (
  clk           => clk,
  rst           => rst,
  uart_rx       => debug_rx,
  uart_tx       => debug_tx,
  start_read    => cu_start_debug,
  num_addresses => 4096,
  bram_addr     => uart_debug_addr,
  bram_rd_data  => pp_rd_data
);

debug_mux : process(fsm_state, debug_tx, uart_cmd_tx)
begin
uart_tx <= uart_cmd_tx;
if fsm_state = "0011" then
  uart_tx <= debug_tx;
end if;
end process;

cmd_rx   <= uart_rx;
debug_rx <= uart_rx;

-- ========================
-- ANN INFERENCE MODULE
-- ========================
ann_inst : entity work.ann
port map (
  clk         => clk,
  rst         => rst,
  start       => cu_start_ann,
  done        => ann_done,
  in_addr     => ann_addr,
  in_rd_data  => ann_rd_data,
  final_class => final_class
);

-- ========================
-- 7-SEGMENT DISPLAY
-- ========================
seg_display_inst : entity work.seven_segment_decoder
port map (
  digit => final_class,
  seg   => seg,
  an    => an
);

end architecture;
