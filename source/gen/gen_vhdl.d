module gen.gen_vhdl;
import common;
import std.file;
import std.array;
import std.algorithm;
import std.string;

private{
	enum strDesilog_SrcOutReg 	= "dg_SrcOR_";
	enum strDesilog_DstOutWire	= "dg_DstOW_";
	enum strDesilog_DstOutLatch	= "dg_DstOL_";
	enum strDesilog_DstReg 		= "dg_DstR_";

	string vhdlFilenameFromURI(string uri){
		return "out/" ~ uri ~ ".vhd";
	}
}

File vhdlOut;


private{
	int mIndent = 0;

	void xput(T...)(T args){
		vhdlOut.writef(args);
	}
	void xline(T...)(T args){
		vhdlOut.writef("\n");
		foreach(i; 0..mIndent) vhdlOut.writef("\t");
		vhdlOut.writef(args);
	}
}


private{
	string VhdlPackFromURI(string uri){
		return uri.replace(".","_");
	}

	void PrintVHDLUseHeader(KNode node){
		xput("library ieee;\n"
			"use ieee.std_logic_1164.all;\n"
			"use ieee.numeric_std.all;\n"
			"use ieee.std_logic_unsigned.all;\n"
			"use work.desilog.all;\n"
			);
		
		// write all "use" things before this node was declared

		foreach(k; node.kids){
			KImport imp = cast(KImport)k; if(!imp)continue;
			xline("use work.%s.all;",VhdlPackFromURI(imp.name));
		}

		xline("");
	}

	/*
	void printKName(KNode node){
		xput("%s", node.name);
	}
	void printKTyp(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec && typ.size==1){
			xput("std_logic");
		}else{
			printKName(typ);
		}
	}*/

	string typName(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec && typ.size==1){
			return "std_logic";
		}else{
			return typ.name;
		}
	}

	void printVHDLTypeDef(KTyp typ){
		switch(typ.kind){
			case KTyp.EKind.kstruct:
				xline("type %s is record", typ.name);
				foreach(KVar m; typ){
					xline("	%s: %s;", m.name, typName(m.typ));
				}
				xline("end record;\n");
				break;
			case KTyp.EKind.kvec:
				xline("subtype %s is std_logic_vector(%d downto 0);", typ.name, typ.size - 1);
				break;
			case KTyp.EKind.karray:
				xline("type %s is array(0 to %d) of %s;", typ.name, typ.size - 1, typName(typ.base));
				break;
			case KTyp.EKind.kenum:
				xline("type %s is (", typ.name);
				foreach(int i, m; typ.kids){
					if(i)xput(",");
					xline("	 %s_%s", typ.name, m.name);
				}
				xput(");\n");
				break;
			default:
				notImplemented();
		}
	}


	void WriteSizedVectorNum(int siz, int value){
		if(siz < 32){
			if(siz < 1)err("Size ", siz, " is negative");
			int mask = (1 << siz) - 1;
			mask = ~mask;
			if(mask & value) err("Value ", value, " cannot fit in ", siz, " bits");
		}
		if(siz==1){
			xput("'%d'",value);
		}else if(siz >= 4){
			if(siz & 3){
				xput("(\"");
				for(int i=siz;i & 3;){
					i--;
					xput(((value >> i) & 1) ? "1" : "0");
				}
				xput("\" & ");
			}
			xput("X\"");
			for(int i=siz>>2;i--;){
				xput("%X", (value >> (i*4)) & 0xF);
			}
			
			if(siz & 3) xput("\")");
			else xput("\"");
		}else{
			xput("\"");
			for(int i=siz; i--;){
				xput(((value >> i) & 1) ? "1" : "0");
			}
			xput("\"");
		}
	}

	// print src, normalized towards a dstTyp.
	//     int -> X"00"
	void PrintSetStatementSrc(KTyp dstTyp, KExpr src){
		if(auto num = cast(KExprNum)src){
			WriteSizedVectorNum(dstTyp.size, num.val);
		}else{
			src.printVHDL();
		}
	}

	void PrintConditionalExpr(KExpr cond){
		xput("(");
		if(auto a = cast(KExprVar)cond){
			a.printVHDL();
			xput(" = '1'");
		}else{
			cond.printVHDL();
		}
		xput(")");
	}



	string GetSpecialVarPrefix(KVar var, bool isDest){
		if(isDest){
			if(var.storage == KVar.EStor.kreg){
				return strDesilog_DstReg;
			}
			if(var.Is.isOut){
				if(var.storage == KVar.EStor.kwire){
					return strDesilog_DstOutWire;
				}
				if(var.storage == KVar.EStor.klatch){
					return strDesilog_DstOutLatch;
				}
				notImplemented;
			}
		}else{
			if(var.Is.isOut) return strDesilog_SrcOutReg;
		}
		return "";
	}

	void PrintSensitivityList(KNode scop){
		xput("all");
		/*
		bool first = true;
		IterateKNode(KVar, v, scope->parent){
			if(!first)xput(", ");
			first = false;
			if(v->storage == KVar.EStor.kclock){
				xput("%s_clk,%s_reset_n", v->name, v->name);
			}else{
				const char* prefix = GetSpecialVarPrefix(v, false);
				xput("%s%s", prefix, v->name);
			}
		}*/
	}

	void printVHDL(KIntf k){
		xline("entity %s is port(", k.name);
		int idx=0, num=0;
		foreach(KVar p; k) 	 num++;
		foreach(KClock p; k) num++;

		foreach(KClock p; k){
			xline("	%s_clk, %s_reset_n: in std_logic", p.name, p.name);
			idx++;
			if(idx!= num)xput(";");
		}

		foreach(KVar p; k){
			xline("	%s:	%s %s", p.name, p.Is.isIn ? "in" : "out", typName(p.typ));

			idx++;
			if(idx!= num)xput(";");
			switch(p.storage){
				case KVar.EStor.kwire:	xput(" -- WIRE"); break;
				case KVar.EStor.klatch:	xput(" -- Latch"); break;
				case KVar.EStor.kreg:	xput(" -- reg"); break;
				default: break;
			}
		}
		xline("	);\nend entity;");
	}

	void printUnitSignal(KVar v){
		for(int i=0;i<2;i++){
			string prefix = GetSpecialVarPrefix(v, i != 0);
			if(!prefix.length) continue;
			xput("\n	signal %s%s: %s;", prefix, v.name, typName(v.typ));
		}
	}

	void printUnitSignalClockPump(KClock clk, KUnit unit){
		xline("---- sync clock pump for %s ------", clk.name);
		xline("process begin"); mIndent++;
		xline("wait until rising_edge(%s_clk);", clk.name);
		xline("if %s_reset_n = '0' then", clk.name);
		foreach(KVar reg; unit){ // find non-input regs with init
			if(reg.storage != KVar.EStor.kreg) continue;
			if(reg.Is.readOnly) continue;
			if(!reg.reset.firstTok) continue;
			/*assert(reg.initExpr);
				const char* prefixSrc = GetSpecialVarPrefix(reg, false);
				xline("	%s%s <= ", prefixSrc, reg.name);
				PrintSetStatementSrc(reg.typ, reg.initExpr);
				xput(";");*/
		}
		xline("else");
		foreach(KVar reg; unit){ // find non-input regs
			if(reg.storage != KVar.EStor.kreg) continue;
			if(reg.Is.readOnly) continue;
			string prefixSrc = GetSpecialVarPrefix(reg, false);
			string prefixDst = GetSpecialVarPrefix(reg, true);
			assert(prefixSrc != prefixDst);
			xline("	%s%s <= %s%s;", prefixSrc, reg.name, prefixDst, reg.name);
		}
		xline("end if;");
		mIndent--; xline("end process;");
	}

	void printUnitSignalsVHDL(KUnit unit){
		foreach(KVar v; unit){
			if(v.Is.port)continue;
			//if(v.Is.handle) continue;
			xput("\n	signal %s: %s;", v.name, typName(v.typ));
		}

		xput("\n	----- internal regs/wires/etc --------");
		foreach(KVar v; unit){
			printUnitSignal(v);
		}

		xput("\n\t----- unit signals -------------");
		foreach(KHandle h; unit){
			if(h.isInPort) continue;
			if(h.isArray){
				notImplemented;
			}
			foreach(KVar m; h){
				for(int i=0;i<2;i++){
					if(i){
						if(m.storage != KVar.EStor.kreg)break;
						if(m.Is.isIn)break;
					}
					xline("	signal %s%s_%s : ",  i ? "reg_" : "", h.name, m.name);
					if(h.isArray){
						//xput("typ_%s_%s;", v.name, m.name);
					}else{
						xput("%s;", typName(m.typ));
					}
				}
			}
		}
	}

	void printVHDL(KUnit unit){
		mIndent = 0;
		xline("--#------- %s ------------------------------------", unit.name);
		xline("architecture rtl of %s is", unit.name);
		mIndent = 1;
		
		foreach(KTyp t; unit){
			printVHDLTypeDef(t);
		}

		printUnitSignalsVHDL(unit);


		xput("\nbegin");
		
		foreach(KProcess p; unit){
			printVHDL(p);
		}
		
		xline("-------[ sub-units ]-----------");
		foreach(KSubUnit subu; unit){
			int num = 1;
			if(subu.isArray){
				num = subu.arrayLen;
			}
		}

		/*
		xline("-------[ links ]----------");
		foreach(KLink k; unit){
			xline("");
			k.dst.printVHDL(true);
			k.src.printVHDL(false);
			xput(";");
		}*/

		
		foreach(KClock clk; unit){
			printUnitSignalClockPump(clk, unit);
		}

		xline("------[ output registers] --------------");
		foreach(KVar oreg; unit){ // find regs with init
			if(oreg.storage != KVar.EStor.kreg) continue;
			if(!oreg.Is.isOut) continue;
			string prefixSrc = GetSpecialVarPrefix(oreg, false);
			xline("%s <= %s%s;", oreg.name, prefixSrc, oreg.name);
		}
		
		mIndent = 0;
		xline("end architecture;");
		xline("");

	}
	void printVHDL(KProcess proc){
		xline("%s: process (", proc.name, proc.clk.name, proc.clk.name);
		PrintSensitivityList(proc);
		xput(")");
		mIndent=2;
		
		foreach(KVar v; proc){
			xput("\n	variable %s: %s;", v.name, typName(v.typ));
		}
		xput("\n	begin");
		//PrintPreloadLatchesAndWires(parent, this);
		
		foreach(s; proc.code){
			printVHDL(s);
		}
		mIndent=1;
		xline("end process;");
	}

	void printVHDL(KStmtSet a){
		xline("");
		a.dst.printVHDL(true);
		PrintSetStatementSrc(a.dst.finalTyp, a.src);
		xput(";");
	}
	void printVHDL(KStmtMux a){
	}
	void printVHDL(KStmtIfElse a){
		with(a){
			for(size_t i=0; i < conds.length; i++){
				ICond cnd = conds[i];
				if(cnd.cond){
					if(i) xline("elsif ");
					else  xline("if ");
					PrintConditionalExpr(cnd.cond);
					xput(" then");
				}else{
					xline("else");
				}
				mIndent++;
				foreach(s; cnd.block.code){
					s.printVHDL();
				}
				mIndent--;
			}
			xline("end if;");
		}
	}

	void printVHDL(KStmt s){
			  if(auto a = cast(KStmtSet)s){		printVHDL(a);
		}else if(auto a = cast(KStmtMux)s){		printVHDL(a);
		}else if(auto a = cast(KStmtIfElse)s){	printVHDL(a);
		}else{
			errInternal;
		}
	}

	void printVHDL(KExprNum k) {
		xput("%d",k.val);
	}

	void printVHDL(KExpr k) {
			 if(auto a = cast(KExprBin)k) printVHDL(a);
		else if(auto a = cast(KExprVar)k) printVHDL(a);
		else if(auto a = cast(KExprNum)k) printVHDL(a);
		else errInternal;
	}

	void printVarOffsets(KTyp typ, XOffset[] offsets){
		for(size_t oi=0; oi < offsets.length; oi++){
			XOffset off = offsets[oi];
			if(typ.kind == KTyp.EKind.kstruct){
				KVar sm = cast(KVar)typ.kids[off.idx];
				xput(".%s", sm.name);
				typ = sm.typ;
			}else if(typ.kind == KTyp.EKind.karray){
				xput("[");
				if(off.arg){
					off.arg.printVHDL();
				}else{
					xput("%d", off.idx);
				}
				xput("]");
				typ = typ.base;
			}else if(typ.kind == KTyp.EKind.kvec){
				XOffset bsiz = offsets[oi+1];
				oi++; // consume second offset
				if(bsiz.idx == 1){
					if(!off.arg){
						xput("(%d)", off.idx);
					}else{
						xput("(");
						off.arg.printVHDL();
						xput(")");
					}
				}else{
					if(!off.arg){
						xput("(%d downto %d)", off.idx + bsiz.idx - 1, off.idx);
					}else{
						xput("((%d + (", bsiz.idx - 1);
						off.arg.printVHDL();
						xput(")) downto (");
						off.arg.printVHDL();
						xput("))");
					}
				}
				typ = getCustomSizedVec(bsiz.idx);
			}
		}
	}

	void printVHDL(KArg arg, bool isDest) {
		int firstOffs = 0;
		if(arg.obj){
			xput("%s_",arg.obj.name);
			firstOffs = 2;
		}
		string prefix = GetSpecialVarPrefix(arg.var, isDest);
		xput("%s%s", prefix, arg.var.name);
		KTyp typ = arg.var.typ;

		printVarOffsets(typ, arg.offsets[firstOffs .. $]);

		if(isDest){
			if(arg.var.storage == KVar.EStor.kvar){
				xput(" := ");
			}else{
				xput(" <= ");
			}
		}

	}

	void printVHDL(KExprVar k) {
		k.arg.printVHDL(false);
	}
	void printVHDL(KExprUnary k) {
		xput(" %c",cast(char)k.uniOp);
	}

	void printVHDL(KExprBin k) {
		xput("(");
		k.x.printVHDL();
		xput(" %s ", k.binOp);
		k.y.printVHDL();
		xput(")");
	}


	void printVHDL(KTestBench tb){
		xline("entity %s is  end entity;", tb.name);
		xline("architecture testbench of %s is", tb.name);
		xline("	signal done,error : std_logic := '0';");
		xline("	signal reset_n,clk : std_logic := '0';");
		xline("	signal counter : integer := 0;");
		foreach(KVar v; tb.intf){
			xline("	signal %s : %s;", v.name, typName(v.typ));
		}
		xline("begin");
		mIndent++;

		/*
		foreach(f, forcers){
			xline("process(clk, reset_n) begin");
			mIndent++;
			foreach_pvec(s, f.code){
				s.printVHDL();
			}
			mIndent--;
			xline("end process;");
		}
		*/
		xline("process begin");
		xline("	clk <= '0';  wait for 1 ps;");
		xline("	clk <= '1';  wait for 1 ps;");
		xline("end process;");
		
		xline("process begin");
		xline("	wait until rising_edge(clk);");
		xline("	counter <= counter + 1;");
		xline("	if counter >= 10 then");
		xline("		reset_n <= '1';");
		xline("	end if;");
		xline("end process;");
		
		xline("test: entity work.%s port map(", tb.intf.name);
		xline("	clk_clk => clk, clk_reset_n => reset_n");
		foreach(KVar port; tb.intf){
			xput(",");
			xline("	%s => %s ", port.name, port.name);
		}
		xline(");");

		/* FIXME restore
		if(verifEntries.num){
			xline("process begin");
			xline("	wait until rising_edge(clk);\n");
			mIndent++;
			int clockOffs = verifyOffs + 10;
			
			if(verifIn.num){
				int cidx = clockOffs;
				xline("case counter is -- write values");
				mIndent++;
				foreach(e; tb.verifEntries){
					assert(e.ins.num == verifIn.num);
					xline("when %d => ", cidx);
					int iidx = 0;
					foreach_pvec(set, verifIn){
						xline("	");
						set.printVHDL(true);
						PrintSetStatementSrc(verifIn.items[iidx].finalTyp, e.ins.items[iidx]);
						xput(";");
						iidx++;
					}
					cidx++;
				}
				xline("when others => null;");
				mIndent--;
				xline("end case;\n");
			}
			
			if(verifOut.num){
				int cidx = clockOffs + verifyLatency;
				xline("case counter is -- read+verify values");
				mIndent++;
				foreach_pvec(e, verifEntries){
					assert(e.ins.num == verifOut.num);
					xline("when %d => ", cidx);
					int oidx = 0;
					foreach_pvec(set, verifOut){
						xline("	if ");
						set.printVHDL(false);
						xput(" /= ");
						PrintSetStatementSrc(verifOut.items[oidx].finalTyp, e.outs.items[oidx]);
						xput(" then");
						xline("		error <= '1';");
						xline("	end if;");
						oidx++;
					}
					cidx++;
				}
				xline("when %d =>  done <= '1'; ", cidx+verifyOffs);
				xline("	if error='0' then");
				xline("	report \"---------[ TESTBENCH SUCCESS ]---------------\";");
				xline("	else");
				xline("	report \"---------[ TESTBENCH FAILURE ]---------------\";");
				xline("	end if;");
				xline("when others => null;");
				mIndent--;
				xline("end case;");
			}
			
			mIndent--;
			xline("end process;");
		}
		*/
		
		mIndent--;
		xline("end architecture;");
	}




}

private{
	void GenPackageFile(DPFile pack){
		CreateFile(pack.name);
		PrintVHDLUseHeader(pack);
		xline("package %s is", VhdlPackFromURI(pack.name));
		foreach(KTyp t; pack){
			printVHDLTypeDef(t);
		}
		xline("end package;");


		foreach(KIntf intf; pack){
			PrintVHDLUseHeader(pack);
			printVHDL(intf);
		}
	}

	void GenUnitFile(DPFile funit){
		CreateFile(funit.name);
		foreach(KUnit unit; funit){
			PrintVHDLUseHeader(funit);
			printVHDL(unit);
		}

		foreach(KTestBench tb; funit){
			PrintVHDLUseHeader(funit);
			printVHDL(tb);
		}
	}

	void GenDesilogFile(){
		CreateFile("desilog");
		xput(
`library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


package desilog is
subtype  u8 is std_logic_vector( 7 downto 0);
subtype u16 is std_logic_vector(15 downto 0);
subtype u32 is std_logic_vector(31 downto 0);

type string_ptr is access string;
--function str(a : std_logic_vector) return string;
--function str(a : integer) return string; 

end package;
`);

	}
}

void CreateFile(string uri){
	if(0){
		vhdlOut = stdout; //vhdlOut = new File(
	}else{
		if(vhdlOut.isOpen) vhdlOut.close();
		vhdlOut.open("out/" ~ uri ~ ".vhd","w");
	}
}

void GenerateAllVHDL(DProj proj){

	if(!exists("out")) mkdir("out");




	foreach(DPFile dfile; proj){
		if(!dfile.isUnit) GenPackageFile(dfile);
	}
	foreach(DPFile dfile; proj){
		if(dfile.isUnit) GenUnitFile(dfile);
	}

	// create the supporting-package
	GenDesilogFile();

	vhdlOut.close();
}
