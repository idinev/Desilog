-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


entity tute3 is port(
	clk_clk, clk_reset_n: in std_ulogic;
	iwrite0:	in std_ulogic; -- reg
	iwdata0:	in u8; -- reg
	iaddr0:	in u8; -- reg
	iaddr1:	in u8; -- reg
	r0:	out u8; -- WIRE
	r1:	out u8 -- WIRE
	);
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


--#------- tute3 ------------------------------------
architecture rtl of tute3 is

	----- internal regs/wires/etc --------
	signal dg_c_iwrite0: std_ulogic;
	signal dg_c_iwdata0: u8;
	signal dg_c_iaddr0: u8;
	signal dg_c_iaddr1: u8;
	signal dg_w_r0: u8;
	signal dg_w_r1: u8;
	---- internal signals for RAM mem -------------
	type mem_arrtype is array (0 to 255) of std_logic_vector(7 downto 0);
	signal mem : mem_arrtype;
	signal mem_addr0_wire: u8;
	signal mem_addr0_reg : u8;
	signal mem_data0: u8;
	signal mem_wdata0: u8;
	signal mem_write0: std_ulogic;
	signal mem_addr1_wire: u8;
	signal mem_addr1_reg : u8;
	signal mem_data1: u8;
	signal mem_wdata1: u8;
	signal mem_write1: std_ulogic;
begin

	main: process (all)
	begin
		dg_w_r0 <= X"00"; -- wire pre-zero-init
		dg_w_r1 <= X"00"; -- wire pre-zero-init
		mem_write0 <= '0';
		mem_addr0_wire <= (others => '0');
		mem_wdata0 <= X"00";
		mem_write1 <= '0';
		mem_addr1_wire <= (others => '0');
		mem_wdata1 <= X"00";
		mem_addr0_wire <= iaddr0;
		mem_write0 <= '1';
		mem_wdata0 <= iwdata0;
		mem_addr1_wire <= iaddr1;
		dg_w_r0 <= mem_data0;
		dg_w_r1 <= mem_data1;
	end process;

	----[ sync clock pump for clk ]------
	process begin
		wait until rising_edge(clk_clk);
	end process;
	--- clock pump for RAM mem port
	process(clk_clk) begin 	if(rising_edge(clk_clk)) then
		if mem_write0='1' then
			mem(to_integer(mem_addr0_wire)) <= std_logic_vector(mem_wdata0);
		end if;
		if mem_write1='1' then
			mem(to_integer(mem_addr1_wire)) <= std_logic_vector(mem_wdata1);
		end if;
		mem_addr0_reg <= mem_addr0_wire;
		mem_addr1_reg <= mem_addr1_wire;
	end if; end process;
	mem_data0 <= unsigned(mem(to_integer(mem_addr0_reg)));
	mem_data1 <= unsigned(mem(to_integer(mem_addr1_reg)));

	------[ output registers/wires/latches ] --------------
	r0 <= dg_w_r0;
	r1 <= dg_w_r1;
end;


