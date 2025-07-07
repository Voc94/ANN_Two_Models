library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mad_unit is
    generic (
        INPUT_BITWIDTH : integer := 15  -- Q1.14 (16 bits)
    );
    port (
        clk         : in  std_logic;
        rstn        : in  std_logic;
        en          : in  std_logic;
        img_val     : in  std_logic_vector(INPUT_BITWIDTH downto 0);
        weight_val  : in  std_logic_vector(INPUT_BITWIDTH downto 0);
        bias        : in  std_logic_vector(INPUT_BITWIDTH downto 0);
        out_val     : out std_logic_vector(INPUT_BITWIDTH downto 0);
        done        : out std_logic
    );
end entity;

architecture rtl of mad_unit is

    signal result_q14 : signed(INPUT_BITWIDTH downto 0) := (others => '0');
    signal done_int   : std_logic := '0';

begin

    process(clk)
        variable img_s     : signed(INPUT_BITWIDTH downto 0);
        variable weight_s  : signed(INPUT_BITWIDTH downto 0);
        variable bias_s    : signed(INPUT_BITWIDTH downto 0);
        variable product   : signed((INPUT_BITWIDTH*2)+1 downto 0);
        variable result    : signed(INPUT_BITWIDTH downto 0);
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                result_q14 <= (others => '0');
                done_int   <= '0';

            elsif en = '1' then
                -- Convert inputs
                img_s    := signed(img_val);
                weight_s := signed(weight_val);
                bias_s   := signed(bias);

                -- Multiply (Q1.14 x Q1.14 = Q2.28)
                product := resize(img_s * weight_s, product'length);

                -- Truncate back to Q1.14 by shifting right 14 bits (logical right shift)
                result := resize(product(product'high downto 14), result'length);

                -- Add bias (same Q1.14 format)
                result := result + bias_s;

                result_q14 <= result;
                done_int   <= '1';
            else
                done_int <= '0';
            end if;
        end if;
    end process;

    out_val <= std_logic_vector(result_q14);
    done    <= done_int;

end rtl;
