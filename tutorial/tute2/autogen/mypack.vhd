-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;


package mypack is
type MEM_CTL is record
	act: std_ulogic;
	write: std_ulogic;
	addr: u8;
	wdata: u8;
end record;

type MEM_RES is record
	valid: std_ulogic;
	busy: std_ulogic;
	rdata: u8;
end record;

type MyEnum is (
	 MyEnum_one,
	 MyEnum_two,
	 MyEnum_three);

subtype myVec55 is unsigned(54 downto 0);
type myArr256_u8 is array(0 to 255) of u8;

function DoXorAnd (aa : u8; bb : u8; isXor : std_ulogic) return u8;
end package;


package body mypack is

function DoXorAnd (aa : u8; bb : u8; isXor : std_ulogic) return u8 is
		variable result: u8;
	begin
		result := X"00"; -- local-var zero-init
		if (isXor = '1') then
			result := (aa xor bb);
		else
			result := (aa and bb);
		end if;
		return result;
	end;
end;
