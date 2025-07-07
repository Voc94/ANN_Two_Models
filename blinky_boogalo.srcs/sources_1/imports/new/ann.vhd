library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cnn_cfg_pkg.all;

entity ann is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    start       : in  std_logic;
    done        : out std_logic;
    in_addr     : out unsigned(12 downto 0);
    in_rd_data  : in  std_logic_vector(15 downto 0);
    final_class : out unsigned(3 downto 0)
  );
end entity;

architecture Behavioral of ann is
  type state_t is (
    IDLE, L1_LOAD, L1_ACCUM, 
    L2_INIT, L2_MAC, OUTPUT_RESULT, FINISHED
  );
  signal state : state_t := IDLE;

  signal pix_cnt       : unsigned(12 downto 0) := (others => '0');
  signal neuron_idx    : integer range 0 to 63 := 0;  -- extended to 64 neurons
  signal in_addr_i     : unsigned(12 downto 0) := (others => '0');
  signal w_addr_i      : unsigned(17 downto 0) := (others => '0');  -- 18 bits for 64 * 4096
  signal accum_sum     : signed(31 downto 0)   := (others => '0');

  type signed_array_64 is array(0 to 63) of signed(31 downto 0);
  signal L1_out : signed_array_64 := (others => (others => '0'));

  type signed_array_10 is array(0 to 9) of signed(31 downto 0);
  signal L2_out : signed_array_10 := (others => (others => '0'));

  signal final_class_i : unsigned(3 downto 0) := (others => '0');
  signal mac_result    : std_logic_vector(15 downto 0);
  signal w_rd_data     : std_logic_vector(15 downto 0);
  signal bias_rd_data  : std_logic_vector(15 downto 0);
  signal wea_sig       : std_logic_vector(0 downto 0) := "0";

  -- L2 computation signals
  signal l2_n     : integer range 0 to 9 := 0;
  signal l2_j     : integer range 0 to 63 := 0;  -- extended to 64 inputs
  signal l2_acc   : signed(47 downto 0) := (others => '0');  -- Expanded to 48-bit
begin

  in_addr     <= in_addr_i;
  final_class <= final_class_i;

  mad_inst : entity work.mad_unit
    generic map (INPUT_BITWIDTH => 15)
    port map (
      clk        => clk,
      rstn       => not rst,
      en         => '1',
      img_val    => in_rd_data,
      weight_val => w_rd_data,
      bias       => (others => '0'),
      out_val    => mac_result,
      done       => open
    );

  weight_bram_inst : entity work.blk_mem_gen_1
    port map (
      clka  => clk,
      ena   => '1',
      wea   => wea_sig,
      addra => std_logic_vector(w_addr_i),
      dina  => (others => '0'),
      douta => w_rd_data
    );

  bias_bram_inst : entity work.blk_mem_gen_2
    port map (
      clka  => clk,
      ena   => '1',
      wea   => wea_sig,
      addra => std_logic_vector(to_unsigned(neuron_idx, 6)),  -- 6 bits for 64 neurons
      dina  => (others => '0'),
      douta => bias_rd_data
    );

  process(clk, rst)
    variable best_i   : integer;
    variable best_val : signed(31 downto 0);
    variable temp_sum : signed(31 downto 0);
  begin
    if rst = '1' then
      state         <= IDLE;
      done          <= '0';
      pix_cnt       <= (others => '0');
      neuron_idx    <= 0;
      accum_sum     <= (others => '0');
      final_class_i <= (others => '0');
      l2_n          <= 0;
      l2_j          <= 0;
      l2_acc        <= (others => '0');
      L1_out        <= (others => (others => '0'));
      L2_out        <= (others => (others => '0'));

    elsif rising_edge(clk) then
      case state is
        when IDLE =>
          done <= '0';
          if start = '1' then
            pix_cnt    <= (others => '0');
            neuron_idx <= 0;
            accum_sum  <= (others => '0');
            state      <= L1_LOAD;
          end if;

        when L1_LOAD =>
          in_addr_i <= pix_cnt;
          w_addr_i  <= to_unsigned(neuron_idx * 4096 + to_integer(pix_cnt), 18);  -- now 18 bits
          state     <= L1_ACCUM;

        when L1_ACCUM =>
          if pix_cnt = 0 then
            accum_sum <= resize(signed(bias_rd_data), 32) + resize(signed(mac_result), 32);
          else
            accum_sum <= accum_sum + resize(signed(mac_result), 32);
          end if;

          if pix_cnt = 4095 then
            if accum_sum < 0 then
              L1_out(neuron_idx) <= (others => '0');
            else
              L1_out(neuron_idx) <= accum_sum;
            end if;

            accum_sum <= (others => '0');
            pix_cnt   <= (others => '0');

            if neuron_idx = 63 then  -- last neuron
              neuron_idx <= 0;
              state      <= L2_INIT;
            else
              neuron_idx <= neuron_idx + 1;
              state      <= L1_LOAD;
            end if;
          else
            pix_cnt <= pix_cnt + 1;
            state   <= L1_LOAD;
          end if;

        when L2_INIT =>
          l2_n   <= 0;
          l2_j   <= 0;
          l2_acc <= resize(signed(L2_biases(0)), 48);
          state  <= L2_MAC;

        when L2_MAC =>
          l2_acc <= resize(l2_acc + resize(L1_out(l2_j), 48) * resize(signed(L2_weights(l2_n, l2_j)), 48), 48);

          if l2_j = 63 then
            L2_out(l2_n) <= resize(l2_acc, 32);
            l2_acc       <= (others => '0');

            if l2_n = 9 then
              state <= OUTPUT_RESULT;
            else
              l2_n <= l2_n + 1;
              l2_j <= 0;
              l2_acc <= resize(signed(L2_biases(l2_n + 1)), 48);
            end if;
          else
            l2_j <= l2_j + 1;
          end if;

        when OUTPUT_RESULT =>
          best_i   := 0;
          best_val := L2_out(0);
          for n in 1 to 9 loop
            if L2_out(n) > best_val then
              best_val := L2_out(n);
              best_i   := n;
            end if;
          end loop;
          final_class_i <= to_unsigned(best_i, 4);
          state         <= FINISHED;

        when FINISHED =>
          done <= '1';
          state <= IDLE;
      end case;
    end if;
  end process;
end architecture;
