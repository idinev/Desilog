module parser.expr;
import common;
import std.conv;
// import parser.stmt;


struct XOffset{
	KExpr arg; // dynamic offset. idx=0
	int idx;  // constant offset. arg=null
};

class KArg{
	KVar var;
	KTyp finalTyp;
	XOffset[] offsets;

	bool isStaticVec() const{
		if(finalTyp.kind != KTyp.EKind.kvec)return false;
		foreach(ref item; offsets){
			if(item.arg) return false;
		}
		return true;
	}

	//final void read(KNode node, bool isDest);
};

class KExpr{
	KTyp finalTyp;

	enum ESimple{
		kcomplex,
		knum,
		kvar,
		kenum
	};

	ESimple kind = ESimple.kcomplex;
	


};

class KExprNum : KExpr{
	int val;
	this(){ kind = ESimple.knum;}
};

class KExprVar : KExpr{
	KArg arg;
	this(){ kind = ESimple.kvar;}
};

class KExprUnary : KExpr{
	int uniOp;
};

class KExprBin : KExpr{
	string binOp;
	KExpr x;
	KExpr y;
};




int reqGetConstIntegerExpr(int imin, int imax){
	XOffset off;
	KNode dummyNode = new KNode;
	ReadXOffset(dummyNode, off);
	
	if(off.arg) err("Constant integer expression required");
	
	if(off.idx < imin || off.idx > imax){
		err("Value out of acceptable range [", imin, ":", imax, "]", imin, imax);
	}
	return off.idx;
}


KArg ReadArg_Var(KVar var, KNode node, bool isDest){
	KArg arg = new KArg;
	arg.var = var;
	arg.finalTyp = var.typ;
	
	KVar fvar = var; // final var
	
	/*if(fvar.Is.handle){   FIXME restore
		XOffset arrIdx={null,0};
		XOffset membIdx={null,0};
		gtok;
		if(var.Is.handleArray){
			reqTok('[');gtok;
			ReadXOffset(node, arrIdx);
			reqTok(']');gtok;
		}
		reqTok('.'); gtok;
		ReqGetStructMemberIdx(var.handle, membIdx.idx, fvar);
		finalTyp = fvar.typ;
		offsets.append(membIdx);
		offsets.append(arrIdx); //always add the unit-offset
	}*/
	
	if(isDest){
		UpdateVarWriter(fvar, node);
	}else{
		if(var.Is.writeOnly)err("Write-only variable");
		var.Is.everRead = 1;
	}
	
	for(;;){
		gtok;
		XOffset off={null,0};
		
		if(cc.typ == TokTyp.ident){
			err("identifiers disallowed after variable-usage. Expected an operator instead");
		}else if(cc.typ=='.'){
			if(arg.finalTyp.kind == KTyp.EKind.kstruct){
				gtok; reqIdent;
				KVar memb;
				ReqGetStructMemberIdx(arg.finalTyp, off.idx, memb);
				arg.offsets ~= off;
				arg.finalTyp = memb.typ;
			}else{
				err("operator '.' accepts only structures");
			}
		}else if(cc.typ=='['){
			if(arg.finalTyp.kind == KTyp.EKind.karray){
				notImplemented;
			}else if(arg.finalTyp.kind == KTyp.EKind.kvec){
				if(arg.finalTyp.size == 1)err("Cannot slice a single bit");
				XOffset bitOffs={null,0};
				XOffset bitSize={null,1};
				gtok;
				ReadXOffset(node, bitOffs);
				if(peek(',')){
					gtok;
					ReadXOffset(node, bitSize);
				}
				req(']');
				
				if(bitSize.arg) err("Slice size must be constant");
				if(bitSize.idx < 1 || bitSize.idx > arg.finalTyp.size) err("Slice size out of bounds");
				// FIXME: more negative checking
				
				arg.offsets ~= bitOffs;
				arg.offsets ~= bitSize;
				arg.finalTyp = getCustomSizedVec(bitSize.idx);
			}else{
				err("operator '[] accepts only arrays or vectors");
			}
		}else{
			break;
		}
	}
	return arg;
}



//=======================================================


private{
	void ReadXOffset(KNode node, ref XOffset res){
		res.idx = 0;
		ReadExpr(node, res.arg);
		if(res.arg.kind == KExpr.ESimple.knum){
			KExprNum en = cast(KExprNum)res.arg;
			res.idx = en.val;
			res.arg = null;
		}
	}

	KScope reqGetRootScope(KNode node){
		KNode found = null;
		for(KNode n = node; n; n = n.parent){
			if(cast(KScope)n){
				found = n;
			}
		}
		if(!found) err("Node is not in a process/scope");
		return cast(KScope) found;
	}
	
	void UpdateVarWriter(KVar var, KNode curWriterChild){
		if(var.Is.readOnly) err("Read-only variable");
		KScope writer;
		KScope prevWr = var.writer;
		writer = reqGetRootScope(curWriterChild);
		if(prevWr && prevWr != writer){
			err("Signal already written in another process: ", prevWr.name);
		}
		KProcess proc = cast(KProcess)writer;
		if(proc){
			if(var.storage == KVar.EStor.kreg){
				if(var.clock != proc.clk.name){
					err("Signal cannot be written in this process, "
						"as it uses a different clock: ", proc.clk.name);
				}
			}
		}
		
		var.writer = writer;
	}
	
	void ReqGetStructMemberIdx(KNode struc, ref int resIdx, ref KVar resVar){
		string mname = reqIdent;
		int midx=0;
		
		
		foreach(n; struc.kids){
			KVar v = cast(KVar)n; if(!v)continue;
			if(mname == v.name){
				resIdx = midx;
				resVar = v;
				return;
			}
			midx++;
		}
		err("Unknown structure member");
	}

	void GetSingleExpr(KNode node, ref KExpr result) {
		switch(cc.typ){
			case TokTyp.ident:
			{
				KNode symbol = node.findNode(cc.str);
				if(typeid(symbol) == typeid(KVar)){
					KExprVar v = new KExprVar();
					v.arg = ReadArg_Var(cast(KVar)symbol, node, false);
					v.finalTyp = v.arg.finalTyp;
					result = v;
				}else{
					err("Expected a variable or object");
				}
				return;
			}
			case TokTyp.num:
			{
				KExprNum n = new KExprNum();
				n.val = to!int(cc.str);
				result = n;
				gtok;
				return;
			}
			case '-':
			{
				KExprUnary u = new KExprUnary();
				u.uniOp = cc.typ;
				result = u;
				gtok;
				return;
			}
			case '(':
				gtok;
				ReadExpr(node, result);
				req(')');
				if(cc.typ=='.'){
					notImplemented;
				}
				return;
			default:
				err("Invalid source");
		}
	}

	int ReduceConstExpr(string op, int a, int b){
		switch(op){
			case "-": return a-b;
			case "+": return a+b;
			case "*": return a*b;
			default:
				notImplemented;
		}
		return 0;
	}


	void HandleOp(KNode node, string op, ref KExpr dst, ref KExpr v1, ref KExpr v2) {
		int fv1, fv2;
		bool c1 = (v1.kind == KExpr.ESimple.knum);
		bool c2 = (v2.kind == KExpr.ESimple.knum);
		if(c1) fv1 = (cast(KExprNum)v1).val;
		if(c2) fv2 = (cast(KExprNum)v2).val;
		
		switch(op){
			case "-":
			case "+":
			case "*":
			{
				if(c1 && c2){
					KExprNum n = new KExprNum;
					n.val = ReduceConstExpr(op, fv1,fv2);
					dst = n;
					return;
				}
				KExprBin b = new KExprBin;
				b.binOp = op;
				b.x = v1;
				b.y = v2;
				dst = b;
				return;
			}
			default:
				err("Unknown operator");
		}
	}

	int GetPrec(string op){
		switch(op){
			case "&&": return 8;
			case "||": return 8;
			case "/":  return 7;
			case "*":  return 7;
			case "%":  return 7;
			case "+":  return 6;
			case "-":  return 6;
			case "<<": return 5;
			case ">>": return 5;
			case ">":  return 4;
			case ">=": return 4;
			case "<":  return 4;
			case "<=": return 4;
			case "==": return 3;
			case "!=": return 3;
			case "&":  return 2;
			case "^":  return 1;
			case "|":  return 0;
			default:   return -1;
		}
	}
}

void ReadExpr(KNode node, ref KExpr result) {
	int	sp = 0;
	string[9] ops;
	KExpr v;
	KExpr[10] vals;
	
	GetSingleExpr(node, vals[0]);
	while (GetPrec(cc.str) >= 0) {
		while (sp > 0 && GetPrec(cc.str) <= GetPrec(ops[sp-1])) {
			HandleOp(node, ops[sp-1], v, vals[sp-1], vals[sp]);
			vals[--sp] = v;
		}
		ops[sp++] = cc.str;
		gtok;
		GetSingleExpr(node, vals[sp]);
	}
	while (sp > 0) {
		KExpr v2;
		HandleOp(node, ops[sp-1], v2, vals[sp-1], vals[sp]);
		vals[--sp] = v2;
	}
	result = vals[0];
}

