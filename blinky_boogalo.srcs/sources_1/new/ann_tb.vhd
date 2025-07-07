library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ann_tb is
end entity;

architecture Behavioral of ann_tb is

  constant CLK_PERIOD : time := 10 ns;

  signal clk           : std_logic := '0';
  signal rst           : std_logic := '1';
  signal start         : std_logic := '0';
  signal done          : std_logic;

  signal in_addr       : unsigned(12 downto 0);
  signal in_rd_data    : std_logic_vector(15 downto 0);

  signal final_class   : unsigned(3 downto 0);

  type input_mem is array(0 to 8191) of std_logic_vector(15 downto 0);
  signal input_bram : input_mem := (others => x"0001");  -- All inputs 0001 in Q1.14 format

begin

  DUT: entity work.ann
    port map (
      clk         => clk,
      rst         => rst,
      start       => start,
      done        => done,
      in_addr     => in_addr,
      in_rd_data  => in_rd_data,
      final_class => final_class
    );

  -- Clock generation
  clk_proc: process
  begin
    clk <= '0'; wait for CLK_PERIOD/2;
    clk <= '1'; wait for CLK_PERIOD/2;
  end process;

  -- Simulation process
  stim_proc: process
  begin
    -- Reset sequence
    rst <= '1';
    wait for 50 ns;
    rst <= '0';
    wait for 50 ns;

    -- Start the ANN
    start <= '1';
    wait for CLK_PERIOD;
    start <= '0';

    -- Wait until done
    wait until done = '1';
    wait for CLK_PERIOD;

    -- Report the final classification
    report "Final classification output: " & integer'image(to_integer(final_class));

    wait;
  end process;

  -- Simulated BRAM read
  in_rd_data <= input_bram(to_integer(in_addr));

end Behavioral;