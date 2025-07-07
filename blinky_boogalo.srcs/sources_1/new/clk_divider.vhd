library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clk_divider is
  generic(
    WIDTH : integer := 20  -- 2^24 ~ 96 HZ
  );
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    slow_tick : out std_logic
  );
end entity;

architecture rtl of clk_divider is
  signal cnt : unsigned(WIDTH-1 downto 0) := (others => '0');

  -- define an all-ones constant at the right width
  constant ALL_ONES : unsigned(WIDTH-1 downto 0) := (others => '1');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt       <= (others => '0');
        slow_tick <= '0';
      else
        if cnt = ALL_ONES then
          cnt       <= (others => '0');
          slow_tick <= '1';
        else
          cnt       <= cnt + 1;
          slow_tick <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;

