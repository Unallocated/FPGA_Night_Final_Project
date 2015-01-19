LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY master_instructor_tb IS
END master_instructor_tb;
 
ARCHITECTURE behavior OF master_instructor_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT master_instructor
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         rx : IN  std_logic;
         sine_out : OUT  std_logic_vector(7 downto 0);
         adc_in : IN  std_logic_vector(7 downto 0);
         adc_clk : OUT  std_logic;
         vga_red : OUT  std_logic_vector(2 downto 0);
         vga_green : OUT  std_logic_vector(2 downto 0);
         vga_blue : OUT  std_logic_vector(1 downto 0);
         vga_hs : OUT  std_logic;
         vga_vs : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal rx : std_logic := '0';
   signal adc_in : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal sine_out : std_logic_vector(7 downto 0);
   signal adc_clk : std_logic;
   signal vga_red : std_logic_vector(2 downto 0);
   signal vga_green : std_logic_vector(2 downto 0);
   signal vga_blue : std_logic_vector(1 downto 0);
   signal vga_hs : std_logic;
   signal vga_vs : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: master_instructor PORT MAP (
          clk => clk,
          rst => rst,
          rx => rx,
          sine_out => sine_out,
          adc_in => sine_out,
          adc_clk => adc_clk,
          vga_red => vga_red,
          vga_green => vga_green,
          vga_blue => vga_blue,
          vga_hs => vga_hs,
          vga_vs => vga_vs
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin		
			rst <= '1';
      -- hold reset state for 100 ns.
      wait for 100 ns;	
			rst <= '0';
      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
