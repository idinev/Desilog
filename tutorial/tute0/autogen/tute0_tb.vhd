-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity tute0_tb is  end entity;
architecture testbench of tute0_tb is
	signal success, done, error : std_ulogic := '0';
	signal reset_n, clk : std_ulogic := '0';
	signal counter : integer := 0;
	signal xx : u8;
	signal yy : u8;
	signal someUnused : u8;
	signal sum : u8;
	signal totalSum : u8;
	signal outXorWire : u8;
	signal outLatch : u8;
begin
	process(clk, reset_n) begin
		someUnused <= X"77";
	end process;
	success <= done and (not error);
	process begin
		clk <= '0';  wait for 5 ps;
		clk <= '1';  wait for 5 ps;
	end process;
	process begin
		wait until rising_edge(clk);
		counter <= counter + 1;
		if counter >= 10 then
			reset_n <= '1';
		end if;
	end process;
	test: entity work.tute0 port map(
		clk_clk => clk, clk_reset_n => reset_n,
		xx => xx ,
		yy => yy ,
		someUnused => someUnused ,
		sum => sum ,
		totalSum => totalSum ,
		outXorWire => outXorWire ,
		outLatch => outLatch 
	);
	process begin
		wait until rising_edge(clk);

		case counter is -- write values
			when 15 => 
				xx <= X"03";
				yy <= X"04";
			when 16 => 
				xx <= X"55";
				yy <= X"11";
			when 17 => 
				xx <= X"01";
				yy <= X"01";
			when others => null;
		end case;

		case counter is -- read+verify values
			when 17 => 
				if sum /= X"07" then
					error <= '1';
				end if;
				if totalSum /= X"07" then
					error <= '1';
				end if;
			when 18 => 
				if sum /= X"66" then
					error <= '1';
				end if;
				if totalSum /= X"6D" then
					error <= '1';
				end if;
			when 19 => 
				if sum /= X"02" then
					error <= '1';
				end if;
				if totalSum /= X"6F" then
					error <= '1';
				end if;
			when 25 =>  done <= '1'; 
				if error='0' then
				report "---------[ TESTBENCH SUCCESS ]---------------";
				else
				report "---------[ !!! TESTBENCH FAILURE !!! ]---------------";
				end if;
			when others => null;
		end case;
	end process;
end;

