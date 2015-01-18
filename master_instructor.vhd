library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.frame_types.all;

entity master_instructor is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           rx : in  STD_LOGIC;
           sine_out : out  STD_LOGIC_VECTOR (7 downto 0));
end master_instructor;

architecture Behavioral of master_instructor is

	signal frame : frame_t := (others => (others => '0'));
	signal frame_valid : std_logic := '0';
	COMPONENT uart_comms
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

	signal sine_buffer : std_logic_vector(sine_out'range) := (others => '0');

begin
	
	process(clk, rst)
	begin
		if(rst = '1') then
			sine_out <= x"80";
		elsif(rising_edge(clk)) then
			sine_out <= std_logic_vector(unsigned(sine_buffer) + 128);
		end if;
	end process;
	
	process(clk, rst)
	begin
		if(rst = '1') then
			pinc_in <= x"00FF";
		elsif(rising_edge(clk)) then
			if(frame_valid = '1') then
				case frame(3) is
					when x"00" =>
						pinc_in <= frame(4) & frame(5);
					when others  =>
						null;
				end case;
			end if;
		end if;
	end process;

	sine_gen_inst : sine_gen
	  PORT MAP (
		 clk => clk,
		 pinc_in => pinc_in,
		 sine => sine_buffer
	  );
	  
	Inst_uart_comms: uart_comms PORT MAP(
		clk => clk,
		rst => rst,
		rx => rx,
		frame => frame,
		frame_valid => frame_valid
	);

end Behavioral;



