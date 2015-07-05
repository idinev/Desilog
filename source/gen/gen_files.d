module gen.gen_files;



const string gen_files_Desilog_vhd =
`library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package desilog is
subtype  u8 is unsigned( 7 downto 0);
subtype u16 is unsigned(15 downto 0);
subtype u32 is unsigned(31 downto 0);
subtype u64 is unsigned(63 downto 0);
subtype  u2 is unsigned( 1 downto 0);
subtype  u4 is unsigned( 3 downto 0);

type string_ptr is access string;
function str(a : std_ulogic) return string;
function str(a : unsigned) return string;
function str(a : integer) return string; 
function dg_boolToBit(bval : boolean) return std_ulogic;

end package;


package body desilog is
	function dg_boolToBit(bval : boolean) return std_ulogic is	begin
		if bval then
			return '1';
		else
			return '0';
		end if;
	end function;

	function str(a : std_ulogic) return string is
	begin
		if a = '1' then
			return "1";
		elsif a = '0' then
			return "0";
		end if;
		return "X";
	end function;

	function str(a : unsigned) return string is
		variable res : string_ptr;
	-- pragma translate_off
		variable c : character;
		variable len,j : integer;
		variable dd : unsigned(3 downto 0);
	-- pragma translate_on
	begin
	-- pragma translate_off
		len := (a'length+3)/4;
		res := new string(1 to len);
		
		for i in 1 to len loop
			j := (len - i)*4;
			if (j+3 < a'length) then
				dd := a(j+3+a'right downto j+a'right);
			else
				dd := "0000";
				dd(a'left-j downto 0) := a(a'left downto j);
			end if;
			case dd is
				when X"0" => c := '0';	when X"1" => c := '1';	when X"2" => c := '2';	when X"3" => c := '3';
				when X"4" => c := '4';	when X"5" => c := '5';	when X"6" => c := '6';	when X"7" => c := '7';
				when X"8" => c := '8';	when X"9" => c := '9';	when X"A" => c := 'A';	when X"B" => c := 'B';
				when X"C" => c := 'C';	when X"D" => c := 'D';	when X"E" => c := 'E';	when X"F" => c := 'F';
				when others => c := 'X';
			end case;
			res.all(i) := c;
		end loop;
		return res.all;
		-- pragma translate_on
		
		return "stupid xilinx ise";
		
		
	end function;
	
	function str(a : integer) return string is
	begin
		return str(to_unsigned(a,32));
	end function;

end;


`;

const string gen_files_Desilog_altera_vhd =
	`-- Abstraction layer for Altera 


-- =============== RAM 1-port sync-out ==============================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dg_sys_ram_mono_sync is 
	generic (
		ADDR_BITS : natural := 8;
		DATA_BITS : natural := 32
	);
	port (
		clk0, write0	: in std_ulogic;
		addr0		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata0	: in  unsigned((DATA_BITS-1) downto 0);
		rdata0	: out unsigned((DATA_BITS-1) downto 0)
	);
	
end entity;

architecture rtl of dg_sys_ram_mono_sync is
	signal vec_rdata0	: std_logic_vector((DATA_BITS-1) downto 0);
begin
	rdata0 <= unsigned(vec_rdata0);
	
	xmem : component altsyncram 
		generic map(
			operation_mode => "SINGLE_PORT",
			widthad_a => ADDR_BITS,
			width_a => DATA_BITS,
			outdata_reg_a => "CLOCK0"
		)
		port map(
			clock0 => clk0,
			wren_a => write0,
			address_a => std_logic_vector(addr0),
			data_a => std_logic_vector(wdata0),
			q_a => vec_rdata0
		);
end architecture;


-- =============== RAM 2-port sync-out ==============================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dg_sys_ram_dual_sync is 
	generic (
		ADDR_BITS : natural := 8;
		DATA_BITS : natural := 32
	);
	port (
		clk0, write0	: in std_ulogic;
		addr0		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata0	: in  unsigned((DATA_BITS-1) downto 0);
		rdata0	: out unsigned((DATA_BITS-1) downto 0);
		
		clk1, write1	: in std_ulogic;
		addr1		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata1	: in  unsigned((DATA_BITS-1) downto 0);
		rdata1	: out unsigned((DATA_BITS-1) downto 0)
	);
	
end entity;

architecture rtl of dg_sys_ram_dual_sync is
	signal vec_rdata0, vec_rdata1	: std_logic_vector((DATA_BITS-1) downto 0);
begin
	rdata0 <= unsigned(vec_rdata0);
	rdata1 <= unsigned(vec_rdata1);
	
	xmem : component altsyncram 
		generic map(
			operation_mode => "BIDIR_DUAL_PORT",
			widthad_a => ADDR_BITS,
			widthad_b => ADDR_BITS,
			width_a => DATA_BITS,
			width_b => DATA_BITS,
			outdata_reg_a => "CLOCK0",
			outdata_reg_b => "CLOCK1"
		)
		port map(
			clock0 => clk0,
			clock1 => clk1,
			wren_a => write0,
			wren_b => write1,
			address_a => std_logic_vector(addr0),
			address_b => std_logic_vector(addr1),
			data_a => std_logic_vector(wdata0),
			data_b => std_logic_vector(wdata1),
			q_a => vec_rdata0,
			q_b => vec_rdata1
		);
end architecture;

`;


const string gen_files_Desilog_generic_vhd =
	`-- Abstraction layer for generic/Xilinx

-- =============== RAM 1-port sync-out ==============================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;

entity dg_sys_ram_mono_sync is 
	generic (
		ADDR_BITS : natural := 8;
		DATA_BITS : natural := 32
	);
	port (
		clk0, write0	: in std_ulogic;
		addr0		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata0	: in  unsigned((DATA_BITS-1) downto 0);
		rdata0	: out unsigned((DATA_BITS-1) downto 0)
	);
	
end entity;

architecture rtl of dg_sys_ram_mono_sync is
	type memtype is array (0 to 2**ADDR_BITS - 1) of unsigned(DATA_BITS-1 downto 0);
	shared variable mem : memtype;	
	
	signal reg_write0 : std_ulogic;
	signal reg_addr0  : unsigned((ADDR_BITS-1) downto 0);
	signal reg_wdata0 : unsigned((DATA_BITS-1) downto 0);
begin
	onclk0: process begin
		wait until rising_edge(clk0);
		reg_write0 <= write0;
		reg_addr0  <= addr0;
		reg_wdata0 <= wdata0;
		
		if reg_write0 = '1' then
			mem(to_integer(reg_addr0)) := reg_wdata0;
		end if;
		rdata0 <= mem(to_integer(reg_addr0));
	end process;
end architecture;



-- =============== RAM 2-port sync-out ==============================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;

entity dg_sys_ram_dual_sync is 
	generic (
		ADDR_BITS : natural := 8;
		DATA_BITS : natural := 32
	);
	port (
		clk0, write0	: in std_ulogic;
		addr0		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata0	: in  unsigned((DATA_BITS-1) downto 0);
		rdata0	: out unsigned((DATA_BITS-1) downto 0);
		
		clk1, write1	: in std_ulogic;
		addr1		: in  unsigned((ADDR_BITS-1) downto 0);
		wdata1	: in  unsigned((DATA_BITS-1) downto 0);
		rdata1	: out unsigned((DATA_BITS-1) downto 0)
	);
	
end entity;

architecture rtl of dg_sys_ram_dual_sync is
	type memtype is array (0 to 2**ADDR_BITS - 1) of unsigned(DATA_BITS-1 downto 0);
	shared variable mem : memtype;	
	
	signal reg_write0, reg_write1 : std_ulogic;
	signal reg_addr0,  reg_addr1  : unsigned((ADDR_BITS-1) downto 0);
	signal reg_wdata0, reg_wdata1 : unsigned((DATA_BITS-1) downto 0);
begin
	onclk0: process begin
		wait until rising_edge(clk0);
		reg_write0 <= write0;
		reg_addr0  <= addr0;
		reg_wdata0 <= wdata0;
		
		if reg_write0 = '1' then
			mem(to_integer(reg_addr0)) := reg_wdata0;
		end if;
		rdata0 <= mem(to_integer(reg_addr0));
	end process;
	
	onclk1: process begin
		wait until rising_edge(clk1);
		reg_write1 <= write1;
		reg_addr1  <= addr1;
		reg_wdata1 <= wdata1;
		
		if reg_write1 = '1' then
			mem(to_integer(reg_addr1)) := reg_wdata1;
		end if;
		rdata1 <= mem(to_integer(reg_addr1));
	end process;
end architecture;

`;
