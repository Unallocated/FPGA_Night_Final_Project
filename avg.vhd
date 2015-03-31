library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity avg is
    Port ( rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  a : in std_logic_vector(7 downto 0);
           mag_mag : in  STD_LOGIC_VECTOR (7 downto 0);
           mag_idx : in  STD_LOGIC_VECTOR (8 downto 0);
           mag_dv : in  STD_LOGIC;
           avg : out  STD_LOGIC_VECTOR (7 downto 0);
           idx : out  STD_LOGIC_VECTOR (8 downto 0);
           dv : out  STD_LOGIC);
end avg;

architecture Behavioral of avg is

	COMPONENT averaging_memory
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 clkb : IN STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	  );
	END COMPONENT;

	signal mag_input_buffer, mag_input_buffer2 : std_logic_vector(mag_mag'range);
	signal mag_idx_buffer, mag_idx_buffer2 : std_logic_vector(mag_idx'range);
	signal mag_dv_buffer, mag_dv_buffer2 : std_logic;
	
	signal previous_value : std_logic_vector(mag_mag'range);

	signal avg_buffer : std_logic_vector(avg'range);
	signal dv_buffer : std_logic;
	signal idx_buffer : std_logic_vector(idx'range);
begin

	process(clk, rst)
		variable arith_temp : std_logic_vector((mag_mag'length * 2) - 1 downto 0);
	begin
		if(rst = '1') then
		
		elsif(rising_edge(clk)) then
			mag_input_buffer <= mag_mag;
			mag_idx_buffer <= mag_idx;
			mag_dv_buffer <= mag_dv;
			
			mag_input_buffer2 <= mag_input_buffer;
			mag_idx_buffer2 <= mag_idx_buffer;
			mag_dv_buffer2 <= mag_dv_buffer;
			
			arith_temp := std_logic_vector((unsigned(a) * unsigned(mag_input_buffer2)) 
							  + ((unsigned(not a)) * unsigned(previous_value))); 
		
			avg_buffer <= arith_temp(arith_temp'high downto arith_temp'length/2);
			idx_buffer <= mag_idx_buffer2;
			dv_buffer <= mag_dv_buffer2;
			
			avg <= avg_buffer;
			idx <= idx_buffer;
			dv <= dv_buffer;
		end if;
	end process;
	
	avg_ram_inst : averaging_memory
	  PORT MAP (
		 clka => clk,
		 wea => (others => dv_buffer),
		 addra => idx_buffer,
		 dina => avg_buffer,
		 clkb => clk,
		 addrb => mag_idx_buffer,
		 doutb => previous_value
	  );

end Behavioral;

