-----------------------------------------------------------
--------- AUTOGENERATED FILE, DO NOT EDIT -----------------
-----------------------------------------------------------

library ieee;
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


