module gen.gen_vhdl;
import common;
import std.file;
import std.array;
import std.algorithm;
import std.string;
import std.conv;

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

		xnewline();
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
		if(typ.kind == KTyp.EKind.kvec){
			if(typ.size==1){
				return "std_logic";
			}else if(typ.name.canFind('[')){
				return "std_logic_vector(" ~ to!string(typ.size-1) ~ " downto 0)";
			}else{
				return typ.name;
			}
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

	void PrintTypeZeroInitter(KTyp typ){
		if(typ.kind == KTyp.EKind.kvec){
			WriteSizedVectorNum(typ.size, 0);
		}else if(typ.kind == KTyp.EKind.kenum){
			xput("%s_%s", typ.name, typ.kids[0].name);
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


	void PrintPreloadLatchesAndWires(KNode nodeWithVars, KScope scop){
		foreach(KVar reg; nodeWithVars){
			if(reg.Is.readOnly)continue;
			if(reg.storage != KVar.EStor.kreg)continue;
			if(reg.writer != scop)continue;
			string prefixD = GetSpecialVarPrefix(reg, true);
			string prefixS = GetSpecialVarPrefix(reg, false);
			xline("%s%s <= %s%s", prefixD, reg.name, prefixS, reg.name);
			xput("; -- register preload");
		}

		foreach(KVar latch; nodeWithVars){
			if(latch.Is.readOnly)continue;
			if(latch.storage != KVar.EStor.klatch)continue;
			if(latch.writer != scop)continue;
			string prefix = GetSpecialVarPrefix(latch, true);
			xline("%s%s <= %s%s", prefix, latch.name, prefix, latch.name);
			if(latch.resetExpr){
				if(KProcess proc = cast(KProcess)scop){
					xput("when %s_reset_n='1' else ", proc.clk.name);
					PrintMatchedSrc(latch.typ, latch.resetExpr);
				}else{
					err("Latch %s should be written in a clocked process, to have an initial value", latch.name);
				}
			}
			xput("; -- latch preload");
		}
		
		foreach(KVar wire; nodeWithVars){
			if(wire.Is.readOnly)continue;
			if(wire.storage != KVar.EStor.kwire)continue;
			if(wire.writer != scop)continue;
			string prefix = GetSpecialVarPrefix(wire, true);
			xline("%s%s <= ", prefix, wire.name);
			PrintTypeZeroInitter(wire.typ);
			if(wire.resetExpr){
				if(KProcess proc = cast(KProcess)scop){
					xput("when %s_reset_n='1' else ", proc.clk.name);
					PrintMatchedSrc(wire.typ, wire.resetExpr);
				}else{
					err("Wire %s should be written in a clocked process, to have an initial value", wire.name);
				}
			}

			xput("; -- wire pre-zero-init ");
		}
	}

	void PreloadRAMs(KProcess proc){
		KUnit unit = cast(KUnit)proc.parent;
		foreach(KRAM ram; unit){
			for(int idx=0; idx<2; idx++){
				if(ram.writer[idx] != proc)continue;
				string postfix = "";
				if(ram.dual) postfix = idx ? "1" : "0";
				xline("%s_write%s <= '0';",ram.name, postfix);
				xline("%s_addr%s_wire <= (others => '0');",ram.name, postfix);
				xline("%s_wdata%s <= ",ram.name, postfix);
				PrintTypeZeroInitter(ram.typ);
				xput(";");
			}
		}
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
			if(reg.resetExpr){
				string prefixSrc = GetSpecialVarPrefix(reg, false);
				xline("	%s%s <= ", prefixSrc, reg.name);
				PrintMatchedSrc(reg.typ, reg.resetExpr);
				xput(";");
			}
		}
		xline("else");
		foreach(KVar reg; unit){ // find non-input regs
			if(reg.storage != KVar.EStor.kreg) continue;
			if(reg.Is.readOnly) continue;
			if(!reg.writer)continue;
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

		xonceClear();
		foreach(KVar v; unit){
			xoncePut("\n	----- internal regs/wires/etc --------");
			printUnitSignal(v);
		}

		xonceClear();
		foreach(KSubUnit h; unit){
			if(h.isInPort) continue;
			xoncePut("\n\t----- unit signals -------------");

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

		foreach(KRAM h; unit){
			xline("---- internal signals for RAM %s -------------", h.name);
			int actualSize = (1 << (logNextPow2(h.size)));
			xline("type %s_arrtype is array (0 to %d) of %s;", h.name, actualSize - 1, typName(h.typ));
			xline("signal %s : %s_arrtype := (others => (others => '1'));", h.name, h.name);


			void WriteRAMSignals(KRAM h, string prefix){
				xline("signal %s_addr_wire%s: %s;", h.name, prefix, typName(h.addrTyp));
				xline("signal %s_addr_reg%s : %s;", h.name, prefix, typName(h.addrTyp));
				xline("signal %s_data%s: %s;", h.name, prefix, typName(h.typ));
				xline("signal %s_wdata%s: %s;", h.name, prefix, typName(h.typ));
				xline("signal %s_write%s: std_logic;", h.name, prefix);
			}

			if(h.dual){
				WriteRAMSignals(h, "0");
				WriteRAMSignals(h, "1");
			}else{
				WriteRAMSignals(h, "");
			}
		}

	}

	void printVHDL(KUnit unit){
		mIndent = 0;
		xline("--#------- %s ------------------------------------", unit.intf.name);
		xline("architecture rtl of %s is", unit.intf.name);
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

		foreach(KRAM h; unit){
			for(int idx=0; idx < 2; idx++){
				string postfix="";
				if(h.dual) postfix = idx ? "1" : "0";
				else if(idx)break;

				xline("--- clock pump for RAM %s port %d", h.name, idx);

				xline("process(%s_clk) begin 	if(rising_edge(%s_clk)) then", h.clk[idx].name, h.clk[idx].name);
				xline("\tif %s_write%s='1' then", h.name, postfix);
				xline("\t\t%s(conv_integer(%s_addr%s_wire)) <= %s_wdata%s;", h.name, h.name, postfix, h.name, postfix);
				xline("\tend if;");
				xline("\t%s_addr%s_reg <= %s_addr%s_wire;", h.name, postfix, h.name, postfix);
				xline("end if; end process;");
				xline("%s_data%s <= %s(conv_integer(%s_addr%s_reg));", h.name, postfix, h.name, h.name, postfix);
			}
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
		xnewline();
		xnewline();

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
		PrintPreloadLatchesAndWires(proc.parent, proc);

		PreloadRAMs(proc);

		foreach(s; proc.code){
			printVHDL(s);
		}
		mIndent=1;
		xline("end process;");
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
	void printVHDL(KStmtMux a){
		xline("case ");
		a.mux.printVHDL();
		xput(" is");
		foreach(e; a.entries){
			xline("\twhen ");
			foreach(int idx, val; e.icases){
				if(idx) xput(" | ");
				WriteSizedVectorNum(a.mux.finalTyp.size, val);
			}
			xput(" =>\t");
			PrintAssign(a.dst, e.value);
		}
		if(a.others){
			xline("\twhen others => ");
			PrintAssign(a.dst, a.others);
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


	void printVHDL(KStmtObjMethod s){
		if(auto a = cast(KArgRAMMeth)s.dst){
			switch(a.method.name){
				case "setAddr":
				case "setAddr0":
				case "setAddr1":
					xline("%s_addr_wire <= ", a.ram.name);
					PrintMatchedSrc(a.ram.addrTyp, a.methodArgs[0]);
					xput(";");
					break;
				case "write":
				case "write0":
				case "write1":
					xline("%s_write <= '1';", a.ram.name);
					xline("%s_wdata <= ", a.ram.name);
					PrintMatchedSrc(a.ram.typ, a.methodArgs[0]);
					xput(";");
					break;
				default: errInternal;
			}
		}else errInternal;
	}

	void printVHDL(KStmt s){
			  if(auto a = cast(KStmtSet)s)		printVHDL(a);
		else if(auto a = cast(KStmtMux)s)		printVHDL(a);
		else if(auto a = cast(KStmtIfElse)s)	printVHDL(a);
		else if(auto a = cast(KStmtObjMethod)s) printVHDL(a);
		else if(auto a = cast(KStmtPick)s)		printVHDL(a);
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
		else errInternal;
	}

	void vhdlArrayIndexOpen(){

	}
	void vhdlArrayIndexClose(){
		xput("))");
	}

	void vhdlPrintConvInteger(KExpr arg){
		xput("conv_integer(");
		arg.printVHDL();
		xput(")");
	}
	void vhdlPrintArrayElement(KExpr arg, int idx){
		if(!arg){
			xput("(%d)", idx);
		}else{
			xput("(conv_integer(");
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
		string prefix = GetSpecialVarPrefix(arg.var, arg.isDest);
		xput("%s%s", prefix, arg.var.name);

		vhdlPrintVarExtra(arg.var, arg.offsets, arg.isDest);
	}
	void printVHDL(KArgSubuPort arg){
		string prefix = GetSpecialVarPrefix(arg.var, arg.isDest);
		xput("%s%s_%s", prefix, arg.sub.name, arg.var.name);
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

	void printVHDL(KArg arg) {
			 if(auto a = cast(KArgVar)arg) 		printVHDL(a);
		else if(auto a = cast(KArgSubuPort)arg) printVHDL(a);
		else if(auto a = cast(KArgRAMDat)arg)	printVHDL(a);
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
			default:  vop = k.binOp;
		}

		xput(" %s ", vop);
		k.y.printVHDL();
		xput(")");
	}

	void printVHDL(KExprCmp k){
		xput("(");
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
					assert(e.ins.length == tb.vfy.argOuts.length);
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
				xline("	report \"---------[ TESTBENCH FAILURE ]---------------\";");
				xline("	end if;");
				xline("when others => null;");
				mIndent--;
				xline("end case;");
			}
			
			mIndent--;
			xline("end process;");
		}

		
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
		xnewline();
		xnewline();


		foreach(KIntf intf; pack){
			PrintVHDLUseHeader(pack);
			printVHDL(intf);
			xnewline();
			xnewline();
		}
	}

	void GenUnitFile(DPFile funit){
		CreateFile(funit.name);

		foreach(KIntf intf; funit){
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

		foreach(KTestBench tb; funit){
			PrintVHDLUseHeader(funit);
			printVHDL(tb);
			xnewline();
			xnewline();
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
subtype u64 is std_logic_vector(63 downto 0);
subtype  u2 is std_logic_vector( 1 downto 0);
subtype  u4 is std_logic_vector( 3 downto 0);

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
		vhdlOut.open(uri ~ ".vhd","w");
	}
}

void GenerateAllVHDL(DProj proj){



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
