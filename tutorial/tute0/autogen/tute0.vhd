-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity tute0 is port(
	clk_clk, clk_reset_n: in std_ulogic;
	xx:	in u8; -- reg
	yy:	in u8; -- reg
	someUnused:	in u8; -- WIRE
	sum:	out u8; -- reg
	totalSum:	out u8; -- reg
	outXorWire:	out u8; -- WIRE
	outLatch:	out u8 -- Latch
	);
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


--#------- tute0 ------------------------------------
architecture rtl of tute0 is
	signal counter: u4;	-- reg

	----- internal regs/wires/etc --------
	signal dg_c_xx: u8;
	signal dg_c_yy: u8;
	signal dg_c_sum: u8;
	signal dg_o_sum: u8;
	signal dg_c_totalSum: u8;
	signal dg_o_totalSum: u8;
	signal dg_w_outXorWire: u8;
	signal dg_l_outLatch: u8;
	signal dg_c_counter: u4;
begin

	dg_comb_proc1: process (all)
	begin
		dg_l_outLatch <= dg_l_outLatch; -- latch preload
		if (dg_boolToBit(xx = X"55") = '1') then
			dg_l_outLatch <= yy;
		end if;
	end process;

	MyProcess: process (all)
		variable varSum: u8;
	begin
		dg_c_sum <= dg_o_sum; -- reg preload
		dg_c_totalSum <= dg_o_totalSum; -- reg preload
		dg_w_outXorWire <= X"00"; -- wire pre-zero-init
		dg_c_counter <= counter; -- reg preload
		varSum := X"00"; -- local-var zero-init
		varSum := (xx + yy);
		dg_c_sum <= varSum;
		dg_c_totalSum <= (dg_o_totalSum + varSum);
		if (dg_boolToBit(counter = X"5") = '1') then
			dg_c_totalSum <= varSum;
		end if;
		dg_w_outXorWire <= (xx xor yy);
		dg_c_counter <= counter + X"1";
	end process;

	----[ sync clock pump for clk ]------
	process begin
		wait until rising_edge(clk_clk);
		dg_o_sum <= dg_c_sum;
		dg_o_totalSum <= dg_c_totalSum;
		counter <= dg_c_counter;
		if clk_reset_n = '0' then
			dg_o_totalSum <= X"00";
			counter <= X"0";
		end if;
	end process;

	------[ output registers/wires/latches ] --------------
	sum <= dg_o_sum;
	totalSum <= dg_o_totalSum;
	outXorWire <= dg_w_outXorWire;
	outLatch <= dg_l_outLatch;
end;


