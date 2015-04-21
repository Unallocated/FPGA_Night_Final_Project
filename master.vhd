library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.frame_types.all;

entity master is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           rx : in  STD_LOGIC;
           sine_out : out  STD_LOGIC_VECTOR (7 downto 0);
			  adc_in : in STD_LOGIC_VECTOR(7 downto 0);
			  adc_clk : out STD_LOGIC;
			  vga_hs : out STD_LOGIC;
			  vga_vs : out STD_LOGIC;
			  vga_red : out STD_LOGIC_VECTOR(2 downto 0);
			  vga_green : out STD_LOGIC_VECTOR(2 downto 0);
			  vga_blue : out STD_LOGIC_VECTOR(1 downto 0));
end master;

architecture Behavioral of master is

	signal last_vga_v_blanking, vga_h_blanking, vga_v_blanking : std_logic;
	signal vga_red_in, vga_green_in : std_logic_vector(2 downto 0);
	signal vga_blue_in : std_logic_vector(1 downto 0);
	signal vga_x_pos, vga_y_pos : integer;
	
	COMPONENT vga_configurable
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		blue_in : IN std_logic_vector(1 downto 0);
		red_in : IN std_logic_vector(2 downto 0);
		green_in : IN std_logic_vector(2 downto 0);          
		hs : OUT std_logic;
		vs : OUT std_logic;
		green : OUT std_logic_vector(2 downto 0);
		red : OUT std_logic_vector(2 downto 0);
		blue : OUT std_logic_vector(1 downto 0);
		v_blanking : OUT std_logic;
		h_blanking : OUT std_logic;
		x_pos : OUT integer;
		y_pos : OUT integer
		);
	END COMPONENT;

	signal vga_ram_class_enb : std_logic;
	signal vga_ram_class_addrb : std_logic_vector(8 downto 0);
	signal vga_ram_class_doutb : std_logic_vector(7 downto 0);
	COMPONENT vga_ram_class
	  PORT (
		 clka : IN STD_LOGIC;
		 ena : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 clkb : IN STD_LOGIC;
		 enb : IN STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	  );
	END COMPONENT;

	signal mag_output_valid : std_logic;
	signal mag_mag : std_logic_vector(7 downto 0);
	signal mag_idx_out : std_logic_vector(8 downto 0);
	COMPONENT mag
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		input_valid : IN std_logic;
		re : IN std_logic_vector(7 downto 0);
		im : IN std_logic_vector(7 downto 0);
		idx_in : IN std_logic_vector(8 downto 0);          
		idx_out : OUT std_logic_vector(8 downto 0);
		mag : OUT std_logic_vector(7 downto 0);
		output_valid : OUT std_logic
		);
	END COMPONENT;

	signal fft_clk, original_clk, vga_clk : std_logic;
	component dcm_class
		port
		 (
		  clk : in std_logic;
		  fft_clk : out std_logic;
		  vga_clk : out std_logic;
		  original_clk : out std_logic
		 );
		end component;

	signal fft_xk_re, fft_xk_im : std_logic_vector(7 downto 0);
	signal fft_xk_index, fft_xn_index : std_logic_vector(8 downto 0);
	signal fft_dv, fft_ce, fft_start, fft_done, fft_unload, fft_rfd, fft_busy, fft_ovflo : std_logic;
	signal fft_scale_sch : std_logic_vector(17 downto 0);
	signal fft_waiting_to_write : std_logic;
	COMPONENT fft_class
	  PORT (
		 clk : IN STD_LOGIC;
		 ce : IN STD_LOGIC;
		 sclr : IN STD_LOGIC;
		 start : IN STD_LOGIC;
		 unload : IN STD_LOGIC;
		 xn_re : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 xn_im : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 fwd_inv : IN STD_LOGIC;
		 fwd_inv_we : IN STD_LOGIC;
		 scale_sch : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
		 scale_sch_we : IN STD_LOGIC;
		 rfd : OUT STD_LOGIC;
		 xn_index : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
		 busy : OUT STD_LOGIC;
		 edone : OUT STD_LOGIC;
		 done : OUT STD_LOGIC;
		 dv : OUT STD_LOGIC;
		 xk_index : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
		 xk_re : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		 xk_im : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		 ovflo : OUT STD_LOGIC
	  );
	END COMPONENT;

	signal frame : frame_t := (others => (others => '0'));
	signal frame_valid : std_logic := '0';
	COMPONENT uart_comms
	GENERIC(
		clk_rate : natural := 100_000_000;
		baud_rate : natural := 500_000
	);
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		rx : IN std_logic;          
		frame : OUT frame_t;
		frame_valid : OUT std_logic
		);
	END COMPONENT;

	signal pinc_in : std_logic_vector(15 downto 0);
	COMPONENT sine_gen
	  PORT (
		 clk : IN STD_LOGIC;
		 pinc_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 sine : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	  );
	END COMPONENT;
	
	signal avg_avg : std_logic_vector(7 downto 0);
	signal avg_idx : std_logic_vector(8 downto 0);
	signal avg_dv : std_logic;
	signal weight_in : std_logic_vector(7 downto 0);
	COMPONENT avg
	PORT(
		rst : IN std_logic;
		clk : IN std_logic;
		a : IN std_logic_vector(7 downto 0);
		mag_mag : IN std_logic_vector(7 downto 0);
		mag_idx : IN std_logic_vector(8 downto 0);
		mag_dv : IN std_logic;          
		avg : OUT std_logic_vector(7 downto 0);
		idx : OUT std_logic_vector(8 downto 0);
		dv : OUT std_logic
		);
	END COMPONENT;

	signal adc_offset : std_logic_vector(adc_in'range);
	--signal adc_adjusted : std_logic_vector(adc_in'range);
	signal fft_input, selected_input : std_logic_vector(adc_in'range);
	signal sine_buffer : std_logic_vector(sine_out'range) := (others => '0');
	signal adc_selected : std_logic;
	signal adjusted_fft_clk : std_logic;
	signal adjusted_fft_clk_counter, adjusted_fft_clk_counter_max : integer;
begin

	selected_input <= adc_in when adc_selected = '1' else sine_buffer;

	adc_clk <= adjusted_fft_clk;
	
	process(fft_clk, rst)
	begin
		if(rst = '1') then
			adjusted_fft_clk_counter <= 0;
			adjusted_fft_clk <= '0';
		elsif(rising_edge(fft_clk)) then
			adjusted_fft_clk_counter <= adjusted_fft_clk_counter + 1;
			if(adjusted_fft_clk_counter >= adjusted_fft_clk_counter_max) then
				adjusted_fft_clk <= not adjusted_fft_clk;
				adjusted_fft_clk_counter <= 0;
			end if;
		end if;
	end process;
	
	process(vga_clk, rst)
	begin
		if(rst = '1') then
			vga_blue_in <= (others => '0');
		elsif(rising_edge(vga_clk)) then
			vga_ram_class_enb <= '0';
		
			if(vga_x_pos >= 0 and vga_x_pos < 512 
					and vga_y_pos >= 0 and vga_y_pos < 256) then
				vga_ram_class_enb <= '1';
				vga_ram_class_addrb <= 
					std_logic_vector(to_unsigned(vga_x_pos, vga_ram_class_addrb'length));
				
				if(255 - unsigned(vga_ram_class_doutb) <= vga_y_pos) then
					vga_blue_in <= (others => '1');
				else
					vga_blue_in <= (others => '0');
				end if;
			else
				vga_blue_in <= (others => '0');
			end if;
		end if;
	end process;
	
	process(adjusted_fft_clk, rst)
	begin
		if(rst = '1') then
			fft_start <= '0';
		elsif(rising_edge(adjusted_fft_clk)) then
			fft_start <= '0';
			fft_unload <= '0';
			last_vga_v_blanking <= vga_v_blanking;
			
			if(fft_done = '1') then
				fft_waiting_to_write <= '1';
			end if;
			
			if(last_vga_v_blanking = '0' and vga_v_blanking = '1' 
					and fft_waiting_to_write = '1') then
				fft_unload <= '1';
				fft_waiting_to_write <= '0';
			end if;
			
			if(fft_rfd = '0' and fft_start = '0' and fft_busy = '0' 
				and fft_done = '0' and fft_dv = '0' and fft_unload = '0'
				and vga_v_blanking = '0' and fft_waiting_to_write = '0') then
					
					fft_start <= '1';
			end if;
		end if;
	end process;
	
	process(adjusted_fft_clk, rst)
	begin
		if(rst = '1') then
			sine_out <= x"80";
			fft_input <= (others => '0');
		elsif(rising_edge(adjusted_fft_clk)) then
			sine_out <= std_logic_vector(unsigned(sine_buffer) + 128);
			fft_input <= std_logic_vector(unsigned(selected_input) + unsigned(adc_offset));
		end if;
	end process;
	
	process(original_clk, rst)
	begin
		if(rst = '1') then
			pinc_in <= x"00FF";
			weight_in <= (others => '1');
			fft_scale_sch <= "010101010101010101";
			adc_offset <= (others => '0');
			adc_selected <= '0';
			adjusted_fft_clk_counter_max <= 0;
		elsif(rising_edge(original_clk)) then
			if(frame_valid = '1') then
				case frame(3) is
					when x"00" =>
						pinc_in <= frame(4) & frame(5);
					when x"01" =>
						weight_in <= frame(4);
					when x"02" =>
						fft_scale_sch <= frame(4)(1 downto 0) & frame(5) & frame(6);
					when x"03" =>
						adc_offset <= frame(4);
					when x"04" =>
						adc_selected <= frame(4)(0);
					when x"05" =>
						adjusted_fft_clk_counter_max <= to_integer(unsigned(frame(4)));
					when others  =>
						null;
				end case;
			end if;
		end if;
	end process;

	sine_gen_inst : sine_gen
	  PORT MAP (
		 clk => fft_clk,
		 pinc_in => pinc_in,
		 sine => sine_buffer
	  );
	  
	Inst_uart_comms: uart_comms PORT MAP(
		clk => original_clk,
		rst => rst,
		rx => rx,
		frame => frame,
		frame_valid => frame_valid
	);
	
	fft_class_inst : fft_class
	  PORT MAP (
		 clk => adjusted_fft_clk,
		 ce => '1',
		 sclr => rst,
		 start => fft_start,
		 unload => fft_unload,
		 xn_re => fft_input,
		 xn_im => (others => '0'),
		 fwd_inv => '1',
		 fwd_inv_we => '1',
		 scale_sch => fft_scale_sch,
		 scale_sch_we => '1',
		 rfd => fft_rfd,
		 xn_index => open,
		 busy => fft_busy,
		 edone => open,
		 done => fft_done,
		 dv => fft_dv,
		 xk_index => fft_xk_index,
		 xk_re => fft_xk_re,
		 xk_im => fft_xk_im,
		 ovflo => fft_ovflo
	  );
	  
	  dcm_class_inst : dcm_class
		  port map
			( clk => clk,
			  fft_clk => fft_clk,
			  vga_clk => vga_clk,
			  original_clk => original_clk);
	 
	 Inst_mag: mag PORT MAP(
		clk => adjusted_fft_clk,
		rst => rst,
		input_valid => fft_dv,
		re => fft_xk_re,
		im => fft_xk_im,
		idx_in => fft_xk_index,
		idx_out => mag_idx_out,
		mag => mag_mag,
		output_valid => mag_output_valid
	);
	
	vga_ram_inst : vga_ram_class
	  PORT MAP (
		 clka => adjusted_fft_clk,
		 ena => avg_dv,
		 wea => (others => avg_dv),
		 addra => avg_idx,
		 dina => avg_avg,
		 clkb => vga_clk,
		 enb => vga_ram_class_enb,
		 addrb => vga_ram_class_addrb,
		 doutb => vga_ram_class_doutb
	  );
	  
	Inst_vga_configurable: vga_configurable PORT MAP(
		clk => vga_clk,
		rst => rst,
		hs => vga_hs,
		vs => vga_vs,
		green => vga_green,
		red => vga_red,
		blue => vga_blue,
		v_blanking => vga_v_blanking,
		h_blanking => vga_h_blanking,
		x_pos => vga_x_pos,
		y_pos => vga_y_pos,
		blue_in => vga_blue_in,
		red_in => vga_red_in,
		green_in => vga_green_in
	);
	
	avg_inst : avg PORT MAP(
		rst => rst,
		clk => adjusted_fft_clk,
		a => weight_in,
		mag_mag => mag_mag,
		mag_idx => mag_idx_out,
		mag_dv => mag_output_valid,
		avg => avg_avg,
		idx => avg_idx,
		dv => avg_dv
	);

end Behavioral;


