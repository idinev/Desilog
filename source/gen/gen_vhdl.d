module gen.gen_vhdl;
import common;
import std.file;
import std.array;
import std.algorithm;
import std.string;
import std.conv;
import std.bitmanip;
import app;
import gen.gen_files;

private{
	enum strDesilog_SrcOutReg 	= "dg_o_";
	enum strDesilog_DstOutWire	= "dg_w_";
	enum strDesilog_DstOutLatch	= "dg_l_";
	enum strDesilog_DstReg 		= "dg_c_"; // actually a combi-out to be registered later

	string vhdlFilenameFromURI(string uri){
		return "out/" ~ uri ~ ".vhd";
	}
}

File vhdlOut;

string[] vhdlAllGenFiles;


private{
	int mIndent = 0;

	void xput(T...)(T args){
		vhdlOut.writef(args);
	}
	void xput(string str){
		vhdlOut.write(str);
	}
	void xline(T...)(T args){
		vhdlOut.writef("\n");
		foreach(i; 0..mIndent) vhdlOut.writef("\t");
		vhdlOut.writef(args);
	}
	void xnewline(){
		vhdlOut.writef("\n");
	}

	bool _onceTrigered = false;
	void xonceClear(){
		_onceTrigered = false;
	}
	void xoncePut(string s){
		if(!_onceTrigered) xput(s);
		_onceTrigered = true;
	}

}


private{
	// print src, normalized towards a dstTyp.
	//     int -> X"00"
	void PrintMatchedSrc(KTyp dstTyp, KExpr src){
		if(auto num = cast(KExprNum)src){
			WriteSizedVectorNum(dstTyp.size, num.val);
		}else{
			src.printVHDL();
		}
	}

	string VhdlPackFromURI(string uri){
		return uri.replace(".","_");
	}

	void PrintVHDLUseHeader(KNode node){
		xput(
`library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.desilog.all;
`
			);
		
		// write all "use" things before this node was declared

		foreach(k; node.kids){
			KImport imp = cast(KImport)k; if(!imp)continue;
			xline("use work.%s.all;",VhdlPackFromURI(imp.name));
		}

		xnewline();
	}

	/*
	void printKName(KNode node){
		xputs(node.name);
	}
	void printKTyp(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec && typ.size==1){
			xput("std_ulogic");
		}else{
			printKName(typ);
		}
	}*/

	string typName(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec){
			if(typ.size==1){
				return "std_ulogic";
			}else if(typ.name.canFind('[')){
				return "unsigned(" ~ to!string(typ.size-1) ~ " downto 0)";
			}else{
				return typ.name;
			}
		}else{
			return typ.name;
		}
	}

	string varName(KVar var, bool isDest){
		string handPrefix = "";
		if(var.handle){
			handPrefix = var.handle.name ~ "_";
		}

		string prefixD = GetSpecialVarPrefix(var, isDest);
		string result = prefixD ~ handPrefix ~ var.name;
		return result;
	}

	string enumName(KTyp typ, int eidx){
		return typ.name ~ "_" ~ typ.kids[eidx].name;
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
				xline("subtype %s is unsigned(%d downto 0);", typ.name, typ.size - 1);
				break;
			case KTyp.EKind.karray:
				xline("type %s is array(0 to %d) of %s;", typ.name, typ.size - 1, typName(typ.base));
				break;
			case KTyp.EKind.kenum:
				xline("type %s is (", typ.name);
				foreach(int i, m; typ.kids){
					if(i)xput(",");
					xline("	 %s", enumName(typ, i));
				}
				xput(");\n");
				break;
			default:
				errInternal;
		}
	}


	void WriteSizedVectorNum(int siz, ulong value){
		if(siz < 64){
			if(siz < 1)err("Size ", siz, " is negative");
			ulong mask = (1UL << cast(ulong)siz) - 1;
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


	void PrintConditionalExpr(KExpr cond){
		xput("(");
		cond.printVHDL();
		xput(" = '1'");
		xput(")");
	}



	string GetSpecialVarPrefix(KVar var, bool isDest){
		if(var.Is.isOut){
			switch(var.storage){
				case KVar.EStor.kreg:	return isDest ? strDesilog_DstReg : strDesilog_SrcOutReg;
				case KVar.EStor.kwire:	return strDesilog_DstOutWire;
				case KVar.EStor.klatch:	return strDesilog_DstOutLatch;
				default:	errInternal;
			}
		}

		if(isDest &&  var.storage == KVar.EStor.kreg){
			return strDesilog_DstReg;
		}
		return "";
	}

	void PrintTypeZeroInitter(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec){
			WriteSizedVectorNum(typ.size, 0);
		}else if(typ.kind == KTyp.EKind.kenum){
			xput(enumName(typ, 0));
		}else if(typ.kind == KTyp.EKind.karray){
			xput("( others => ");
			PrintTypeZeroInitter(typ.base);
			xput(")");
		}else if(typ.kind == KTyp.EKind.kstruct){
			xput("(");
			int midx=0;
			foreach(KVar m; typ){
				if(midx) xput(",");
				midx++;
				PrintTypeZeroInitter(m.typ);
			}
			xput(")");
		}else{
			notImplemented;
		}
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


	void PrintPreloadSignal(KVar var, KScope scop){
		if(var.storage == KVar.EStor.kreg){
			xline("%s <= %s; -- reg preload", varName(var,true), varName(var,false));
		}else if(var.storage == KVar.EStor.klatch){
			xline("%s <= %s", varName(var,true), varName(var,false));
			if(var.resetExpr){
				if(KProcess proc = cast(KProcess)scop){
					xput("when %s_reset_n='1' else ", proc.clk.name);
					PrintMatchedSrc(var.typ, var.resetExpr);
				}else{
					err("Latch %s should be written in a clocked process, to have an initial value", var.name);
				}
			}
			xput("; -- latch preload");
		}else if(var.storage == KVar.EStor.kwire){
			xline("%s <= ", varName(var,true));
			PrintTypeZeroInitter(var.typ);
			if(var.resetExpr){
				if(KProcess proc = cast(KProcess)scop){
					xput("when %s_reset_n='1' else ", proc.clk.name);
					PrintMatchedSrc(var.typ, var.resetExpr);
				}else{
					err("Wire %s should be written in a clocked process, to have an initial value", var.name);
				}
			}
			
			xput("; -- wire pre-zero-init");
		}else if(var.storage == KVar.EStor.kvar){
			xline("%s := ", varName(var,true));
			PrintTypeZeroInitter(var.typ);
			xput("; -- local-var zero-init");
		}
	}

	void PrintPreloadLatchesAndWires(KNode nodeWithVars, KScope scop){
		foreach(KVar var; nodeWithVars){
			if(var.Is.readOnly)continue;
			if(var.writer != scop)continue;
			PrintPreloadSignal(var, scop);
		}

		foreach(KHandle handl; nodeWithVars){
			foreach(KVar var; handl){
				if(var.Is.readOnly)continue;
				if(var.writer != scop)continue;
				PrintPreloadSignal(var, scop);
			}
		}
	}

	void printVHDL(KEntity k){
		xline("entity %s is port(", k.name);
		int idx=0, num=0;
		foreach(KVar p; k) 	 num++;
		foreach(KClock p; k) num++;

		foreach(KClock p; k){
			xline("	%s_clk, %s_reset_n: in std_ulogic", p.name, p.name);
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
		string prefix = GetSpecialVarPrefix(v, true);
		if(!prefix.length) return;
		xput("\n	signal %s%s: %s;", prefix, v.name, typName(v.typ));
		if(v.Is.isOut && v.storage == KVar.EStor.kreg){
			prefix = GetSpecialVarPrefix(v, false);
			xput("\n	signal %s%s: %s;", prefix, v.name, typName(v.typ));
		}
	}

	void printUnitSignalClockPump(KClock clk, KUnit unit){
		xnewline;
		xline("----[ sync clock pump for %s ]------", clk.name);
		xline("process begin"); mIndent++;
		xline("wait until rising_edge(%s_clk);", clk.name);

		bool anyReset = false;
		KNode[] nodesWithVars = [unit];
		foreach(KSubUnit sub; unit) nodesWithVars ~= sub;

		static bool isWritableReg(KVar reg){
			if(reg.storage != KVar.EStor.kreg) return false;
			if(reg.Is.readOnly)  return false;
			if(reg.writer && cast(KLink)reg.writer) return false;
			return true;
		}

		foreach(KNode n; nodesWithVars){
			foreach(KVar reg; n){ // find non-input regs
				if(!isWritableReg(reg))continue;
				if(reg.resetExpr) anyReset = true;
				xline("%s <= %s;", varName(reg, false), varName(reg, true));
			}
		}

		if(anyReset){
			xline("if %s_reset_n = '0' then", clk.name);
			foreach(KNode n; nodesWithVars){
				foreach(KVar reg; n){ // find non-input regs with init
					if(!isWritableReg(reg))continue;
					if(!reg.resetExpr)continue;
					xline("	%s <= ", varName(reg, false));
					PrintMatchedSrc(reg.typ, reg.resetExpr);
					xput(";");
				}
			}
			xline("end if;");
		}
		mIndent--; xline("end process;");
	}

	void printUnitSignalsVHDL(KUnit unit){
		foreach(KVar v; unit){
			if(v.Is.port)continue;
			//if(v.Is.handle) continue;
			string stor;
			switch(v.storage){
				case KVar.EStor.kreg:	stor = "	-- reg"; break;
				case KVar.EStor.kwire:	stor = "	-- WIRE"; break;
				case KVar.EStor.klatch:	stor = "	-- LATCH!!!"; break;
				default:				stor = "";
			}
			xput("\n	signal %s: %s;%s", v.name, typName(v.typ), stor);
		}

		xonceClear();
		foreach(KVar v; unit){
			xoncePut("\n\n\t----- internal regs/wires/etc --------");
			printUnitSignal(v);
		}

		xonceClear();
		foreach(KSubUnit sub; unit){
			if(sub.isInPort) continue;
			xoncePut("\n\n\t----- unit signals -------------");

			if(sub.isArray){
				notImplemented;
			}
			foreach(KVar m; sub){
				for(int i=0;i<2;i++){
					if(i){
						if(m.storage != KVar.EStor.kreg)break;
						if(m.Is.readOnly)break;
						if(m.writer && cast(KLink)m.writer){
							// is written by a link, 
							//don't make an extra signal
							break; 
						}
					}
					xline("	signal %s : ", varName(m, i==1));
					if(sub.isArray){
						//xput("typ_%s_%s;", v.name, m.name);
					}else{
						xput("%s;", typName(m.typ));
					}
				}
			}
			foreach(KClock subClk; sub){
				// print local signals for the clocks of this subunit
				if(sub.dstClk == subClk)continue;
				xline("\tsignal %s_%s_clk, %s_%s_reset_n : std_ulogic;", sub.name, subClk.name, sub.name, subClk.name);
			}
		}

		foreach(KRAM h; unit){
			xline("---- internal signals for %s %s -------------", h.isRom ? "ROM" : "RAM", h.name);
			int actualSize = (1 << (logNextPow2(h.size)));

			foreach(KVar v; h){
				xline("signal %s_%s: %s", h.name, v.name, typName(v.typ));
				if(!v.Is.readOnly && !v.writer){
					xput(" := ");
					PrintTypeZeroInitter(v.typ);
					xput("; -- WARNING: unwritten RAM input");
				}else{
					xput(";");
				}
			}
			if(h.isRom){
				xline("type %s_romtype is array(0 to %d) of %s;", h.name, h.size-1, typName(h.typ));
				xline("signal %s_romdata : %s_romtype := (", h.name, h.name);
				for(int idx=0; idx < h.size; idx++){
					if(idx) xput(",");
					if(!(idx & 7)) xline("\t");
					if(idx < h.romData.length){
						PrintMatchedSrc(h.typ, h.romData[idx]);
					}else{
						PrintTypeZeroInitter(h.typ);
					}
				}
				xline(");");
			}
		}
	}

	void printVHDL(KUnit unit){
		mIndent = 0;
		xline("--#------- %s ------------------------------------", unit.entity.name);
		xline("architecture rtl of %s is", unit.entity.name);
		mIndent = 1;
		
		foreach(KTyp t; unit){
			printVHDLTypeDef(t);
		}

		printUnitSignalsVHDL(unit);


		foreach(KFunc f; unit){
			printVHDLFunction(f, false);
		}
		foreach(KCasterFunc f; unit){
			printVHDLCasterFunc(f, false);
		}

		xput("\nbegin");

		foreach(KCombi p; unit){
			printVHDLProcess(p);
		}
		
		foreach(KProcess p; unit){
			printVHDLProcess(p);
		}



		xonceClear;
		foreach(KSubUnit subu; unit){ 
			xoncePut("\n\n\t-------[ sub-units ]-----------");
			int num = 1;
			if(subu.isArray){
				num = subu.arrayLen;
			}
			xline("%s : entity work.%s port map(", subu.name, subu.intf.name);
			mIndent++;

			bool anyPrinted=false;
			foreach(int idx, n; subu.kids){
				if(anyPrinted)xput(",");
				if(n == subu.dstClk){
					xline("%s_clk => %s_clk,", n.name, subu.srcClk.name);
					xline("%s_reset_n => %s_reset_n", n.name, subu.srcClk.name);
				}else if(auto a = cast(KClock)n){
					xline("%s_clk => %s_%s_clk,", n.name, subu.name, n.name);
					xline("%s_reset_n => %s_%s_reset_n", n.name, subu.name, n.name);
				}else if(auto a = cast(KHandle)n){
					errInternal;
				}else if(auto a = cast(KVar)n){
					xline("%s => %s_%s", n.name, subu.name, n.name);
				}else{
					errInternal;
				}
				anyPrinted = true;
			}
			mIndent--;
			xline(");");
		}


		xonceClear;
		foreach(KLink k; unit){
			xoncePut("\n\n\t-------[ links ]----------");
			foreach(e; k.code){
				KStmtLink s = cast(KStmtLink)e;
				s.printVHDL();
			}
		}

		
		foreach(KClock clk; unit){
			printUnitSignalClockPump(clk, unit);
		}

		foreach(KRAM h; unit){ // for each RAM
			if(h.isRom) continue;
			int logSize = logNextPow2(h.size);
			xnewline;
			xline("%s: entity work.%s generic map(DATA_BITS=> %d, ADDR_BITS=>%d)", 
				h.name,
				h.dual ? "dg_sys_ram_dual_sync" : "dg_sys_ram_mono_sync",
				h.typ.calcTypSizeInBits(),
				logSize);


			xline("	port map("); //clk, mem_we, mem_idx, mem_data, mem_q");
			final void PrintPortPortmap(KRAM h, int idx){
				string n = h.name;
				final void printTuple(KRAM h, int idx, string vname){
					xput(", %s_%s%d", h.name, vname, idx);
				}
				xput("%s_clk", h.clk[idx].name);
				printTuple(h, idx, "write");
				printTuple(h, idx, "addr");
				printTuple(h, idx, "wdata");
				printTuple(h, idx, "data");
			}

			PrintPortPortmap(h, 0);
			if(h.dual){
				xput(", ");
				PrintPortPortmap(h, 1);
			}
			xput(");\n");
		}

		foreach(KRAM h; unit){ // for each ROM
			if(!h.isRom) continue;
			xnewline;

			int numPorts = h.dual ? 2 : 1;

			xline("process -- ROM pump for %s", h.name);
			for(int i=0;i<numPorts;i++){
				xline("	variable rv_addr%d : %s;", i, typName(h.addrTyp));
			}
			xline("begin");
			mIndent++;
			xline("wait until rising_edge(%s_clk);", h.clk[0].name);
			for(int i=0;i<numPorts;i++){
				xline("%s_data%d <= %s_romdata(to_integer(rv_addr%d));",h.name, i,  h.name, i);
				xline("rv_addr%d := %s_addr%d;",i, h.name, i);
			}
			mIndent--;
			xline("end process;");
			xnewline;
		}

		xonceClear;
		foreach(KVar oreg; unit){ // find regs with init
			if(!oreg.Is.isOut) continue;
			xoncePut("\n\n\t------[ output registers/wires/latches ] --------------");
			xline("%s <= %s;", oreg.name, varName(oreg, false));
		}
		
		mIndent = 0;
		xline("end;");
		xnewline();
		xnewline();

	}

	void printVHDLProcess(KScope proc){
		xnewline;
		xline("%s: process (", proc.name);
		PrintSensitivityList(proc);
		xput(")");
		mIndent=2;
		
		foreach(KVar v; proc){
			xput("\n\t\tvariable %s: %s;", v.name, typName(v.typ));
		}
		xput("\n	begin");
		PrintPreloadLatchesAndWires(proc.parent, proc);
		foreach(KVar localVar; proc){
			PrintPreloadSignal(localVar, proc);
		}


		foreach(s; proc.code){
			printVHDL(s);
		}
		mIndent=1;
		xline("end process;");
	}

	void printVHDLFunction(KFunc func, bool onlyDecl){
		xnewline;
		xline("function %s (",func.name);
		foreach(int idx, v; func.args){
			if(idx)xput("; ");
			xput("%s : %s", v.name, typName(v.typ));
		}
		xput(") return %s%s",typName(func.typ), (onlyDecl ? ";" : " is"));
		if(onlyDecl)return;

		mIndent=2;

		foreach(KVar v; func){
			if(!v.Is.funcArg) xput("\n\t\tvariable %s: %s;", v.name, typName(v.typ));
		}
		xput("\n	begin");
		foreach(KVar v; func){
			if(!v.Is.funcArg) PrintPreloadSignal(v,func);
		}

		foreach(s; func.code){
			printVHDL(s);
		}
		mIndent=1;
		xline("end;");
	}
	void printVHDLCasterFunc(KCasterFunc func, bool onlyDecl){
		xnewline;
		xline("function %s(arg : %s) return %s%s",
			func.name,
			typName(func.srcTyp), typName(func.dstTyp),
			onlyDecl ? ";" : " is");
		mIndent=2;

		int svecSiz = calcTypSizeInBits(func.srcTyp);
		int dvecSiz = calcTypSizeInBits(func.dstTyp);
		int mvecSiz = max(svecSiz,dvecSiz);

		xput("\n\t\tvariable tmp: unsigned(%d downto 0) := (others => '0');", mvecSiz-1);
		xput("\n\t\tvariable res: %s;", typName(func.dstTyp));
		xput("\n	begin");


		static void convThing(KTyp typ, bool isDest){
			switch(typ.kind){
				case KTyp.EKind.kvec:
					if(isDest){
						xline("res := tmp(%d downto 0);", typ.size - 1);
					}else{
						xline("tmp(%d downto 0) := arg;", typ.size - 1);
					}
					break;
				case KTyp.EKind.karray:
					if(typ.base.kind == KTyp.EKind.kvec){
						int dbit=0;
						int baseSiz = typ.base.size;
						for(int i=0;i<typ.size;i++){
							if(isDest){
								xline("res(%d) := tmp(%d downto %d);", i, dbit+baseSiz-1, dbit);
							}else{
								xline("tmp(%d downto %d) := arg(%d);", dbit+baseSiz-1, dbit, i);
							}
							dbit += baseSiz;
						}
					}else{
						notImplemented;
					}
					break;
				case KTyp.EKind.kstruct:
					int dbit=0;
					foreach(KVar m; typ){
						if(m.typ.kind == KTyp.EKind.kvec){
							int baseSiz = m.typ.size;
							if(isDest){
								xline("res.%s := tmp(%d downto %d);", m.name, dbit+baseSiz-1, dbit);
							}else{
								xline("tmp(%d downto %d) := arg.%s;", dbit+baseSiz-1, dbit, m.name);
							}
							dbit += baseSiz;
						}else{
							notImplemented;
						}
					}
					break;
				default:
					errInternal;
			}
		}


		convThing(func.srcTyp, false); // convert source to unsigned into "tmp"
		convThing(func.dstTyp, true);  // convert unsigned "tmp" to into "res"
		xline("return res;");

		mIndent=1;
		xline("end;");
	}

	void PrintAssign(KArg dst, KExpr src){
		dst.printVHDL();
		PrintMatchedSrc(dst.finalTyp, src);
		xput(";");
	}

	void PrintAssignLine(KArg dst, KExpr src, string lineStart=""){
		xline(lineStart);
		PrintAssign(dst, src);
	}

	void printVHDL(KStmtSet a){
		PrintAssignLine(a.dst, a.src, "");
	}

	void printWhenCases(KTyp muxTyp, int[] icases){
		xline("\twhen ");
		foreach(int idx, val; icases){
			if(idx) xput(" | ");
			if(muxTyp.kind == KTyp.EKind.kenum){
				xput(enumName(muxTyp, val));
			}else{
				WriteSizedVectorNum(muxTyp.size, val);
			}
		}
		xput(" =>\t");
	}

	void printVHDL(KStmtMux a){
		xnewline;
		xline("case ");
		a.mux.printVHDL();
		xput(" is");


		foreach(e; a.entries){
			printWhenCases(a.mux.finalTyp, e.icases);
			PrintAssign(a.dst, e.value);
		}
		if(a.others){
			xline("\twhen others => ");
			PrintAssign(a.dst, a.others);
		}

		xline("end case;");
	}
	void printVHDL(KStmtArrMux a){
		xnewline;
		xline("case ");
		a.mux.printVHDL();
		xput(" is");
		foreach(int i, e; a.values){
			if(i+1 < a.values.length){
				int[1] val; val[0] = i;
				printWhenCases(a.mux.finalTyp, val);
			}else{
				xline("\twhen others =>\t");
			}
			PrintAssign(a.dst, e);
		}

		xline("end case;");
	}

	void printVHDL(KStmtPick a){
		xline("if ");
		PrintConditionalExpr(a.src);
		xput(" then");
		PrintAssignLine(a.dst, a.pass, "\t");
		xline("else");
		PrintAssignLine(a.dst, a.fail, "\t");
		xline("end if;");
	}

	void printVHDL(KStmtIncDec a){
		xline("");
		a.dst.printVHDL();

		assert(a.dst.isDest);
		a.dst.isDest = false;
		a.dst.printVHDL();
		a.dst.isDest = true;
		xput(a.inc ? " + " : " - ");
		WriteSizedVectorNum(a.dst.finalTyp.size, 1);
		xput(";");
	}

	void printVHDL(KStmtReturn a){
		xline("return ");
		PrintMatchedSrc(a.func.typ, a.src);
		xput(";");
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

	void printVHDL(KStmtSwitch a){
		xnewline;
		xline("case ");
		a.mux.printVHDL();
		xput(" is");

		foreach(e; a.entries){
			printWhenCases(a.mux.finalTyp, e.icases);
			mIndent+=2;
			if(!e.block.code.length) xput("null;");
			foreach(s; e.block.code) s.printVHDL();
			mIndent-=2;
		}
		if(a.others){
			xline("\twhen others => ");
			if(!a.others.code.length) xput("null;");
			mIndent+=2;
			foreach(s; a.others.code) s.printVHDL();
			mIndent-=2;
		}else{
			xline("\twhen others => null;");
		}
		xline("end case;");
	}

	void PrintEndPointAttr(VEndPoint p, string attr){
		if(p.var){
			xput(varName(p.var, false));
			if(p.arrSubIdx){
				xput("(%d)", p.arrSubIdx - 1);
			}
			if(p.arrVarIdx){
				xput("(%d)", p.arrVarIdx - 1);
			}
			xput(attr);
		}else if(p.clk){
			if(p.sub){
				xput("%s_", p.sub.name);
				if(p.arrSubIdx){
					xput("(%d).", p.arrSubIdx - 1);
				}
			}
			xput("%s%s", p.clk.name, attr);
		}else{
			errInternal;
		}

	}
	void PrintEndPointAssignAttr(VEndPoint dst, VEndPoint src, string attr){
		xline("");
		PrintEndPointAttr(dst, attr);
		xput(" <= ");
		PrintEndPointAttr(src, attr);
		xput(";");
	}

	void printVHDL(KStmtLink a){
		VEndPoint dst = a.edst;
		VEndPoint src = a.esrc;

		if(dst.clk){
			PrintEndPointAssignAttr(dst, src, "_clk");
			PrintEndPointAssignAttr(dst, src, "_reset_n");
		}else{
			PrintEndPointAssignAttr(dst, src, "");
		}
	}


	void printVHDL(KStmtObjMethod s){
		/*if(auto a = cast(KArgRAMMeth)s.dst){
			int port = 0;
			switch(a.method.name){
				case "setAddr0":
				case "setAddr1":
					if(a.method.name == "setAddr1") port = 1;
					xline("%s_addr%d_wire <= ", a.ram.name, port);
					PrintMatchedSrc(a.ram.addrTyp, a.methodArgs[0]);
					xput(";");
					break;
				case "write0":
				case "write1":
					if(a.method.name == "write1") port = 1;
					xline("%s_write%d <= '1';", a.ram.name, port);
					xline("%s_wdata%d <= ", a.ram.name, port);
					PrintMatchedSrc(a.ram.typ, a.methodArgs[0]);
					xput(";");
					break;
				default: errInternal;
			}
		}
		else
		*/
		errInternal;
	}

	void printVHDL(KStmtReport s){
		if(!s.allow) return;
		if(!cfgGenReport) return;
		string padding = ` & " "`; // can be configured to be none
		string severityStr;
		string vhdlSevStr;
		switch(s.severityLevel){
			case 0:  severityStr = "DG_VERBOSE";	vhdlSevStr="note";		break;
			case 1:  severityStr = "DG_NOTE";		vhdlSevStr="note";		break;
			case 2:  severityStr = "DG_WARNING";	vhdlSevStr="warning";	break;
			default: severityStr = "DG_ERROR";		vhdlSevStr="error";
		}
		xline(`report "%s%d: "`, severityStr, s.severityLevel);
		foreach(idx, str; s.strings){
			if(s.values[idx]){
				xput(` & str(`);
				printVHDL(s.values[idx]);
				xput(`)%s`, padding);
			}else{
				xput(` & %s%s`, str, padding);
			}
		}
		xput(" severity %s;", vhdlSevStr);
	}

	void printVHDL(KStmtAssert s){
		if(!cfgGenAssert) return;
		xline("assert ");
		PrintConditionalExpr(s.cond);
		xput(` report "DG assert fail at %s:%d" severity failure;`, s.fileName, s.lineNum);
	}

	void printVHDL(KStmt s){
			  if(auto a = cast(KStmtSet)s)		printVHDL(a);
		else if(auto a = cast(KStmtMux)s)		printVHDL(a);
		else if(auto a = cast(KStmtArrMux)s)	printVHDL(a);
		else if(auto a = cast(KStmtIfElse)s)	printVHDL(a);
		else if(auto a = cast(KStmtSwitch)s)	printVHDL(a);
		else if(auto a = cast(KStmtObjMethod)s) printVHDL(a);
		else if(auto a = cast(KStmtPick)s)		printVHDL(a);
		else if(auto a = cast(KStmtReturn)s)	printVHDL(a);
		else if(auto a = cast(KStmtIncDec)s)	printVHDL(a);
		else if(auto a = cast(KStmtReport)s)	printVHDL(a);
		else if(auto a = cast(KStmtAssert)s)	printVHDL(a);
		else errInternal;
	}


	void printVHDL(KExprNum k) {
		xput("%d",k.val);
	}

	void printVHDL(KExpr k) {
			 if(auto a = cast(KExprBin)k) printVHDL(a);
		else if(auto a = cast(KExprVar)k) printVHDL(a);
		else if(auto a = cast(KExprNum)k) printVHDL(a);
		else if(auto a = cast(KExprUnary)k) printVHDL(a);
		else if(auto a = cast(KExprCmp)k) printVHDL(a);
		else if(auto a = cast(KExprCast)k)printVHDL(a);
		else if(auto a = cast(KExprEnumMemb)k)printVHDL(a);
		else errInternal;
	}

	void vhdlArrayIndexOpen(){

	}
	void vhdlArrayIndexClose(){
		xput("))");
	}

	void vhdlPrintConvInteger(KExpr arg){
		xput("to_integer(");
		arg.printVHDL();
		xput(")");
	}
	void vhdlPrintArrayElement(KExpr arg, int idx){
		if(!arg){
			xput("(%d)", idx);
		}else{
			xput("(to_integer(");
			arg.printVHDL();
			xput("))");
		}
	}
	void vhdlPrintArrayRange(KExpr arg, int idx, int len){
		if(!arg){
			xput("(%d downto %d)", idx + len - 1, idx);
		}else{
			xput("(%d + ", len-1);
			vhdlPrintConvInteger(arg);
			xput(" downto ");
			vhdlPrintConvInteger(arg);
			xput(")");
		}
	}


	void printVarOffsets(XOffset[] offsets){
		foreach(off; offsets){
			if(off.bits){
				if(off.bits == 1){
					vhdlPrintArrayElement(off.exp, off.idx);
				}else{
					vhdlPrintArrayRange(off.exp, off.idx, off.bits);
				}
			}else if(off.sMember){
				xput(".%s", off.sMember.name);
			}else{
				vhdlPrintArrayElement(off.exp, off.idx);
			}
		}
	}

	void vhdlPrintVarExtra(KVar var, XOffset[] offsets, bool isDest){
		printVarOffsets(offsets);
		
		if(isDest){
			if(var.storage == KVar.EStor.kvar){
				xput(" := ");
			}else{
				xput(" <= ");
			}
		}
	}

	void printVHDL(KArgVar arg){
		xput(varName(arg.var, arg.isDest));

		vhdlPrintVarExtra(arg.var, arg.offsets, arg.isDest);
	}
	void printVHDL(KArgSubuPort arg){
		xput(varName(arg.var, arg.isDest));
		if(arg.sub.isArray){
			vhdlPrintArrayElement(arg.arrIdx.exp, arg.arrIdx.idx);
		}

		vhdlPrintVarExtra(arg.var, arg.offsets, arg.isDest);
	}


	void printVHDL(KArgRAMDat arg){
		xput("%s_%s", arg.ram.name, arg.var.name);
		if(arg.ram.isArray){
			vhdlPrintArrayElement(arg.arrIdx.exp, arg.arrIdx.idx);
		}
		vhdlPrintVarExtra(arg.var, arg.offsets, arg.isDest);
	}
	void printVHDL(KArgFuncCall call){
		xput("%s(", call.func.name);
		foreach(int i, a; call.func.args){
			if(i)xput(", ");
			PrintMatchedSrc(a.typ, call.args[i]);
		}
		xput(")");
	}
	void printVHDL(KArgClockDat arg){
		string vname = varName(arg.var, arg.isDest);
		if(arg.var.name=="reset"){
			// we had represented the reset as active-high,
			// when it's active-low and with name "reset_n"
			xput("(not %s_n)",vname);
		}else{
			xput(vname);
		}
		
		vhdlPrintVarExtra(arg.var, arg.offsets, arg.isDest);
	}

	void printVHDL(KArg arg) {
			 if(auto a = cast(KArgVar)arg) 		printVHDL(a);
		else if(auto a = cast(KArgSubuPort)arg) printVHDL(a);
		else if(auto a = cast(KArgRAMDat)arg)	printVHDL(a);
		else if(auto a = cast(KArgFuncCall)arg)	printVHDL(a);
		else if(auto a = cast(KArgClockDat)arg)	printVHDL(a);
		else notImplemented;
	}

	void printVHDL(KExprVar k) {
		k.arg.printVHDL();
	}
	void printVHDL(KExprUnary k) {
		string vop;
		switch(k.uniOp){
			case '-':	vop = "-";  break;
			case '!':	vop = "not"; break;
			case '~':	vop = "not"; break;
			default: errInternal;
		}
		string zero = "";
		if(k.uniOp == '-'){
			// VHDL doesn't directly handle unary '-'
			// so, prepend a 0
			zero = "0 "; 
		}

		xput(" (%s%s ", zero, vop);
		k.x.printVHDL();
		xput(")");
	}



	void printVHDL(KExprBin k) {
		xput("(");
		k.x.printVHDL();
		string vop;
		switch(k.binOp){
			case "^": vop = "xor"; break;
			case "&": vop = "and"; break;
			case "|": vop = "or"; break;
			case "~": vop = "&"; break;
			default:  vop = k.binOp;
		}

		xput(" %s ", vop);
		k.y.printVHDL();
		xput(")");
	}

	void printVHDL(KExprCmp k){
		xput("dg_boolToBit(");
		k.x.printVHDL();
		string vop;
		switch(k.cmpOp){
			case "==": vop = "=";  break;
			case "<":  vop = "<";  break;
			case ">":  vop = ">";  break;
			case "!=": vop = "/="; break;
			case "<=": vop = "<="; break;
			case ">=": vop = ">="; break;
			default: errInternal;
		}
		
		xput(" %s ", vop);
		PrintMatchedSrc(k.x.finalTyp, k.y);
		xput(")");
	}
	void printVHDL(KExprCast k){
		xput("%s(", k.casterFuncName);
		k.arg.printVHDL();
		xput(")");
	}
	void printVHDL(KExprEnumMemb k){
		xput(enumName(k.finalTyp, k.eidx));
	}


	void printVHDL(KTestBench tb){
		xline("entity %s is  end entity;", tb.name);
		xline("architecture testbench of %s is", tb.name);
		xline("	signal success, done, error : std_ulogic := '0';");
		xline("	signal reset_n, clk : std_ulogic := '0';");
		xline("	signal counter : integer := 0;");
		foreach(KVar v; tb.intf){
			xline("	signal %s : %s;", v.name, typName(v.typ));
		}
		xline("begin");
		mIndent++;


		foreach(KTBForcer f; tb){
			xline("process(clk, reset_n) begin");
			mIndent++;
			foreach(s; f.code){
				s.printVHDL();
			}
			mIndent--;
			xline("end process;");
		}
		xline("success <= done and (not error);");
		xline("process begin");
		xline("	clk <= '0';  wait for %d ps;", cfgTestBenchPeriod/2);
		xline("	clk <= '1';  wait for %d ps;", cfgTestBenchPeriod/2);
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

		if(tb.vfy.entries.length){
			xline("process begin");
			xline("	wait until rising_edge(clk);\n");
			mIndent++;
			int clockOffs = tb.vfy.offset + 10;
			
			if(tb.vfy.argIns.length){
				int cidx = clockOffs;
				xline("case counter is -- write values");
				mIndent++;
				foreach(e; tb.vfy.entries){
					assert(e.ins.length == tb.vfy.argIns.length);
					xline("when %d => ", cidx);
					int iidx = 0;
					foreach(set; tb.vfy.argIns){
						xline("	");
						set.printVHDL();
						PrintMatchedSrc(tb.vfy.argIns[iidx].finalTyp, e.ins[iidx]);
						xput(";");
						iidx++;
					}
					cidx++;
				}
				xline("when others => null;");
				mIndent--;
				xline("end case;\n");
			}
			
			if(tb.vfy.argOuts.length){
				int cidx = clockOffs + tb.vfy.latency;
				xline("case counter is -- read+verify values");
				mIndent++;
				foreach(e; tb.vfy.entries){
					assert(e.outs.length == tb.vfy.argOuts.length);
					xline("when %d => ", cidx);
					int oidx = 0;
					foreach(set; tb.vfy.argOuts){
						xline("	if ");
						set.printVHDL();
						xput(" /= ");
						PrintMatchedSrc(tb.vfy.argOuts[oidx].finalTyp, e.outs[oidx]);
						xput(" then");
						xline("		error <= '1';");
						xline("	end if;");
						oidx++;
					}
					cidx++;
				}
				xline("when %d =>  done <= '1'; ", cidx+tb.vfy.offset);
				xline("	if error='0' then");
				xline("	report \"---------[ TESTBENCH SUCCESS ]---------------\";");
				xline("	else");
				xline("	report \"---------[ !!! TESTBENCH FAILURE !!! ]---------------\";");
				xline("	end if;");
				xline("when others => null;");
				mIndent--;
				xline("end case;");
			}
			
			mIndent--;
			xline("end process;");
		}

		
		mIndent--;
		xline("end;");
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

		bool anyFuncs = false;
		foreach(KFunc f; pack){
			anyFuncs = true;
			printVHDLFunction(f, true);
		}
		foreach(KCasterFunc f; pack){
			anyFuncs = true;
			printVHDLCasterFunc(f, true);
		}

		xline("end package;");
		xnewline();
		xnewline();

		if(anyFuncs){
			xline("package body %s is", VhdlPackFromURI(pack.name));
			foreach(KFunc f; pack){
				printVHDLFunction(f, false);
			}
			foreach(KCasterFunc f; pack){
				printVHDLCasterFunc(f, false);
			}
			mIndent = 0;
			xline("end;");
			xnewline();
			xnewline();
		}


		foreach(KEntity intf; pack){
			PrintVHDLUseHeader(pack);
			printVHDL(intf);
			xnewline();
			xnewline();
		}
	}

	void GenUnitFile(DPFile funit){
		CreateFile(funit.name);

		foreach(KEntity intf; funit){
			PrintVHDLUseHeader(funit);
			printVHDL(intf);
			xnewline();
			xnewline();
		}

		foreach(KUnit unit; funit){
			PrintVHDLUseHeader(funit);
			printVHDL(unit);
			xnewline();
			xnewline();
		}


		bool anyTestBenches = false;
		foreach(KTestBench tb; funit) anyTestBenches = true;

		if(anyTestBenches){
			CreateFile(funit.name ~ "_tb"); // switch to the "_tb" file

			foreach(KTestBench tb; funit){
				PrintVHDLUseHeader(funit);
				printVHDL(tb);
				xnewline();
				xnewline();
			}
		}
	}

	void GenDesilogFiles(){
		CreateFile("desilog");
		xput(gen_files_Desilog_vhd);

		CreateFile("desilog_altera", cfgTestBenchAltera);
		xput(gen_files_Desilog_altera_vhd);

		CreateFile("desilog_generic", cfgTestBenchGeneric);
		xput(gen_files_Desilog_generic_vhd);
	}
}



void CreateFile(string uri, bool required = true){
	if(0){
		vhdlOut = stdout; //vhdlOut = new File(
	}else{
		if(vhdlOut.isOpen) vhdlOut.close();
		string fileName = uri ~ ".vhd";
		if(required) vhdlAllGenFiles ~= fileName;
		vhdlOut.open(fileName,"w");
		xput("-----------------------------------------------------------\n");
		xput("--------- AUTOGENERATED FILE, DO NOT EDIT -----------------\n");
		xput("-----------------------------------------------------------\n\n");
	}
}

void GenerateAllVHDL(DProj proj){

	// create the supporting-package files
	GenDesilogFiles();

	foreach(DPFile dfile; proj){
		if(!dfile.isUnit) GenPackageFile(dfile);
	}
	foreach(DPFile dfile; proj){
		if(dfile.isUnit) GenUnitFile(dfile);
	}


	vhdlOut.close();
}
