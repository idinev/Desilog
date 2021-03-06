-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity example0_tb is  end entity;
architecture testbench of example0_tb is
	signal done,error : std_ulogic := '0';
	signal reset_n,clk : std_ulogic := '0';
	signal counter : integer := 0;
	signal doAdd : std_ulogic;
	signal xx : u8;
	signal yy : u8;
	signal zz : u8;
	signal and_result_reg : u8;
	signal xor_result_wire : u8;
	signal or_result_latch : u8;
begin
	process(clk, reset_n) begin
		doAdd <= '1';
	end process;
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
	test: entity work.Example0 port map(
		clk_clk => clk, clk_reset_n => reset_n,
		doAdd => doAdd ,
		xx => xx ,
		yy => yy ,
		zz => zz ,
		and_result_reg => and_result_reg ,
		xor_result_wire => xor_result_wire ,
		or_result_latch => or_result_latch 
	);
	process begin
		wait until rising_edge(clk);

		case counter is -- write values
			when 13 => 
				xx <= X"06";
				yy <= X"0A";
			when 14 => 
				xx <= X"33";
				yy <= X"55";
			when others => null;
		end case;

		case counter is -- read+verify values
			when 15 => 
				if zz /= X"10" then
					error <= '1';
				end if;
				if and_result_reg /= X"02" then
					error <= '1';
				end if;
			when 16 => 
				if zz /= X"88" then
					error <= '1';
				end if;
				if and_result_reg /= X"11" then
					error <= '1';
				end if;
			when 20 =>  done <= '1'; 
				if error='0' then
				report "---------[ TESTBENCH SUCCESS ]---------------";
				else
				report "---------[ !!! TESTBENCH FAILURE !!! ]---------------";
				end if;
			when others => null;
		end case;
	end process;
end;

