-- uart_pkg.vhd (optional, for shared types/constants)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
package uart_pkg is
  constant UART_DATA_BITS : integer := 8;
end package;
