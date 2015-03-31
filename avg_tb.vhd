--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   22:03:42 03/10/2015
-- Design Name:   
-- Module Name:   /home/main/FPGA_Night_Final_Project.old/avg_tb.vhd
-- Project Name:  final_project
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: avg
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY avg_tb IS
END avg_tb;
 
ARCHITECTURE behavior OF avg_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT avg
    PORT(
         rst : IN  std_logic;
         clk : IN  std_logic;
         a : IN  std_logic_vector(7 downto 0);
         mag_mag : IN  std_logic_vector(7 downto 0);
         mag_idx : IN  std_logic_vector(8 downto 0);
         mag_dv : IN  std_logic;
         avg : OUT  std_logic_vector(7 downto 0);
         idx : OUT  std_logic_vector(8 downto 0);
         dv : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal rst : std_logic := '0';
   signal clk : std_logic := '0';
   signal a : std_logic_vector(7 downto 0) := (others => '0');
   signal mag_mag : std_logic_vector(7 downto 0) := (others => '0');
   signal mag_idx : std_logic_vector(8 downto 0) := (others => '0');
   signal mag_dv : std_logic := '0';

 	--Outputs
   signal avg2 : std_logic_vector(7 downto 0);
   signal idx : std_logic_vector(8 downto 0);
   signal dv : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: avg PORT MAP (
          rst => rst,
          clk => clk,
          a => a,
          mag_mag => mag_mag,
          mag_idx => mag_idx,
          mag_dv => mag_dv,
          avg => avg2,
          idx => idx,
          dv => dv
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
      -- hold reset state for 100 ns.
		rst <= '1';
      wait for 100 ns;	
		rst <= '0';
		
      wait for clk_period*10;
		mag_mag <= "10000000";
		mag_idx <= "111110000";
		mag_dv <= '1';
		a <= "10000000";
		
		wait for clk_period;
		
		mag_mag <= "00100000";
		mag_idx <= "000001111";
		mag_dv <= '1';
		a <= "10000000";
		
		wait for clk_period;
		
		mag_mag <= "10000000";
		mag_idx <= "111110000";
		mag_dv <= '1';
		a <= "10000000";
		
		wait for clk_period;
		
		mag_mag <= (others => '0');
		mag_idx <= (others => '0');
		mag_dv <= '0';
      -- insert stimulus here 

      wait;
   end process;

END;
