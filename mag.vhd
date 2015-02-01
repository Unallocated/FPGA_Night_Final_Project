library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mag is
  port ( clk : in std_logic;
         rst : in std_logic;
         input_valid : in std_logic;
         re  : in std_logic_vector(7 downto 0);
         im  : in std_logic_vector(7 downto 0);
         idx_in : in std_logic_vector(8 downto 0);
				 next_idx_out : out std_logic_vector(8 downto 0);
         idx_out : out std_logic_vector(8 downto 0);
         mag : out std_logic_vector(7 downto 0);
         output_valid  : out std_logic);
end mag;

architecture behave of mag is
  constant stages : integer := 10;

  type idx_array_t is array(0 to stages-1) of std_logic_vector(idx_in'range);
  signal idx_buffer_array : idx_array_t := (others => (others => '0'));
  type valid_array_t is array(idx_array_t'range) of std_logic;
  signal valid_array : valid_array_t := (others => '0');

  signal re_buffer, im_buffer : std_logic_vector(re'range) := (others => '0');
  signal re_squared, im_squared : std_logic_vector((re'length * 2) - 1 downto 0) := (others => '0');

  signal parts_summed : std_logic_vector(re_squared'high downto 0) := (others => '0');

  COMPONENT mag_sqrt
  PORT (
    x_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    x_out : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    clk : IN STD_LOGIC
  );
  END COMPONENT;

  signal sqrt_in : std_logic_vector(parts_summed'range) := (others => '0');
  signal sqrt_out : std_logic_vector((parts_summed'length / 2) downto 0) := (others => '0');

  type sqrt_delay_t is array(0 to 5) of std_logic_vector(parts_summed'range);
  signal sqrt_delay : sqrt_delay_t := (others => (others => '0'));
begin

  process(clk, rst)
  begin
    if(rst = '1') then
      idx_buffer_array <= (others => (others => '0'));
      re_squared <= (others => '0');
      im_squared <= (others => '0');
      output_valid <= '0';
      parts_summed <= (others => '0');
      re_buffer <= (others => '0');
      im_buffer <= (others => '0');
      valid_array <= (others => '0');
			next_idx_out <= (others => '0');
    elsif(rising_edge(clk)) then
      for i in 0 to stages-2 loop
        idx_buffer_array(i+1) <= idx_buffer_array(i);
        valid_array(i+1) <= valid_array(i);
      end loop;
      idx_buffer_array(0) <= idx_in;      
      valid_array(0) <= input_valid;
 
      re_buffer <= re;
      im_buffer <= im;

      re_squared <= std_logic_vector(signed(re_buffer) * signed(re_buffer));
      im_squared <= std_logic_vector(signed(im_buffer) * signed(im_buffer));
      
      parts_summed <= std_logic_vector(unsigned(re_squared) + unsigned(im_squared));

      sqrt_in <= sqrt_delay(0);

      for i in 0 to sqrt_delay'high - 1 loop
        sqrt_delay(i+1) <= sqrt_delay(i);
      end loop;
      sqrt_delay(0) <= parts_summed;

      output_valid <= valid_array(valid_array'high);
      mag <= sqrt_out(7 downto 0);
      idx_out <= idx_buffer_array(idx_buffer_array'high);
			next_idx_out <= idx_buffer_array(idx_buffer_array'high - 1);
    end if;
  end process;

  your_instance_name : mag_sqrt
  PORT MAP (
    x_in => sqrt_in,
    x_out => sqrt_out,
    clk => clk
  );

end behave;

