library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include the config package
library work;
use work.cnn_cfg_pkg.all;

entity image_bram is
  port (
    clk      : in  std_logic;
    -- Write port
    we       : in  std_logic;
    wr_addr  : in  unsigned(ADDR_WIDTH-1 downto 0);
    wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    -- Read port
    rd_addr  : in  unsigned(ADDR_WIDTH-1 downto 0);
    rd_data  : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture RTL of image_bram is
  type ram_type is array(0 to IMG_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram : ram_type := (others => (others => '0'));
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(wr_addr)) <= wr_data;
      end if;
      rd_data <= ram(to_integer(rd_addr));
    end if;
  end process;
end architecture;
