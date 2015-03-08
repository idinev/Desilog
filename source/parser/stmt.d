module parser.stmt;
import common;

class KStmt{ // line-statement
	KArg  dst;
};

class KStmtSet : KStmt{
	KExpr src;
};


class KStmtLink : KStmt{
	VEndPoint edst, esrc;
}

class KStmtObjMethod : KStmt{

}

class KStmtPick : KStmt{
	KExpr src;
	KExpr pass;
	KExpr fail;
};

class KStmtIncDec : KStmt{
	bool inc;
}

class KStmtMux : KStmt{
	KExpr mux;
	struct Entry{
		int[] icases;
		KExpr value;
	};
	Entry[] entries;
	KExpr others;
};

class KStmtArrMux : KStmt{
	KExpr mux;
	KExpr[] values;
}

class KStmtIfElse : KStmt{
	struct ICond{
		KExpr cond; // null for "else"
		KScope block;
	};
	ICond[] conds;
};
class KStmtSwitch : KStmt{
	KExpr mux;
	struct Entry{
		int[] icases;
		KScope block;
	};
	Entry[] entries;
	KScope others;
}

class KStmtReturn : KStmt{
	KExpr src;
	KFunc func;
}


// =================================================================================


KExpr ReqReadBoolExpr(KNode node){
	KExpr e = ReadExpr(node);
	if(!e.finalTyp) err("Required a boolean expression, not void");
	if(e.finalTyp.kind != KTyp.EKind.kvec && e.finalTyp.size != 1){
		err("Required a boolean expression");
	}
	return e;
}

int ReqReadEnumValue(KTyp fromEnum, bool readEnumName){
	if(readEnumName){
		req(fromEnum.name);
		req('.');
	}

	string ename = reqIdent;

	foreach(int eidx, m; fromEnum.kids){
		if(m.name == ename){
			return eidx;
		}
	}

	err("Enum value '", ename, "' not found in enumeration ", fromEnum.name);
	return 0;
}

KTyp VerifyMuxSelector(KExpr mux, ref int imax, string expressionName, int maxBits){
	KTyp pEnum = null;
	imax = 0;
	if(mux.finalTyp.kind == KTyp.EKind.kvec){
		int isiz = mux.finalTyp.size;
		if(isiz > maxBits){
			err(expressionName, " can handle only up to ",maxBits,"-bit selectors");
		}
		imax = (1 << isiz)-1;
	}else if(mux.finalTyp.kind == KTyp.EKind.kenum){
		pEnum = mux.finalTyp;
	}else{
		err(expressionName, " accepts only vectors and enums");
	}
	return pEnum;
}

KStmt ParseStatementArrMux(KScope node, KArg dst){
	KStmtArrMux s = new KStmtArrMux;
	s.mux = ReadExpr(node);

	int imax = 0;
	KTyp pEnum = VerifyMuxSelector(s.mux, imax, "mux[]", 24);

	req(']'); req('{');
	for(;;){
		KExpr exp = ReadExpr(node);
		s.values ~= exp;
		if(peek('}'))break;
		req(',');
	}
	return s;
}


KStmt ParseStatementMux(KScope node, KArg dst){
	if(peek('[')){
		return ParseStatementArrMux(node, dst);
	}
	req('(');
	KStmtMux s = new KStmtMux();
	s.mux = ReadExpr(node);
	
	int imax = 0;
	KTyp pEnum = VerifyMuxSelector(s.mux, imax, "mux()", 31);

	req(')'); req('{');
	for(;;){
		if(peek('}'))break;
		if(peek("default")){
			req(':');
			s.others = ReadExpr(node);
			req(';'); req('}');
			break;
		}
		KStmtMux.Entry entry;
		for(;;){
			int icase;
			if(pEnum)	icase = ReqReadEnumValue(pEnum, true);
			else		icase = reqGetConstIntegerExpr(0, imax);
			entry.icases ~= icase;

			if(!peek(','))break;
		}
		req(':');
		entry.value = ReadExpr(node);
		req(';');
		s.entries ~= entry;
	}	
	return s;
}

KStmt ParseStatementObjMethod(KScope node, KArg dst){
	KStmtObjMethod s = new KStmtObjMethod();
	return s;
}

KStmt ParseStatementSet(KScope node, KArg dst){
	if(peek("mux")){
		return ParseStatementMux(node, dst);
	}
	KStmtSet s = new KStmtSet();
	s.src =  ReadExpr(node);
	return s;
}

KStmt ParseStatementPick(KScope node, KArg dst){
	KStmtPick s = new KStmtPick();
	s.src = ReqReadBoolExpr(node);
	req('?');
	s.pass = ReadExpr(node);
	req(':');
	s.fail = ReadExpr(node);
	return s;
}

KStmt ParseStatementIncDec(KScope node, KArg dst, bool inc){
	if(dst.finalTyp.kind != KTyp.EKind.kvec){
		err("Operators ++ and -- can be applied to vectors, as single-line statements");
	}

	auto s = new KStmtIncDec;
	s.inc = inc;
	dst.onRead();
	return s;
}

KStmt ParseStatementIf(KScope node){
	KStmtIfElse s = new KStmtIfElse();
	bool isElse = false;
	
	for(;;){
		KStmtIfElse.ICond cond;
		cond.block = new KScope;
		cond.block.parent = node;
		cond.cond = null;
		if(!isElse){
			cond.cond = ReqReadBoolExpr(node);
		}
		req('{');
		cond.block.code = ReadStatementList(cond.block);
		s.conds ~= cond;
		if(isElse)break;
		
		if(peek("elif")){
		}else if(peek("else")){
			isElse = true;
		}else{
			break;
		}
	}
	
	return s;
}

KStmt ParseStatementSwitch(KScope node){
	KStmtSwitch s = new KStmtSwitch;
	s.mux = ReadExpr(node);

	int imax = 0;
	KTyp pEnum = VerifyMuxSelector(s.mux, imax, "mux()", 31);

	req('{');

	KScope curBlock = null;

	for(;;){
		if(peek('}'))break;
		if(peek("default")){
			if(s.others)err("'default:' already specified");
			req(':');
			curBlock = new KScope;
			curBlock.parent = node;
			s.others = curBlock;
		}else if(peek("case")){
			if(s.others)err("Cannot specify 'case' after 'default:' was specified");
			KStmtSwitch.Entry entry;
			for(;;){
				int icase;
				if(pEnum)	icase = ReqReadEnumValue(pEnum, true);
				else		icase = reqGetConstIntegerExpr(0, imax);
				entry.icases ~= icase;

				if(!peek(','))break;
			}
			req(':');
			curBlock = new KScope;
			curBlock.parent = node;
			entry.block = curBlock;
			s.entries ~= entry;
		}else{
			// must be a normal statement
			if(!curBlock) err("No case/default specified");
			ReadStatementLine(curBlock, curBlock.code);
		}
	}

	return s;
}

void ParseStatementVar(KScope node, ref KStmt[] code){
	KScope root = reqGetRootScope(node);
	KTyp typ = reqTyp(root);

	for(;;){
		KVar v = new KVar;
		v.readName(root);
		v.typ = typ;
		v.storage	= KVar.EStor.kvar;

		int setExpr = 0;
		if(peek('=')){
			setExpr = 1;
		}else if(peek("?=")){
			setExpr = 2;
		}

		if(setExpr){
			KArgVar dst = new KArgVar;
			dst.var = v;
			dst.finalTyp = v.typ;
			dst.proc = node;
			dst.isDest = true;
			dst.onWrite();

			KStmt s;
			if(setExpr == 1) s = ParseStatementSet(node, dst);
			if(setExpr == 2) s = ParseStatementPick(node, dst);

			s.dst = dst;
			code ~= s;
		}
		if(peek(','))continue;
		break;
	}
	req(';');
}

KStmt ParseStatementReturn(KScope node){
	KScope root = reqGetRootScope(node);
	KFunc func = cast(KFunc)root;
	if(!func) err("Return statement valid only in functions");

	auto r = new KStmtReturn;
	r.func = func;
	r.src = ReadExpr(node);
	req(';');
	return r;
}


void ReadStatementLine(KScope node, ref KStmt[] code){
	string word = reqIdent;
	KStmt s;
	
	if(word == "var"){
		ParseStatementVar(node, code);
		return;
	}else if(word == "if"){
		s = ParseStatementIf(node);
	}else if(word == "return"){
		s = ParseStatementReturn(node);
	}else if(word == "switch"){
		s = ParseStatementSwitch(node);
	}else{
		KArg dst = reqReadArg(word, node, true);
		
		if(cast(KArgObjMethod)dst){
			s = ParseStatementObjMethod(node, dst);
		}else{
			if(peek('=')){
				s = ParseStatementSet(node, dst);
			}else if(peek("?=")){
				s = ParseStatementPick(node, dst);
			}else if(peek("++")){
				s = ParseStatementIncDec(node, dst, true);
			}else if(peek("--")){
				s = ParseStatementIncDec(node, dst, false);
			}else{
				err("Accepted statement operators are only = and ?=");
			}
		}
		
		req(';');
		s.dst = dst;
	}
	code ~= s;
}

KStmt[] ReadStatementList(KScope node){
	KStmt[] code;
	for(;;){
		if(peek('}'))break;
		ReadStatementLine(node, code);
	}
	return code;
}

void RenameSubuInputPortClock(KSubUnit sub, string oldClk, string newClk){
	foreach(KVar v; sub){
		if(!v.Is.readOnly && v.clock && v.clock == oldClk){
			v.clock = newClk;
		}
	}
}

KStmt[] ReadLinksList(KScope node){
	KStmt[] code;
	for(;;){
		if(peek('}'))break;

		KStmtLink s = new KStmtLink;
		s.edst = reqReadEndPoint(node, true);
		req('=');
		s.esrc = reqReadEndPoint(node, false);
		if(s.edst.finalTyp != s.esrc.finalTyp)	err("Link endpoints are incompatible");

		if(s.edst.clk && s.edst.sub){
			RenameSubuInputPortClock(s.edst.sub, s.edst.clk.name, s.esrc.clk.name);
		}

		req(';');

		code ~= s;
	}
	return code;
}
