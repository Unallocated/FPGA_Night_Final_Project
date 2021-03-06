library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity averaging is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           a : in  STD_LOGIC_VECTOR(7 downto 0);
           mag_in : in  STD_LOGIC_VECTOR (7 downto 0);
					 mag_idx : in  STD_LOGIC_VECTOR (8 downto 0);
					 mag_valid : in STD_LOGIC;
           avg_out : out  STD_LOGIC_VECTOR (7 downto 0);
					 avg_idx : out STD_LOGIC_VECTOR(8 downto 0);
           avg_valid : out  STD_LOGIC);
end averaging;

architecture Behavioral of averaging is

	signal ram_wea : std_logic_vector(0 downto 0);
	signal ram_addra, ram_addrb : std_logic_vector(8 downto 0);
	signal ram_dina, ram_doutb : std_logic_vector(7 downto 0);

	COMPONENT avg_ram
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

	signal dv_buffered : std_logic;
	signal mag_in_buffered, previous_mag : std_logic_vector(mag_in'range);
	signal mag_idx_buffered : std_logic_vector(mag_idx'range);

begin

	process(clk, rst)
		variable arith_temp : std_logic_vector(15 downto 0);
	begin
		if(rst = '1') then
			dv_buffered <= '0';
			ram_wea <= (others => '0');
			arith_temp := (others => '0');
		elsif(rising_edge(clk)) then
			mag_idx_buffered <= mag_idx;
			mag_in_buffered <= mag_in;
			dv_buffered <= mag_valid;

			arith_temp := std_logic_vector((unsigned(a) * unsigned(mag_in_buffered)) + (255 - unsigned(a)) * unsigned(previous_mag));

			avg_idx <= mag_idx_buffered;
			avg_out <= arith_temp(15 downto 8);
			avg_valid <= dv_buffered;
			
			ram_wea <= (others => dv_buffered);
			ram_addra <= mag_idx_buffered;
			ram_dina <= arith_temp(15 downto 8);
			
		end if;
	end process;


	avg_ram_inst : avg_ram
		PORT MAP (
			clka => clk,
			wea => ram_wea,
			addra => ram_addra,
			dina => ram_dina,
			clkb => clk,
			addrb => mag_idx,
			doutb => previous_mag
		);

end Behavioral;

