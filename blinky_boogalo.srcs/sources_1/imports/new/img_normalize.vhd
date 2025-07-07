library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity img_normalize is
  generic (
    G_IMG_W             : integer := 64;
    G_IMG_H             : integer := 64;
    IMG_BRAM_ADDR       : integer := 13;
    IMG_BRAM_WIDTH      : integer := 8;
    PING_PONG_BRAM_ADDR : integer := 13;
    PING_PONG_BRAM_WIDTH: integer := 16
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    start       : in  std_logic;
    done        : out std_logic;

    img_addr    : out unsigned(IMG_BRAM_ADDR-1 downto 0);
    img_din     : out std_logic_vector(IMG_BRAM_WIDTH-1 downto 0);
    img_dout    : in  std_logic_vector(IMG_BRAM_WIDTH-1 downto 0);
    img_we      : out std_logic;

    ping_pong_addr : out unsigned(PING_PONG_BRAM_ADDR-1 downto 0);
    ping_pong_din  : out std_logic_vector(PING_PONG_BRAM_WIDTH-1 downto 0);
    ping_pong_dout : in  std_logic_vector(PING_PONG_BRAM_WIDTH-1 downto 0);
    ping_pong_we   : out std_logic
  );
end entity;

architecture rtl of img_normalize is
  constant C_TOTAL_PIX : integer := G_IMG_W * G_IMG_H;

  type t_state is (S_IDLE, S_READ, S_WAIT1, S_WAIT2, S_COMPUTE, S_WRITE, S_DONE);
  signal state : t_state := S_IDLE;

  signal pix_cnt          : unsigned(IMG_BRAM_ADDR-1 downto 0) := (others => '0');
  signal img_addr_i       : unsigned(IMG_BRAM_ADDR-1 downto 0) := (others => '0');
  signal ping_pong_addr_i : unsigned(PING_PONG_BRAM_ADDR-1 downto 0) := (others => '0');
  signal q_val            : unsigned(15 downto 0) := (others => '0');
begin

  img_addr       <= img_addr_i;
  img_din        <= (others => '0');
  img_we         <= '0';

  ping_pong_addr <= ping_pong_addr_i;
  ping_pong_din  <= std_logic_vector(q_val);

  process(clk)
    variable pix : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state             <= S_IDLE;
        pix_cnt           <= (others => '0');
        img_addr_i        <= (others => '0');
        ping_pong_addr_i  <= (others => '0');
        ping_pong_we      <= '0';
        done              <= '0';
        q_val             <= (others => '0');
      else
        ping_pong_we <= '0';
        done         <= '0';

        case state is
          when S_IDLE =>
            if start = '1' then
              pix_cnt          <= (others => '0');
              img_addr_i       <= (others => '0');
              ping_pong_addr_i <= (others => '0');
              state            <= S_READ;
            end if;

          when S_READ =>
            img_addr_i <= pix_cnt;
            state      <= S_WAIT1;

          when S_WAIT1 =>
            state <= S_WAIT2;

          when S_WAIT2 =>
            state <= S_COMPUTE;

          when S_COMPUTE =>
            pix := unsigned(img_dout);
            q_val <= "000000" & pix & "00";
            state <= S_WRITE;

          when S_WRITE =>
            ping_pong_addr_i <= resize(pix_cnt, PING_PONG_BRAM_ADDR);
            ping_pong_we     <= '1';

            if pix_cnt = to_unsigned(C_TOTAL_PIX - 1, pix_cnt'length) then
              state <= S_DONE;
            else
              pix_cnt <= pix_cnt + 1;
              state   <= S_READ;
            end if;

          when S_DONE =>
            done  <= '1';
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture;