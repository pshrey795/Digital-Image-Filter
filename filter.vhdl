--Pre-defined modules

--Module for RAM
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity RAM_64Kx8 is
	port (
		clock : in std_logic;
		read_enable, write_enable : in std_logic; 			-- signals that enable read/write operation
		address : in std_logic_vector(15 downto 0); 		-- 2^16 = 64K
		data_in : in std_logic_vector(7 downto 0);			-- Data to be written on RAM
		data_out : out std_logic_vector(7 downto 0)			-- Data which is read from RAM
		);
end RAM_64Kx8;


architecture Artix of RAM_64Kx8 is
	
	type Memory_type is array (0 to 65535) of std_logic_vector (7 downto 0);
	signal Memory_array : Memory_type;	--Memory Array, which is indexed by pixel address, stores the pixel value (0 to 255) of the particular pixel
	
	begin

		process (clock) begin
			
			if rising_edge (clock) then
				
				if (read_enable = '1') then 										-- the data read is available after the clock edge
					data_out <= Memory_array (to_integer (unsigned (address)));
				end if;
				
				if (write_enable = '1') then 										-- the data is written on the clock edge
					Memory_array (to_integer (unsigned(address))) <= data_in;
				end if;
			
			end if;

		end process;

end Artix;




--Module for ROM
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity ROM_32x9 is
	port (
		clock : in std_logic;
		read_enable : in std_logic; 									-- signal that enables read operation
		address : in std_logic_vector(4 downto 0); 						-- 2^5 = 32
		data_out : out std_logic_vector(8 downto 0)						-- Data to be read from ROM
	);
end ROM_32x9;


architecture Artix of ROM_32x9 is
	
	type Memory_type is array (0 to 31) of std_logic_vector (8 downto 0);
	signal Memory_array : Memory_type;					--Memory Array in ROM stores the scaled up 9 bit values of the co-efficient matrices
	
	begin

		process (clock) begin

			if rising_edge (clock) then
				
				if (read_enable = '1') then 										-- the data read is available after the clock edge
					data_out <= Memory_array (to_integer (unsigned (address)));
				end if;

			end if;

		end process;

end Artix;




--Module for multiplier-accumulator
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity MAC is
	port (
		clock : in std_logic;
		control : in std_logic; 												-- ‘0’ for initializing the sum
		data_in1, data_in2 : in std_logic_vector(17 downto 0);					-- Input values from RAM and ROM respectively
		data_out : out std_logic_vector(17 downto 0)							-- Current value of the accumulator to be returned
	);
end MAC;


architecture Artix of MAC is
		
	signal sum, product : signed (17 downto 0);									-- Accumulator and Partial Product respectively

	begin

		data_out <= std_logic_vector (sum);
		product <= signed (data_in1) * signed (data_in2);

		process (clock) begin

			if rising_edge (clock) then 										-- sum is available after clock edge

				if (control = '0') then											-- initialize the sum with the first product
					sum <= (product);
				else 															-- add product to the previous sum
					sum <= (product + signed (sum));
				end if;
--Note that there was an error in the provided code for lines 118 and 120. The signal 'sum' shouldn't be typecasted to std_logic_vector.

			end if;

		end process;

end Artix;




--Actual Design starts here
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity image_filter is
	port(
		clock: in std_logic;						--Master clock
		button: in std_logic;						--Push button input, which when pressed, starts the filter operation on image present in RAM
		switch: in std_logic						--Toggle switch, which decides the mode of filter operation, smoothening or sharpening
		);
end image_filter;


architecture design of image_filter is


	--Component declarations for pre-defined modules i.e. RAM, ROM and MAC

	--RAM
	component RAM_64Kx8 is
		port (
			clock : in std_logic;
			read_enable, write_enable : in std_logic;
			address : in std_logic_vector(15 downto 0);
			data_in : in std_logic_vector(7 downto 0);
			data_out : out std_logic_vector(7 downto 0)
		);
	end component RAM_64Kx8;

	--ROM
	component ROM_32x9 is
		port (
			clock : in std_logic;
			read_enable : in std_logic;
			address : in std_logic_vector(4 downto 0);
			data_out : out std_logic_vector(8 downto 0)
		);
	end component ROM_32x9;

	--MAC i.e. Multiplier Accumulator
	component MAC is
		port (
			clock : in std_logic;
			control : in std_logic; 
			data_in1, data_in2 : in std_logic_vector(17 downto 0);
			data_out : out std_logic_vector(17 downto 0)
		);
	end component MAC;


	--Dimensions of QQVPGA pixel array
	constant NumberOfCols : std_logic_vector(15 downto 0) := x"0078";  --Column Size = 120 pixels
	constant NumberOfRows : std_logic_vector(15 downto 0) := x"00A0";  --Row Size = 160 pixels


	--To enable filtering process
	signal process_enable: std_logic := '0';


	--Current type of filtering
	type mode_type is (smooth_filter, sharp_filter);
	signal mode: mode_type := smooth_filter;


	--Reset
	signal reset: std_logic := '0';


	--Read/Write enablers. These enablers decide whether to read or/and write to RAM and ROM
	signal read: std_logic := '1';
	signal write: std_logic := '0';


	--Counter to store number of clock cycles
	signal counter: std_logic_vector(3 downto 0) := (others => '0'); 		
	--Note that this counter is also useful in indexing the co-efficient matrix


	--Registers
	--Note that all the memory addresses in RAM and ROM are maintained in a row wise manner, which means that the numbering is of the form:
	--   0   1   2   3   4   5 ........... 119
	--   120 121 122 ......                                    So, there are 120 columns and 160 rows
 
	signal addr_X: std_logic_vector(15 downto 0) := (others => '0'); 		
	--Register which stores the memory address of the current pixel in original image 
	
	signal addr_Y: std_logic_vector(15 downto 0) := "0000000001111001";
 	--Counter which stores the memory address of the current pixel in filtered image
 	--Note that it is initialised with the value 121 which refers to the pixel corresponding to the 

	signal X: std_logic_vector(7 downto 0) := (others => '0'); 
    --Register which stores the pixel value of the current pixel of original image
	
	signal Y: std_logic_vector(17 downto 0) := (others => '0');
	--Register which stores the pixel value of the current pixel of filtered image 
	
	signal C: std_logic_vector(8 downto 0) := (others => '0');
	--Register which stores the co-efficient value 


	--Indices
	signal I: std_logic_vector(15 downto 0) := "0000000000000001"; 			--Index to store row number of current pixel 
	signal J: std_logic_vector(15 downto 0) := "0000000000000001";  		--Index to store column number of current pixel
	-- I ranges from 1 to NumberOfRows-1 while J ranges from 1 to NumberOfCols-1

	signal a: std_logic_vector(1 downto 0) := "00";							--Relative row index
	signal b: std_logic_vector(1 downto 0) := "00"; 						--Relative column index
 	-- Both a and b range from 0 to 2


	--Data to be passed in MAC
	signal X_input: std_logic_vector(17 downto 0);			--Data read from RAM
	signal C_input: std_logic_vector(17 downto 0);			--Data read from ROM
	signal control: std_logic := '0';						--Control instruction to initialise sum(accumulator) in MAC


	begin

		--Component Instantiations

		--Reading from RAM
		read_write_RAM: entity work.RAM_64Kx8 port map(clock => clock, read_enable => read, write_enable => write, address => addr_X, data_in => '1'&addr_Y(14 downto 0), data_out => X);

		--Reading from ROM
		read_ROM: entity work.ROM_32x9 port map(clock => clock, read_enable => read, address => switch&counter, data_out => C);

		--Product of two 18 bit numbers
		call_MAC: entity work.MAC port map(clock => clock, control => control, data_in1 => X_input, data_in2 => C_input, data_out => Y);

		--Updating X input to MAC
		X_input <= "0000000000"&X;

		--Updating C input to MAC
		C_input <= "000000000"&C when C(8)='0' else "111111111"&C;



		--Synchronous switching process
		switching: process(switch,clock) 
		begin

			if(rising_edge(clock)) then
				if(switch='0') then 
					mode <= smooth_filter;
				else
					mode <= sharp_filter;
				end if;
			end if;

		end process;
		

		--Synchronous resetting of filter process
		resetting: process(reset,clock) 
		begin

		--Resetting process is called after every image is successfully filtered so that the system is ready to receive new image as input
			if(rising_edge(clock)) then
				if(reset='1') then 

					--All internal signals are re-initialised whenever reset is called
					process_enable <= '0';
					counter <= "0000";
					I <= "0000000000000001";
					J <= "0000000000000001";
					a <= "00";
					b <= "00";
					read <= '1';
					write <= '0';
					Y <= (others => '0');
					addr_Y <= "0000000001111001";
					reset <= '0';

				end if;
			end if;

		end process;


		--Synchronous enabling of filter process
		enabling: process(button, clock)
		begin

			if(rising_edge(clock)) then

			--Calling rising edge on push button can detect changes in button value from 0 to 1 but it is an inefficient way due to 
			--debouncing, and so a better method would be to maintain an FSM which stores previous values(about as old as 5-6 clock cycles)
			--of push button, and whenever there is a visible difference in the values of both these variables i.e. new value = 1 and old
			--value = 0, the we can conclude that the button was pressed. But rising edge would do for our needs and purposes.
				if(rising_edge(button)) then 
					process_enable <= '1';
				end if;
			end if;

		end process;



		--Main process
		main_process: process(process_enable, clock)
		begin

			--If push button has been pressed
			if(process_enable) then
				if(rising_edge(clock)) then

				--Here maintaining the following four cases is crucial due to the fact that the there is a delay of one clock cycle
				--between updation of memory address values (addr_X and counter) and obtaining the value stored in RAM/ROM corresponding
				--to that address, and an additional delay of one clock cycle between obtaining these values and using them to update the 
				--value of the accumulator(sum). So, a net delay of two clock cycles is seen. So, the accumulator takes two additional 
				--clock cycles beyond 9 cycles i.e. a total of 11 cycles to obtain final value of the product while the memory addresses
				--are updated only during the first 9 cycles. These operations need to be dealt separately.

					--When counter=9, we stop reading more values, as we have already obtained 9 matrix values each from RAM and ROM
					if(counter = "1001") then 

						counter <= counter + 1;
						read <= '0';

					--When counter=10, we set the control of MAC to 0 so that the accumulator is initiased for next pixel
					elsif(counter = "1010") then 

						counter <= counter + 1;
						control <= '0';

					--When counter=11, we finally write the obtained value of the accumulator to RAM and reinitialise the counter/register
					--values for next pixel
					elsif(counter = "1011") then

						write <= '1';
						counter <= "0000";

						--Updating the memory address and the corresponding indices in the filtered image to process the next pixel
						J <= J + 1;
						addr_Y <= addr_Y + 1;

						if(J = NumberOfCols - 1) then 
							if(I = NumberOfRows - 1) then 
								reset <= '1';
							else
								I <= I + 1;
								J <= "0000000000000001";
								addr_Y <= addr_Y + "0000000000000010";
							end if;
						end if;



					else 
						
						--Initially, we only read data from RAM and ROM and write data on RAM only after the current pixel value has been
						--calculated after precisely 9 cycles(maintained by counter), and so till then read is enabled and write is disabled
						if(counter = "0000") then 
							read <= '1';
							write <= '0';
						end if;

						--Updating memory address of the pixel in X i.e. original image
						if(b = "01") then
							addr_X <= addr_X + 1;
						elsif (b = "10") then
							addr_X <= addr_X + 1;
						else
							
							addr_X <= addr_Y - 1;

							if(a = "00") then 
								addr_X <= addr_X - NumberOfCols;
							elsif(a = "10") then 
								addr_X <= addr_X + NumberOfCols;
							end if;

						end if;

						--Updating local indices
						if(b = "10") then
							a <= a + 1;
							b <= "00";
						else
							b <= b + 1;
						end if;

						--Updating counter
						counter <= counter + 1; 

					end if;
				end if;
			end if;			

		end process;	

end design;

