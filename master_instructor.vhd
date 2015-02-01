library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Contains the frame_t type
use work.frame_types.all;
-- Contains the vga_timing type
use work.uas.all;

-- This module is a very simple FFT display for VGA.
-- The flow is:

-- |-------|     |-------|      |-------|      |-------|      |-------|
-- |  ADC  |====>|  FFT  |=====>|  MAG  |=====>|  RAM  |=====>|  VGA  | 
-- |_______|     |_______|      |_______|      |_______|      |_______|

-- Data is sampled directly off of the ADC from the FFT module.  The start of the FFT
-- module is synced up to the VGA blanking periods.  After startup, the FFT module waits
-- until the VGA module is rendering pixels (not in any blanking period) and then the FFT
-- module's start signal is asserted.  This kicks off the FFT sampling, and then
-- calculation.  Once the calculation is complete the FFT module will set its done flag
-- high.  This signal is latched so that it can be held onto until the VGA module is at
-- the bottom blanking period.  This is the longest of the blanking periods.  Which is 
-- the best time for doing costly operations such as unloading the FFT, calculating the 
-- magnitudes, and writing to VGA RAM.  The other reason the blanking period is used is
-- that if the VGA module is reading while the magnitude module is writing, then the data
-- will become corrupt.  Using the blanking period ensures that there is no conflict.
-- Once the writing is complete, the magnitude module releases the write enable signal
-- and then the VGA module picks back up rendering the new frame.  The VGA RAM read 
-- enable signal is only asserted when rendering.  So there are times when both the write
-- and read enable signals are low.

-- The ADC, FFT, MAG, and write side (left) of the RAM are all run off of the FFT clock
-- The read side (right) of the RAM and VGA are run off of the VGA clock

-- There is a DDS sine generator as well.  It is really only there for testing the FFT
-- output.  To use it, just connect the sine output (sine_out) to the ADC input (adc_in).
-- No sampling signal is needed.

-- There is also a UART module that allows a USB to serial converter to be used for
-- configuring various aspects of the module.  Currently only the following things
-- are supported through UART:
--		1. Changing the phase increment of the DDS
--		2. Changing the scaling schedule of the FFT

-- Created by David Protzman for Unallocated Space's (http://www.unallocatedspace.org)
-- FPGA class

entity master_instructor is
		Generic ( 
						  -- Base clock rate (rate of the clk port) that is
							-- used later on to calculate timings later on
							clk_rate : natural := 100_000_000;
							-- Baud rate of the serial UART interface
		          baud_rate : natural := 500_000;
							-- Width of the red port
							vga_colors_red_width : positive := 3;
							-- Width of the green port
							vga_colors_green_width : positive := 3;
							-- Width of the blue port
							vga_colors_blue_width : positive := 2 
					 );
    Port ( 
					 -- input clock
					 clk : in  STD_LOGIC;
		       -- async reset
           rst : in  STD_LOGIC;

					 -- serial RX line (there is no tx in this design)
           rx : in  STD_LOGIC;

					 -- sine wave output for debugging
           sine_out : out  STD_LOGIC_VECTOR (7 downto 0);

					 -- analog to digital converter input
					 adc_in : in STD_LOGIC_VECTOR(7 downto 0);
					 -- adc sampling clock
				   adc_clk : out STD_LOGIC;

					 leds : out STD_LOGIC_VECTOR(7 downto 0);

					 -- vga red output
					 vga_red : out STD_LOGIC_VECTOR(vga_colors_red_width-1 downto 0);
		       -- vga green output
					 vga_green : out STD_LOGIC_VECTOR(vga_colors_green_width-1 downto 0);
		       -- vga blue output
					 vga_blue : out STD_LOGIC_VECTOR(vga_colors_blue_width-1 downto 0);
           -- vga horizontal sync
					 vga_hs : out STD_LOGIC;
		       -- vga vertical sync
					 vga_vs : out STD_LOGIC);
end master_instructor;

architecture Behavioral of master_instructor is

	constant fft_width_elements : integer := 512;
	constant fft_width_bits : integer := 9;
	
	-- Data output of the read side of the VGA RAM
	signal vga_ram_data : std_logic_vector(7 downto 0);
	-- Address input of the read side of the VGA RAM
	signal vga_ram_addr : std_logic_vector(fft_width_bits - 1 downto 0);
	-- Enable for the read side of the VGA RAM
	signal vga_ram_en : std_logic;
	-- Enable for the write side of the VGA RAM
	signal vga_ram_we : std_logic_vector(0 downto 0);
	
	-- RAM that connects the output of the magnitude module to the 
	-- VGA controller module
	COMPONENT vga_ram
		PORT (
			clka : IN STD_LOGIC;
			ena : IN STD_LOGIC;
			wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
			addra : IN STD_LOGIC_VECTOR(fft_width_bits - 1 DOWNTO 0);
			dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			clkb : IN STD_LOGIC;
			enb : IN STD_LOGIC;
			addrb : IN STD_LOGIC_VECTOR(fft_width_bits - 1 DOWNTO 0);
			doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;

	-- Magnitude calculation output valid flag
	signal mag_output_valid : std_logic;
	-- Magnitude calculation output index (used to tell where to put the 
	-- output samples in memory)
	signal mag_idx_out, mag_next_idx_out : std_logic_vector(fft_width_bits - 1 downto 0);
	-- Magnitude output (the actual calculated magnitude)
	signal mag_mag : std_logic_vector(7 downto 0);
	
	-- Computes the magnitude using mag = (re * re) + (im * im)
	-- Sum of squares
	COMPONENT mag
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		input_valid : IN std_logic;
		re : IN std_logic_vector(7 downto 0);
		im : IN std_logic_vector(7 downto 0);
		idx_in : IN std_logic_vector(fft_width_bits - 1 downto 0);          
		idx_out : OUT std_logic_vector(fft_width_bits - 1 downto 0);
		next_idx_out : OUT std_logic_vector(fft_width_bits - 1 downto 0);
		mag : OUT std_logic_vector(7 downto 0);
		output_valid : OUT std_logic
		);
	END COMPONENT;

	-- Red color value to request that the VGA controller display
	signal vga_red_in : std_logic_vector(vga_red'range);
	-- Green color value to request that the VGA controller display
	signal vga_green_in : std_logic_vector(vga_green'range);
	-- Blue color value to request that the VGA controller display
	signal vga_blue_in : std_logic_vector(vga_blue'range);
	-- X and Y positions of the currently rendering pixel
	signal vga_x_pos, vga_y_pos : integer;
	-- Used to tell if the horizontal or vertical blanking periods are active
	signal vga_h_blanking, vga_v_blanking : std_logic;

	-- Module that generates and controls the VGA output
	COMPONENT vga_configurable
		GENERIC (
			-- VGA configuration to use
			config : vga_timing := vga_25mhz_640x480;
			-- Width of the red color signal
			red_width : positive := vga_colors_red_width;
			-- Width of the green color signal
			green_width : positive := vga_colors_green_width;
			-- Width of the blue color signal
			blue_width : positive := vga_colors_blue_width);
		PORT(
			clk : IN std_logic;
			rst : IN std_logic;
			blue_in : IN std_logic_vector(blue_width-1 downto 0);
			red_in : IN std_logic_vector(red_width-1 downto 0);
			green_in : IN std_logic_vector(green_width-1 downto 0);          
			hs : OUT std_logic;
			vs : OUT std_logic;
		  h_blanking : OUT std_logic;
		  v_blanking : OUT std_logic;
			green : OUT std_logic_vector(green_width-1 downto 0);
			red : OUT std_logic_vector(red_width-1 downto 0);
			blue : OUT std_logic_vector(blue_width-1 downto 0);
			x_pos : OUT integer;
			y_pos : OUT integer
			);
	END COMPONENT;

	-- Generated clocks from the DCM
	-- The original_clk signal is just the input clock passed through
	signal original_clk, fft_clk, vga_clk : std_logic;

	-- Generates the VGA and FFT/sampling clocks
	COMPONENT dcm
		PORT
		 (
			input_clk : IN STD_LOGIC;
			original_clk : OUT STD_LOGIC;
			fft_clk : OUT STD_LOGIC;
			vga_clk : OUT STD_LOGIC
		 );
	END COMPONENT;

	-- The real and imaginary values going into, and out of the FFT module
	signal fft_xk_re, fft_xk_im, fft_xn_im, fft_xn_re : std_logic_vector(7 downto 0);
	-- Signals to control flags for the FFT module
	signal fft_ce, fft_unload, fft_start, fft_rfd, fft_busy, fft_edone, fft_done, fft_dv, fft_ovflo, fft_scale_we : std_logic;
	-- Used to tell what index (position) the input/output values are for
	signal fft_xk_index, fft_xn_index : std_logic_vector(fft_width_bits - 1 downto 0);
	-- Used to scale the FFT values internally
	signal fft_scale : std_logic_vector((fft_width_bits * 2) - 1 downto 0) := "010101010101010110";

	-- Computes the FFT of the input data from the ADC
	COMPONENT fft
		PORT (
			clk : IN STD_LOGIC;
			ce : IN STD_LOGIC;
			start : IN STD_LOGIC;
			xn_re : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			xn_im : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			fwd_inv : IN STD_LOGIC;
			fwd_inv_we : IN STD_LOGIC;
			scale_sch : IN STD_LOGIC_VECTOR((fft_width_bits * 2) - 1 DOWNTO 0);
			scale_sch_we : IN STD_LOGIC;
		  --blk_exp : OUT STD_LOGIC_VECTOR(4 downto 0);
			rfd : OUT STD_LOGIC;
			xn_index : OUT STD_LOGIC_VECTOR(fft_width_bits - 1 DOWNTO 0);
			busy : OUT STD_LOGIC;
			edone : OUT STD_LOGIC;
			done : OUT STD_LOGIC;
			dv : OUT STD_LOGIC;
			xk_index : OUT STD_LOGIC_VECTOR(fft_width_bits - 1 DOWNTO 0);
			xk_re : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			xk_im : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			ovflo : OUT STD_LOGIC;
			sclr : IN STD_LOGIC;
			unload : IN STD_LOGIC
		);
	END COMPONENT;

	-- Holds the most recent valid frame from the UART module
	signal frame : frame_t;
	-- Used to tell when the frame signal is valid
	-- Pulses once
	signal frame_valid : std_logic;

	-- UART RX module for configuring various signals in this module
	COMPONENT uart_comms
	GENERIC(
		-- Input clock rate in Hz
		clk_rate : natural := clk_rate;
		-- Input baud rate in CPS/Hz
		baud_rate : natural := baud_rate
	);
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		rx : IN std_logic;          
		frame : OUT frame_t;
		frame_valid : OUT std_logic
		);
	END COMPONENT;

	-- Phase increment value for the DDS (sine generator)
	signal pinc_in : std_logic_vector(15 downto 0);

	-- Sine generator.  Used mainly for debugging the FFT output
	COMPONENT sine_gen
	  PORT (
		 clk : IN STD_LOGIC;
		 pinc_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 sine : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	  );
	END COMPONENT;

	signal avg_ram_we : std_logic_vector(0 downto 0);
	signal avg_ram_din, avg_ram_dout : std_logic_vector(7 downto 0);
	signal avg_ram_addr : std_logic_vector(fft_width_bits - 1 downto 0);
	COMPONENT avg_ram
		PORT (
			clka : in STD_LOGIC;
			rsta : in STD_LOGIC;
			wea : in STD_LOGIC_VECTOR(0 downto 0);
			dina : in STD_LOGIC_VECTOR(7 downto 0);
			addra : in STD_LOGIC_VECTOR(fft_width_bits - 1 downto 0);
			douta : out STD_LOGIC_VECTOR(7 downto 0)
		);
	END COMPONENT;

	signal decimate_out, decimate_in : std_logic_vector(7 downto 0);
	signal decimate_rate : std_logic_vector(3 downto 0);
	signal decimate_we : std_logic;
	COMPONENT decimate
		PORT (
			din : in std_logic_vector(7 downto 0);
			rate : in std_logic_vector(3 downto 0);
			rate_we : in std_logic;
			clk : in std_logic;
			sclr : in std_logic;
			dout : out std_logic_vector(7 downto 0);
			rfd : out std_logic;
			rdy : out std_logic
		);
	END COMPONENT;

	signal avg_out : std_logic_vector(7 downto 0);
	signal avg_idx : std_logic_vector(fft_width_bits - 1 downto 0);
	signal avg_valid : std_logic;
	COMPONENT averaging
		PORT(
			clk : IN std_logic;
			rst : IN std_logic;
			a : IN std_logic_vector(7 downto 0);
			mag_in : IN std_logic_vector(7 downto 0);
			mag_idx : IN std_logic_vector(fft_width_bits - 1 downto 0);
			mag_valid : IN std_logic;          
			avg_out : OUT std_logic_vector(7 downto 0);
			avg_idx : OUT std_logic_vector(fft_width_bits - 1 downto 0);
			avg_valid : OUT std_logic
			);
	END COMPONENT;

	-- Needed to store the output from the DDS sine generator so that
	-- its output can be converted from signed to unsigned
	signal sine_buffer : std_logic_vector(sine_out'range);

	-- Used to tell if the FFT module is waiting to write out its data to the VGA RAM
	signal fft_waiting_to_write : std_logic;

	-- Keeps track of the previous values of the horizontal and vertical blanking signals
	-- output from the VGA module
	signal last_vga_h_blanking, last_vga_v_blanking : std_logic;

	signal max_clock_counter_value : integer := 0;
	signal clock_counter_value : integer := 0;
	signal real_fft_clk : std_logic;
	signal adc_offset : unsigned(7 downto 0);

	
	type avg_storage_t is array(0 to fft_width_elements - 1) of std_logic_vector(15 downto 0);
	signal avg_storage : avg_storage_t;
	signal avg : unsigned(15 downto 0);
	signal avg_val : std_logic_vector(7 downto 0);
begin

	leds <= decimate_rate & "0000";

	Inst_averaging: averaging PORT MAP(
		clk => real_fft_clk,
		rst => rst,
		a => avg_val,
		mag_in => mag_mag,
		mag_idx => mag_idx_out,
		mag_valid => mag_output_valid,
		avg_out => avg_out,
		avg_idx => avg_idx,
		avg_valid => avg_valid
	);


	decimate_inst : decimate
		PORT MAP (
			clk => fft_clk,
			din => decimate_in,
			dout => decimate_out,
			rate => decimate_rate,
			rate_we => decimate_we,
			sclr => rst,
			rfd => open,
			rdy => open
		);

	-- The ADC and FFT clocks are the same
	adc_clk <= fft_clk;

	-- Makes sure that the write side of the VGA RAM is only written to when the 
	-- output_valid flag of the magnitude calculator is high
	vga_ram_we <= (others => mag_output_valid);

	-- Always set the FFT scale write enable to high.  This makes it so that any
	-- change is applied immediately
	fft_scale_we <= '1';
		
	process(fft_clk, rst)
	begin
		if(rst = '1') then
			clock_counter_value <= 0;
			real_fft_clk <= '0';
		elsif(rising_edge(fft_clk)) then
			decimate_in <= std_logic_vector(unsigned(adc_in) + adc_offset);
			clock_counter_value <= clock_counter_value + 1;

			if(clock_counter_value >= max_clock_counter_value) then
				clock_counter_value <= 0;
				real_fft_clk <= not real_fft_clk;
			end if;
		end if;
	end process;

	-- This process controls the rendering of the FFT output to the VGA monitor
	-- There will be a rectangle at the top left corder of the screen that has the
	-- FFT magnitude outputs
	process(vga_clk, rst)
		--variable avg : unsigned(15 downto 0);
		--type avg_storage_t is array(0 to 511) of std_logic_vector(7 downto 0);
		--variable avg_storage : avg_storage_t;
	begin
		if(rst = '1') then
			-- Reset all of the colors
			vga_red_in <= (others => '0');
			vga_green_in <= (others => '0');
			vga_blue_in <= (others => '0');
			avg <= (others => '0');
			avg_storage <= (others => (others => '0'));
		elsif(rising_edge(vga_clk)) then
			-- Default the blue color to off
			vga_blue_in <= (others => '0');

			-- Default the read side enable for the VGA RAM to off
			vga_ram_en <= '0';

			-- Only worry about rendering when the VGA module is actually drawing
			if(vga_v_blanking = '0' and vga_h_blanking = '0') then
				-- Because the read side address of the VGA RAM is one cycle behind, use 514
				-- instead of 512.  The Y position is at most 255
				if(vga_x_pos > -1 and vga_y_pos > -1 and vga_x_pos < fft_width_elements / 2 and vga_y_pos < 256) then
					-- Rendering is required, so enable the read side of the VGA RAM
					vga_ram_en <= '1';

					-- In order to get data out of the read side of the VGA RAM, the address
					-- needs to be set.  Here the address is the previous X position so that
					-- everything is zero based like it should be
					vga_ram_addr <= std_logic_vector(to_unsigned(vga_x_pos - 1, fft_width_bits));
					
					--if(vga_y_pos = 1) then
						--avg <= (avg_val * unsigned(vga_ram_data)) + ((256-avg_val) * unsigned(avg_storage(vga_x_pos)));
						--avg_storage(vga_x_pos) <=  std_logic_vector((avg_val * unsigned(vga_ram_data)) + ((256-avg_val) * unsigned(avg_storage(vga_x_pos))));
						--avg_storage(vga_x_pos) <= std_logic_vector(avg(15 downto 8));
					--end if;
					-- The 255 minus part is so that the blue lines are rendered from the bottom
					-- of the rectangular window.  So long as the current position in memory is less
					-- than or equal to the current Y position, render the color blue.  This will make
					-- the blue line.  Just using equals to instead of less than or equal to will plot
					-- dots on the screen
					--if(255 - unsigned(avg_storage(vga_x_pos)(15 downto 8)) <= to_unsigned(vga_y_pos, 8)) then
					if(255 - unsigned(vga_ram_data) <= to_unsigned(vga_y_pos, 8)) then
						-- Turn on all of the blue bits
						vga_blue_in <= (others => '1');
					end if;
				end if;
			end if;
		end if;
	end process;

	-- This process controls the FFT block.  It handles starting the block and unloading
	-- data to the magnitude calculator
	process(real_fft_clk, rst)
	begin
		if(rst = '1') then
			-- Reset all of the signals touched by this process
			fft_waiting_to_write <= '0';
			last_vga_v_blanking <= '0';
			last_vga_h_blanking <= '0';
			fft_start <= '0';
			fft_unload <= '0';
			fft_ce <= '1';
		elsif(rising_edge(real_fft_clk)) then
			-- Turn off the unload signal by default.  It will be overridden later
			fft_unload <= '0';
			-- Turn off the start signal by default.  It will be overridden later
			fft_start <= '0';

			-- Save the last values of the horizontal and vertical blanking flags.  This
			-- is required to make the fake 'rising_edge' check for both
			last_vga_v_blanking <= vga_v_blanking;
			last_vga_h_blanking <= vga_h_blanking;

			-- When the fft_done signal goes high, that means that the FFT module is ready
			-- to unload the data from the most recent calculation.  Latch that signal with the
			-- fft_waiting_to_write signal so that when the horizontal and vertical blanking period
			-- comes, we can know to start outputting data from the FFT module.
			if(fft_done = '1') then
				fft_waiting_to_write <= '1';
			end if;

			-- When there is data to unload from the FFT and the horizontal and vertical blanking flags
			-- just changed from '0' to '1', then that means it's time to start unloading data.  With both
			-- the flags going from '0' to '1', we know that the longest blanking period has started (it's the
			-- one at the very bottom of the screen that lasts for multiple horizontal lines) which gives
			-- plenty of time for the FFT module to unload and the magnitude module to calculate and store
			-- the magnitudes
			if(fft_waiting_to_write = '1' and last_vga_v_blanking = '0' and vga_v_blanking = '1' and last_vga_h_blanking = '0' and vga_h_blanking = '1') then
				-- Turn off the waiting_to_write signal since the unloading is starting now
				fft_waiting_to_write <= '0';
				-- The fft_unload signal only needs to be active for one clock cycle
				fft_unload <= '1';
			end if;

			-- The FFT module will only start processing when the fft_start flag is set to '1'.  All other
			-- times the FFT module is just sitting and waiting.  When the FFT is not currently being started,
			-- not currently preparing to read input data, not currently calculating data, not currently done
			-- processing (or one cycle away from being done - fft_edone), there is no data in the FFT that
			-- is pending being output, and both the horizontal and vertical blanking periods are off (pixels
			-- are being drawn), then start up the FFT so that it will read in new data and run it's calculations
			if(fft_start = '0' and fft_rfd = '0' and fft_busy = '0' and fft_done = '0' and fft_edone = '0' and fft_waiting_to_write = '0' and vga_v_blanking = '0' and vga_h_blanking = '0') then
				fft_start <= '1';
			end if;
		end if;
	end process;
	
	-- Handles converting the DDS sine wave output from signed to unsigned
	process(fft_clk, rst)
	begin
		if(rst = '1') then
			-- Reset the sine output to the center value of 0x80 (should be ~ 1.65 volts)
			sine_out <= x"80";
		elsif(rising_edge(real_fft_clk)) then
			-- Modify the sine_buffer value (which is directly from the DDS module) by adding
			-- 128 which makes the sign fall off
			sine_out <= std_logic_vector(unsigned(sine_buffer) + 128);
		end if;
	end process;
	
	-- Handles the UART data that has come in
	process(original_clk, rst)
		variable last_decimate_we : std_logic := '0';
		variable decimate_countdown : unsigned(31 downto 0);
	begin
		if(rst = '1') then
			last_decimate_we := '0';
			-- Default the phase increment to be 0x00FF (arbitrarily chosen)
			pinc_in <= x"00FF";
			-- Default the fft scaling to shift one bit for each stage except the last
			-- which is shifted twice
			fft_scale <= "010101010101010110";

			max_clock_counter_value <= 0;
			avg_val <= std_logic_vector(to_unsigned(64, 8));
			adc_offset <= (others => '0');
			decimate_rate <= "0100";
			decimate_we <= '1';
			last_decimate_we := '0';
			decimate_countdown := to_unsigned(100, decimate_countdown'length);
		elsif(rising_edge(original_clk)) then
			if(decimate_countdown = 0) then
				decimate_we <= '0';
			else
				decimate_countdown := decimate_countdown - 1;
			end if;

			-- Make sure that the frame is valid
			-- This signal is only active for one tick of original_clk, so there
			-- is no danger of sampling it twice
			if(frame_valid = '1') then
				-- Switch statement to makes things a little cleaner
				case frame(3) is
					-- 0x00 means that the command was to change the phase increment
					when x"00" =>
						pinc_in <= frame(4) & frame(5);

					-- 0x01 means that the command was to change the FFT internal scaling
					when x"01" =>
						-- To keep things simple, the last two bits (which have different constraints)
						-- are just set to "10" and the other 16 bits are whatever is sent in the frame
						fft_scale <= frame(4) & frame(5) & "10";
					when x"02" =>
						max_clock_counter_value <= to_integer(unsigned(frame(4)) & unsigned(frame(5)) & unsigned(frame(6)) & unsigned(frame(7)));
					when x"03" =>
						avg_val <= frame(4);
					when x"04" =>
						adc_offset <= unsigned(frame(4));
					when x"05" =>
						decimate_rate <= frame(4)(3 downto 0);
						decimate_we <= '1';
						decimate_countdown := to_unsigned(100, decimate_countdown'length);
					when others =>
						-- Gotta make sure to have an others!
						null;
				end case;
			end if;
		end if;
	end process;


	-- Instance of the VGA RAM that sits between the magnitude calculator and
	-- the VGA controller module
	vga_ram_inst : vga_ram
		PORT MAP (
			-- The write clock is synchronized to the FFT clock
			clka => real_fft_clk,
			-- Only write to the VGA RAM when the magnitude output_valid flag is high
			-- This means that the mag_mag signal contains legit data.  This also helps
			-- make sure that there are not collisions between the read and write side 
			-- of the VGA RAM
			ena => avg_valid,
			-- Only allow writes to the VGA RAM when the VGA process sets vga_ram_we to high
			wea => vga_ram_we,
			-- This is the write address which is controlled by the magnitude calculator
			addra => avg_idx,
			-- This is the write data which is also controlled by the magnitude calculator
			dina => avg_out,
			-- The read side of the VGA RAM is controlled by the VGA processes and module,
			-- so it needs to be synchronized to the VGA clock
			clkb => vga_clk,
			-- Enabling of the read side of the VGA RAM is controlled here (the vga_ram_en signal
			-- is driven by the VGA process above)
			enb => vga_ram_en,
			-- This is the read address and is controlled by the VGA process above
			addrb => vga_ram_addr,
			-- This is the output of the read side and is used by the VGA process above
			doutb => vga_ram_data
		);

	-- Instance of the magnitude calculator.  This module takes data from the FFT module
	-- and runs the calculation: (im * im) + (re * re)
	-- which is also know as the sum of squares (pythagorean theorem)
	-- THIS MODULE IS PIPELINED!!!
	mag_inst : mag PORT MAP(
		-- This module is fed directly from the FFT module, so it needs to run
		-- off of the same clock
		clk => real_fft_clk,
		-- Active high async reset
		rst => rst,
		-- Since this module is pipelined, it's important that the pipeline know 
		-- when the output is actually valid and not just garbage
		input_valid => fft_dv,
		-- Real input from the FFT module
		re => fft_xk_re,
		-- Imaginary input from the FFT module
		im => fft_xk_im,
		-- Index (bin/memory location) of the current sample.  Needed to know
		-- where the sample goes when it gets to the end of the pipeline
		idx_in => fft_xk_index,
		-- Index/bin of the currently available magnitude value
		idx_out => mag_idx_out,

		next_idx_out => mag_next_idx_out,
		-- Currently available magnitude value
		mag => mag_mag,
		-- Flag used to tell if the output (mag and idx_out) are actually valid,
		-- or if it's just garbage being flushed out of the pipeline
		output_valid => mag_output_valid
	);

	-- VGA controller instance
	vga_inst : vga_configurable PORT MAP(
		-- The base clock (should be the pixel clock for the specified resolution)
		clk => vga_clk,
		-- Async active high reset
		rst => rst,
		-- Horizontal sync.  Should be routed directly out
		hs => vga_hs,
		-- Vertical sync.  Should be routed directly out
		vs => vga_vs,
		-- Green color output.  Should be routed directly out
		green => vga_green,
		-- Red color output.  Should be routed directly out
		red => vga_red,
		-- Blue color output.  Should be routed directly out
		blue => vga_blue,
		-- Used to tell if the horizontal blanking period is active
		h_blanking => vga_h_blanking,
		-- Used to tell if the vertical blanking period is active
		v_blanking => vga_v_blanking,
		-- Used to keep track of the current X position that is being
		-- rendered (will be -1 if there is blanking happening)
		x_pos => vga_x_pos,
		-- Used to keep track of the current Y position that is being
		-- rendered (will be -1 if there is blanking happening)
		y_pos => vga_y_pos,
		-- Value of the blue color that should be displayed.  Will be
		-- ignored during blanking periods
		blue_in => vga_blue_in,
		-- Value of the red color that should be displayed.  Will be
		-- ignored during blanking periods
		red_in => vga_red_in,
		-- Value of the green color that should be displayed.  Will be
		-- ignored during blanking periods
		green_in => vga_green_in
	);

	-- Creates a sine wave to test with.  Mainly used as a loopback to test
	-- the FFT output
	sine_gen_inst : sine_gen
	  PORT MAP (
		 -- Runs off of the fft clock since there is no need to generate a
		 -- sine wave that is faster than the FFT sampling rate (it should be
		 -- half the sampling rate to satisfy the nyquist rate)
		 clk => original_clk,
		 -- Amount that the phase should be incremented per clock.  This directly
		 -- controls the frequency of the output sine wave
		 pinc_in => pinc_in,
		 -- The output sine wave is full range, but is centered around zero.  That
		 -- means that the output is signed which is no good for testing.  Store
		 -- the signed output in sine_buffer so that it can be converted later
		 sine => sine_buffer
	  );
	
	-- Handles the UART commands
	Inst_uart_comms: uart_comms
		PORT MAP(
			-- Needs to run at the base clock
			clk => original_clk,
			-- Async active high reset
			rst => rst,
			-- Serial RX line (should be directly routed out of the FPGA)
			rx => rx,
			-- Frame of data that was last received
			frame => frame,
			-- Goes high for one clock cycle when a new (and valid) frame is received)
			frame_valid => frame_valid
		);

	-- Digital Clock Manager (DCM) that generates the required clocks
	dcm_inst : dcm
		PORT MAP (
			-- Input clock (clk can no longer be used anywhere else!!!)
			input_clk => clk,
			-- Copy of the input clock so that clk can be used elsewhere
			original_clk => original_clk,
			-- Clock that will drive the FFT, sampling, magnitude, and write
			-- side of the VGA RAM
			fft_clk => fft_clk,
			-- Clock that will drive the VGA module and the read side of
			-- the VGA RAM
			vga_clk => vga_clk
		);

	-- Instance of the Xilinx FFT module
	fft_inst : fft
		PORT MAP (
			-- FFT clock
			clk => real_fft_clk,
			-- Chip enable
			ce => fft_ce,
			-- Signals the core to start sampling and then calculating
			start => fft_start,
			-- Real input
			xn_re => decimate_in,
			-- Imaginary input.  Set to zeros since the ADC does not provide
			-- imaginary values
			xn_im => (others => '0'),
			-- Tied to '1' so that only a forward FFT is done
			fwd_inv => '1',
			-- Tied to '1' so that the value of fwd_inv is applied
			fwd_inv_we => '1',
			-- Controls how many bits are shifted at each stage of the FFT calculation
			scale_sch => fft_scale,
			-- Applies changes to the scale_sch input
			scale_sch_we => fft_scale_we,
			--blk_exp => leds(4 downto 0),
			-- Ready for data signal.  Used to notify other modules that the FFT core is ready
			-- to receive data from the ADC
			rfd => fft_rfd,
			-- Shows which index is currently being read.  Nothing needs this.
			xn_index => open,
			-- Shows that the FFT module is busy calculating
			busy => fft_busy,
			-- A warning that on the next clock cycle, the FFT will be complete
			edone => fft_edone,
			-- Shows that the FFT is complete
			done => fft_done,
			-- Shows that the FFT module is now unloading the calculated data
			dv => fft_dv,
			-- Index/bin of the current output data
			xk_index => fft_xk_index,
			-- Real output value
			xk_re => fft_xk_re,
			-- Imaginary output value
			xk_im => fft_xk_im,
			-- Shows that there was an overflow during the calculation.  This going high
			-- means that the scaling needs to be modified
			ovflo => fft_ovflo,
			-- Synchronous reset signal.  Tied to the async reset signal...  This could be bad...
			sclr => rst,
			-- Used to tell the FFT module to start unloading the calculated data
			unload => fft_unload
		);

end Behavioral;
