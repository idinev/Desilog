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
--function str(a : unsigned) return string;
--function str(a : integer) return string; 
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
