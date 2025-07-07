library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_decoder is
  port (
    digit : in  unsigned(3 downto 0);        
    seg   : out std_logic_vector(7 downto 0);
    an    : out std_logic_vector(7 downto 0) 
  );
end entity;

architecture Behavioral of seven_segment_decoder is
begin
  process(digit)
  begin
  an <= b"0111_1111";
  -- seg(7 downto 0) = g f e d c b a
case digit is
  when "0000" => seg <= x"C0"; -- 0
  when "0001" => seg <= x"F9"; -- 1
  when "0010" => seg <= x"A4"; -- 2
  when "0011" => seg <= x"B0"; -- 3
  when "0100" => seg <= x"99"; -- 4
  when "0101" => seg <= x"92"; -- 5
  when "0110" => seg <= x"82"; -- 6
  when "0111" => seg <= x"F8"; -- 7
  when "1000" => seg <= x"80"; -- 8
  when "1001" => seg <= x"90"; -- 9
  when others => seg <= x"FF"; -- off/blank
end case;


  end process;
end architecture;