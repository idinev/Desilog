module nodes.kvar;
import common;




class KVar : KNode{
	KTyp typ;
	EStor storage;
	string clock;
	IdxTok reset;
	VarFlags Is;
	KScope writer;
	KExpr resetExpr;
	KHandle handle;

	enum EStor{
		kinvalid,
		kreg,
		kwire,
		klatch,
		kvar,
	}
	
	struct VarFlags{
		bool isIn;
		bool isOut;
		bool port;
		bool signal;
		bool readOnly;
		bool writeOnly;
		bool everRead;
		bool funcArg;
	}
}

KVar reqFindVar(KNode node, string name){
	KVar v = node.findNodeOfKind!KVar(name);
	if(!v) err("Cannot find variable");
	return v;
}


struct VEndPoint{
	KSubUnit sub;
	KVar var;
	KClock clk;

	KTyp finalTyp;

	int arrSubIdx; // 0 if none, 1-based index if array-element of "sub"
	int arrVarIdx; // 0 if none, 1-based index if array-element of "var"
}

VEndPoint reqReadEndPoint(KScope node, bool isDest){
	string symName = reqIdent;
	KNode symbol = node.findNode(symName);
	if(!symbol)err("Unknown symbol:", symbol);

	VEndPoint pt;

	if(KSubUnit sub = cast(KSubUnit)symbol){
		pt.sub = sub;
		if(sub.isArray){
			req('['); 
			pt.arrSubIdx = 1 + reqGetConstIntegerExpr(0, sub.arrayLen - 1);
			req(']');
		}
		req('.');
		KNode memb;
		string mname = reqIdent;
		foreach(m; sub.kids){
			if(m.name == mname) memb = m;
		}
		if(!memb)err("Unknown subunit member");
		symbol = memb;
	}

	if(KVar var = cast(KVar)symbol){
		pt.var = var;
		pt.finalTyp = var.typ;
		if(var.typ.kind == KTyp.EKind.karray){
			if(peek('[')){
				pt.arrVarIdx = 1 + reqGetConstIntegerExpr(0, var.typ.size - 1);
				pt.finalTyp = var.typ.base;
				req(']');
			}
		}
		if(isDest){
			if(var.Is.readOnly)err("Readonly endpoint");
			if(var.writer) err("Var already written elsewhere");
			var.writer = node;
		} 
	}else if(KClock clk = cast(KClock)symbol){
		pt.clk = clk;
		pt.finalTyp = g_specTypKClock;
		if(isDest && !pt.sub) err("Read-only clock");
		if(!isDest && pt.sub) err("Write-only clock");
	}else{
		err("Unhandled symbol type for links");
	}

	return pt;
}
