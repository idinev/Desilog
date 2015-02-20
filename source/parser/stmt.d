module parser.stmt;
import common;

class KStmt{ // line-statement
	KArg  dst;
};

class KStmtSet : KStmt{
	KExpr src;
};

class KStmtObjMethod : KStmt{

}

class KStmtPick : KStmt{
	KExpr src;
	KExpr pass;
	KExpr fail;
};

class KStmtMux : KStmt{
	KExpr mux;
	struct Entry{
		int[] icases;
		KExpr value;
	};
	Entry[] entries;
	KExpr others;
};

class KStmtIfElse : KStmt{
	struct ICond{
		KExpr cond; // null for "else"
		KScope block;
	};
	ICond[] conds;
};


// =================================================================================


KExpr ReqReadBoolExpr(KNode node){
	KExpr e = ReadExpr(node);
	if(e.finalTyp.kind != KTyp.EKind.kvec && e.finalTyp.size != 1){
		err("Required a boolean expression");
	}
	return e;
}

int ReqReadEnumValue(KTyp fromEnum){
	req(fromEnum.name);
	req('.');
	string ename = reqIdent;

	foreach(int eidx, m; fromEnum.kids){
		if(m.name == ename){
			return eidx;
		}
	}

	err("Enum value '", ename, "' not found in enumeration ", fromEnum.name);
	return 0;
}

KStmt ParseStatementMux(KNode node, KArg dst){
	req('(');
	KStmtMux s = new KStmtMux();
	s.mux = ReadExpr(node);
	
	KTyp pEnum = null;
	int imax = 0;
	if(s.mux.finalTyp.kind == KTyp.EKind.kvec){
		int isiz = s.mux.finalTyp.size;
		if(isiz > 31) err("mux() can handle only up to 31-bit selectors");
		imax = (1 << isiz)-1;
	}else if(s.mux.finalTyp.kind == KTyp.EKind.kenum){
		pEnum = s.mux.finalTyp;
	}else{
		err("mux() accepts only vectors and enums");
	}

	req(')'); req('{');
	for(;;){
		if(peek('}'))break;
		if(peek("else")){
			req(':');
			s.others = ReadExpr(node);
			req(';'); req('}');
			break;
		}
		KStmtMux.Entry entry;
		for(;;){
			int icase;
			if(pEnum){
				icase = ReqReadEnumValue(pEnum);
			}else{
				icase = reqGetConstIntegerExpr(0, imax);
			}
			entry.icases ~= icase;
			if(!peek(','))break;
		}
		req(':');
		entry.value = ReadExpr(node);
		req(';');
		s.entries ~= entry;
	}
	req(';');
	
	return s;
}

KStmt ParseStatementObjMethod(KNode node, KArg dst){
	KStmtObjMethod s = new KStmtObjMethod();
	return s;
}

KStmt ParseStatementSet(KNode node, KArg dst){
	if(peek("mux")){
		return ParseStatementMux(node, dst);
	}
	KStmtSet s = new KStmtSet();
	s.src =  ReadExpr(node);
	return s;
}

KStmt ParseStatementPick(KNode node, KArg dst){
	KStmtPick s = new KStmtPick();
	s.src = ReqReadBoolExpr(node);
	req('?');
	s.pass = ReadExpr(node);
	req(':');
	s.fail = ReadExpr(node);
	return s;
}
KStmt ParseStatementIf(KNode node){
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
		req('}');
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



KStmt[] ReadStatementList(KNode node){
	KStmt[] code;
	for(;;){
		if(peek('}'))break;
		string word = reqIdent;
		KStmt s;
		
		if(word == "var"){
			notImplemented;
		}else if(word == "if"){
			s = ParseStatementIf(node);
		}else{
			KArg dst;
			KNode symbol = node.findNode(word);
			if(!symbol)err("Unknown symbol");
			dst = ReadArg(symbol, node, true);

			if(cast(KArgObjMethod)dst){
				s = ParseStatementObjMethod(node, dst);
			}else{
				if(peek('=')){
					s = ParseStatementSet(node, dst);
				}else if(peek("?=")){
					s = ParseStatementPick(node, dst);
				}else{
					err("Accepted statement operators are only = and ?=");
				}
			}

			req(';');
			s.dst = dst;
		}
		code ~= s;
	}
	return code;
}
