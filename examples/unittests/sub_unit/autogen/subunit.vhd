-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity MyAdder is port(
	clkAdd_clk, clkAdd_reset_n: in std_ulogic;
	x:	in u8; -- reg
	y:	in u8; -- reg
	zout:	out u8 -- reg
	);
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity subunit is port(
	clk_clk, clk_reset_n: in std_ulogic;
	oout:	out u8 -- reg
	);
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


--#------- MyAdder ------------------------------------
architecture rtl of MyAdder is

	----- internal regs/wires/etc --------
	signal dg_c_x: u8;
	signal dg_c_y: u8;
	signal dg_c_zout: u8;
	signal dg_o_zout: u8;
begin

	main: process (all)
	begin
		dg_c_zout <= dg_o_zout; -- reg preload
		dg_c_zout <= (x + y);
	end process;

	----[ sync clock pump for clkAdd ]------
	process begin
		wait until rising_edge(clkAdd_clk);
		dg_o_zout <= dg_c_zout;
	end process;

	------[ output registers/wires/latches ] --------------
	zout <= dg_o_zout;
end;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


--#------- subunit ------------------------------------
architecture rtl of subunit is

	----- internal regs/wires/etc --------
	signal dg_c_oout: u8;
	signal dg_o_oout: u8;

	----- unit signals -------------
		signal madd_x : u8;
		signal dg_c_madd_x : u8;
		signal madd_y : u8;
		signal dg_c_madd_y : u8;
		signal madd_zout : u8;
		signal madd_clkAdd_clk, madd_clkAdd_reset_n : std_ulogic;
begin

	main: process (all)
	begin
		dg_c_oout <= dg_o_oout; -- reg preload
		dg_c_madd_x <= madd_x; -- reg preload
		dg_c_madd_y <= madd_y; -- reg preload
		dg_c_madd_x <= X"01";
		dg_c_madd_y <= X"02";
		dg_c_oout <= madd_zout;
	end process;

	-------[ sub-units ]-----------
	madd : entity work.MyAdder port map(
		clkAdd_clk => madd_clkAdd_clk,
		clkAdd_reset_n => madd_clkAdd_reset_n,
		x => madd_x,
		y => madd_y,
		zout => madd_zout
	);

	-------[ links ]----------
	madd_clkAdd_clk <= clk_clk;
	madd_clkAdd_reset_n <= clk_reset_n;

	----[ sync clock pump for clk ]------
	process begin
		wait until rising_edge(clk_clk);
		dg_o_oout <= dg_c_oout;
		madd_x <= dg_c_madd_x;
		madd_y <= dg_c_madd_y;
	end process;

	------[ output registers/wires/latches ] --------------
	oout <= dg_o_oout;
end;



