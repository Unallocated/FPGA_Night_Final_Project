LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY averaging_tb IS
END averaging_tb;
 
ARCHITECTURE behavior OF averaging_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT averaging
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         a : IN  std_logic_vector(7 downto 0);
         mag_in : IN  std_logic_vector(7 downto 0);
         mag_idx : IN  std_logic_vector(8 downto 0);
         mag_valid : IN  std_logic;
         avg_out : OUT  std_logic_vector(7 downto 0);
         avg_idx : OUT  std_logic_vector(8 downto 0);
         avg_valid : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal a : std_logic_vector(7 downto 0) := "00010000";
   signal mag_in : std_logic_vector(7 downto 0) := (others => '0');
   signal mag_idx : std_logic_vector(8 downto 0) := (others => '0');
   signal mag_valid : std_logic := '0';

 	--Outputs
   signal avg_out : std_logic_vector(7 downto 0);
   signal avg_idx : std_logic_vector(8 downto 0);
   signal avg_valid : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: averaging PORT MAP (
          clk => clk,
          rst => rst,
          a => a,
          mag_in => mag_in,
          mag_idx => mag_idx,
          mag_valid => mag_valid,
          avg_out => avg_out,
          avg_idx => avg_idx,
          avg_valid => avg_valid
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
      wait for 100 ns;	
			rst <= '0';

      wait for clk_period*10;
			
			mag_in <= x"ff";
			mag_idx <= "000000000";
			mag_valid <= '1';

			wait for clk_period;

			mag_in <= x"7e";
			mag_idx <= "000000000";
			mag_valid <= '1';



      wait;
   end process;

END;
