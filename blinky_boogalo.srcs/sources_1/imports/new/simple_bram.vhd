library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_bram is
  generic (
    DATA_WIDTH : integer := 16;
    ADDR_WIDTH : integer := 15  -- 32K locations
  );
  port (
    clk   : in  std_logic;
    we    : in  std_logic;
    addr  : in  unsigned(ADDR_WIDTH-1 downto 0);
    din   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    dout  : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture Behavioral of simple_bram is
  type ram_t is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram : ram_t := (others => (others => '0'));
  signal dout_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(addr)) <= din;
      end if;
      dout_reg <= ram(to_integer(addr));  -- Read always
    end if;
  end process;

  dout <= dout_reg;

end architecture;
