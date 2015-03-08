-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;

use work.mypack.all;
use work.myentities.all;

entity tute2_tb is  end entity;
architecture testbench of tute2_tb is
	signal success, done, error : std_ulogic := '0';
	signal reset_n, clk : std_ulogic := '0';
	signal counter : integer := 0;
	signal memctl : MEM_CTL;
	signal memres : MEM_RES;
	signal resXorAnd : u8;
begin
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
	test: entity work.tute2 port map(
		clk_clk => clk, clk_reset_n => reset_n,
		memctl => memctl ,
		memres => memres ,
		resXorAnd => resXorAnd 
	);
	process begin
		wait until rising_edge(clk);

		case counter is -- write values
			when 13 => 
				memctl.act <= '1';
				memctl.write <= '1';
				memctl.wdata <= X"50";
			when 14 => 
				memctl.act <= '0';
				memctl.write <= '0';
				memctl.wdata <= X"00";
			when 15 => 
				memctl.act <= '1';
				memctl.write <= '0';
				memctl.wdata <= X"00";
			when 16 => 
				memctl.act <= '1';
				memctl.write <= '0';
				memctl.wdata <= X"00";
			when 17 => 
				memctl.act <= '0';
				memctl.write <= '0';
				memctl.wdata <= X"00";
			when 18 => 
				memctl.act <= '1';
				memctl.write <= '1';
				memctl.wdata <= X"90";
			when 19 => 
				memctl.act <= '0';
				memctl.write <= '0';
				memctl.wdata <= X"00";
			when others => null;
		end case;

	end process;
end;
