module parser.expr;
import common;
import std.conv;
// import parser.stmt;


struct XOffset{
	KExpr arg; // dynamic offset. idx=0
	int idx;  // constant offset. arg=null
};


/* FIXME: switch to these new ones
class KArg2{
	KTyp finalTyp;
	XOffset[] offsets;

	void printVHDL(){	errInternal; }
}

class KArgVar : KArg2{
	KVar var;
}
class KArgSubuPort : KArg2{
	KSubUnit sub;
}*/


class KArg{
	KVar var;
	KHandle obj;
	KMethod call;
	KTyp finalTyp;
	XOffset[] offsets;
	KExpr[] callArgs;

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
	off = ReadXOffset(dummyNode);
	
	if(off.arg) err("Constant integer expression required");
	
	if(off.idx < imin || off.idx > imax){
		err("Value out of acceptable range [", imin, ":", imax, "]", imin, imax);
	}
	return off.idx;
}


void ReadExtraOffsets(KArg arg, KNode node, bool isDest){
	for(;;){
	
		if(peek('.')){
			XOffset off;
			if(arg.finalTyp.kind == KTyp.EKind.kstruct){
				KVar memb = ReqGetStructMemberIdx(arg.finalTyp, off.idx);
				arg.offsets ~= off;
				arg.finalTyp = memb.typ;
			}else{
				err("operator '.' accepts only structures");
			}
		}else if(peek('[')){
			XOffset off;
			if(arg.finalTyp.kind == KTyp.EKind.karray){
				notImplemented;
			}else if(arg.finalTyp.kind == KTyp.EKind.kvec){
				if(arg.finalTyp.size == 1)err("Cannot slice a single bit");
				XOffset bitOffs={null,0};
				XOffset bitSize={null,1};
				bitOffs = ReadXOffset(node);
				if(peek(',')){
					bitSize = ReadXOffset(node);
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
}

KArg ReadArg_Var(KVar var, KNode node, bool isDest){
	KArg arg = new KArg;
	arg.var = var;
	arg.finalTyp = var.typ;

	if(isDest){
		UpdateVarWriter(var, node);
	}else{
		if(var.Is.writeOnly)err("Write-only variable");
		var.Is.everRead = 1;
	}

	ReadExtraOffsets(arg, node, isDest);

	return arg;
	
	//KVar fvar = var; // final var
	
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
}

KArg ReadArg_Handle(KHandle obj, KNode node, bool isDest){
	XOffset offs;
	KArg arg = new KArg;
	arg.obj = obj;

	if(obj.isArray){
		req('[');
		offs = ReadXOffset(node);
		req(']');
	}
	arg.offsets ~= offs;

	req('.');
	string propName = reqIdent;

	XOffset memb;

	memb.idx = obj.getKid(propName);
	if(memb.idx < 0) err("Invalid property/function");
	arg.offsets ~= memb;

	KVar var = cast(KVar) obj.kids[memb.idx];
	if(var){
		arg.var = var;
		arg.finalTyp = var.typ;
		if(isDest && var.Is.readOnly) err("Cannot assign to a read-only variable");

		if(isDest){
			UpdateVarWriter(var, node);
		}else{
			if(var.Is.writeOnly)err("Write-only variable");
			var.Is.everRead = 1;
		}

		ReadExtraOffsets(arg, node, isDest);

	}else{
		KMethod met = cast(KMethod) obj.kids[memb.idx];
		if(!met) err("Invalid property/function");
		arg.call = met;
		notImplemented;
	}


	return arg;
}


//=======================================================


private{
	XOffset ReadXOffset(KNode node){
		XOffset res;
		res.idx = 0;
		res.arg = ReadExpr(node);
		if(res.arg.kind == KExpr.ESimple.knum){
			KExprNum en = cast(KExprNum)res.arg;
			res.idx = en.val;
			res.arg = null;
		}
		return res;
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
	
	KVar ReqGetStructMemberIdx(KNode struc, ref int resIdx){
		string mname = reqIdent;
		foreach(int midx, n; struc.kids){
			KVar v = cast(KVar)n; if(!v)continue;
			if(mname == v.name){
				resIdx = midx;
				return v;
			}
		}
		err("Unknown structure member");
		return null;
	}

	KExpr GetSingleExpr(KNode node) {
		switch(cc.typ){
			case TokTyp.ident:
			{
				string symName = reqIdent;
				KNode symbol = node.findNode(symName);
				KVar var = cast(KVar)symbol;
				if(var){
					KExprVar v = new KExprVar();
					v.arg = ReadArg_Var(var, node, false);
					v.finalTyp = v.arg.finalTyp;
					return v;
				}
				KHandle obj = cast(KHandle)symbol;
				if(obj){
					KExprVar v = new KExprVar;
					v.arg = ReadArg_Handle(obj, node, false);
					v.finalTyp = v.arg.finalTyp;
					return v;
				}
				err("Expected a variable or object");
				return null;
			}
			case TokTyp.num:
			{
				KExprNum n = new KExprNum();
				n.val = to!int(cc.str);
				gtok;
				return n;
			}
			case '-':
			{
				KExprUnary u = new KExprUnary();
				u.uniOp = cc.typ;
				gtok;
				return u;
			}
			case '(':
			{
				gtok;
				KExpr sub = ReadExpr(node);
				req(')');
				if(cc.typ=='.'){
					notImplemented;
				}
				return sub;
			}
			default:
				err("Invalid source");
		}
		return null;
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

KExpr ReadExpr(KNode node) {
	int	sp = 0;
	string[9] ops;
	KExpr v;
	KExpr[10] vals;
	
	vals[0] = GetSingleExpr(node);
	while (GetPrec(cc.str) >= 0) {
		while (sp > 0 && GetPrec(cc.str) <= GetPrec(ops[sp-1])) {
			HandleOp(node, ops[sp-1], v, vals[sp-1], vals[sp]);
			vals[--sp] = v;
		}
		ops[sp++] = cc.str;
		gtok;
		vals[sp] = GetSingleExpr(node);
	}
	while (sp > 0) {
		KExpr v2;
		HandleOp(node, ops[sp-1], v2, vals[sp-1], vals[sp]);
		vals[--sp] = v2;
	}
	return vals[0];
}

