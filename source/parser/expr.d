module parser.expr;
import common;
import std.conv;
// import parser.stmt;



class KExpr{
	KTyp finalTyp;

};

class KExprNum : KExpr{
	ulong val;
	int minBits;
};
class KExprSizNum : KExprNum{
	int numBits;
}

class KExprVar : KExpr{
	KArg arg;
};

class KExprUnary : KExpr{
	int uniOp;
	KExpr x;
};

class KExprBin : KExpr{
	string binOp;
	KExpr x;
	KExpr y;
};

class KExprCmp : KExpr{
	string cmpOp;
	KExpr x;
	KExpr y;
}

class KExprCast : KExpr{
	KArg arg;
	string casterFuncName;
}

class KExprEnumMemb : KExpr{
	int eidx; 
}



int reqGetConstIntegerExpr(int imin, int imax, bool limit = true){
	XOffset off;
	KNode dummyNode = new KNode;
	off = ReadXOffset(dummyNode);
	
	if(off.exp) err("Constant integer expression required");

	if(limit && (off.idx < imin || off.idx > imax)){
		err("Value out of acceptable range [", imin, ":", imax, "]", imin, imax);
	}
	return off.idx;
}

KExprNum makeExprNum(ulong value){
	KExprNum n = new KExprNum();
	n.val = value;
	n.minBits = minBitsNecessary(value);
	return n;
}



//=======================================================

private{
	// Built-in expressions
	KExpr BuiltinExpr_sizeof(KNode node){
		req('(');
		KTyp typ = reqTyp(node);
		req(')');
		return makeExprNum(calcTypSizeInBits(typ));
	}
	KExpr BuiltinExpr_lengthof(KNode node){
		req('(');
		KTyp typ = reqTyp(node);
		req(')');
		return makeExprNum(calcTypArrayLength(typ));
	}
	KExpr BuiltinExpr_cast(KNode node){
		KExprCast cc = new KExprCast;
		req('(');
		cc.finalTyp = reqTyp(node);
		req(')');
		string argName = reqIdent;
		cc.arg = reqReadArg(argName, node, false);
		cc.casterFuncName = makeCasterFunc(node, cc.finalTyp, cc.arg.finalTyp);
		return cc;
	}

	KExpr BuiltinExpr_Typ(KNode node, KTyp typ){
		if(typ.kind == KTyp.EKind.kenum){
			auto e = new KExprEnumMemb;
			e.finalTyp = typ;
			req('.');
			e.eidx = ReqReadEnumValue(typ, false);
			return e;
		}else{
			err("Unhandled type as expression. Only enums allowed");
		}
		return null;
	}
}

//=======================================================


private{


	KExpr GetSingleExpr(KNode node) {
		switch(cc.typ){
			case TokTyp.ident:
			{
				string symName = reqIdent;
				switch(symName){
					case "sizeof":		return BuiltinExpr_sizeof(node);
					case "lengthof":	return BuiltinExpr_lengthof(node);
					case "cast":		return BuiltinExpr_cast(node);
					default:
					{
						KNode symbol = node.findNode(symName);
						if(!symbol) err("Unknown symbol: ", symName);
						if(auto typ = cast(KTyp)symbol) return BuiltinExpr_Typ(node, typ);

						KExprVar v = new KExprVar();
						v.arg = ReadArg(symbol, node, false);
						v.finalTyp = v.arg.finalTyp;
						return v;
					}
				}
			}
			case TokTyp.num:
			{
				NumToken nt = cast(NumToken)cc;
				KExprNum n = new KExprNum();
				n.val = nt.value;
				n.minBits = nt.minBits;
				gtok;
				return n;
			}
			case TokTyp.siznum:
			{
				NumToken nt = cast(NumToken)cc;
				KExprSizNum n = new KExprSizNum();
				n.val = nt.value;
				n.minBits = nt.minBits;
				n.numBits = nt.numBits;
				n.finalTyp = getCustomSizedVec(nt.numBits);
				gtok;
				return n;
			}
			case '-':
			case '!':
			case '~':
			{
				KExprUnary u = new KExprUnary();
				u.uniOp = cc.typ;
				gtok;
				u.x = ReadExpr(node);
				u.finalTyp = u.x.finalTyp;
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

	ulong ReduceConstExpr(string op, ulong a, ulong b){
		switch(op){
			case "-": return a-b;
			case "+": return a+b;
			case "*": return a*b;
			case "/":	if(b==0)err("Division by zero"); return a/b;
			case "&": return a & b;
			case "^": return a ^ b;
			case "|": return a | b;

			case "==":	return a == b;
			case "!=":	return a != b;
			case "<":	return a <  b;
			case ">":	return a >  b;
			case "<=":	return a <= b;
			case ">=":	return a >= b;
			default: errInternal;
		}
		return 0;
	}

	KExprNum ReduceConstExprToKExpr(string op, ulong a, ulong b){
		KExprNum n = new KExprNum;
		n.val = ReduceConstExpr(op, a, b);
		n.minBits = minBitsNecessary(n.val);
		return n;
	}

	bool IsVectorTyp(KExpr e){
		if(cast(KExprNum)e) return true;
		if(!e.finalTyp) return false;
		return e.finalTyp.kind == KTyp.EKind.kvec;
	}
	bool IsSizedVectorTyp(KExpr e){
		if(cast(KExprSizNum)e) return true;
		if(!e.finalTyp) return false;
		return e.finalTyp.kind == KTyp.EKind.kvec;
	}

	void ReqIsVectorTyp(KExpr e){
		if(IsVectorTyp(e)) return;
		err("Vector or number required");
	}

	void ReqIsSizedVectorTyp(KExpr e){
		if(IsSizedVectorTyp(e)) return;
		err("Vector required");
	}

	bool IsSameVecSize(KExpr a, KExpr b){
		KExprNum c1 = cast(KExprNum)a;
		KExprNum c2 = cast(KExprNum)b;
		if(c1 && c2) return true;
		if(!c1 && !c2){
			return a.finalTyp.size == b.finalTyp.size;
		}
		if(c1 && !c2){
			return c1.minBits <= b.finalTyp.size;
		}
		return c2.minBits <= a.finalTyp.size;
	}
	void ReqIsSameVecSize(KExpr a, KExpr b){
		ReqIsVectorTyp(a);
		ReqIsVectorTyp(b);
		if(IsSameVecSize(a, b)) return;
		err("Vector sizes don't match");
	}


	KExpr HandleOp(KNode node, string op, KExpr v1, KExpr v2) {
		KExprNum c1 = cast(KExprNum)v1;
		KExprNum c2 = cast(KExprNum)v2;

		switch(op){
			case "-":
			case "+":
			case "&":
			case "^":
			case "|":
			{
				ReqIsSameVecSize(v1,v2);
				if(c1 && c2){
					return ReduceConstExprToKExpr(op, c1.val,c2.val);
				}

				KExprBin b = new KExprBin;
				b.binOp = op;
				b.x = v1;
				b.y = v2;
				if(v1.finalTyp) b.finalTyp = v1.finalTyp;
				if(v2.finalTyp) b.finalTyp = v2.finalTyp;
				return b;
			}
			case "==":
			case "!=":
			case "<":
			case ">":
			case "<=":
			case ">=":
			{
				ReqIsSameVecSize(v1,v2);

				if(c1 && c2){
					return ReduceConstExprToKExpr(op, c1.val,c2.val);
				}
				KExprCmp cm = new KExprCmp;
				cm.cmpOp = op;
				cm.x = v1;
				cm.y = v2;
				cm.finalTyp = getCustomSizedVec(1);
				return cm;
			}
			case "*":
			case "/":
			{
				ReqIsVectorTyp(v1);
				ReqIsVectorTyp(v2);
				if(c1 && c2){
					return ReduceConstExprToKExpr(op, c1.val,c2.val);
				}

				ReqIsSizedVectorTyp(v1);
				ReqIsSizedVectorTyp(v2);

				KExprBin b = new KExprBin;
				b.binOp = op;
				b.x = v1;
				b.y = v2;
				if(op=="*"){
					b.finalTyp = getCustomSizedVec(v1.finalTyp.size + v2.finalTyp.size);
				}else{
					notImplemented;
				}
				return b;
			}
			case "~":
			{
				ReqIsSizedVectorTyp(v1);
				ReqIsSizedVectorTyp(v2);

				KExprBin b = new KExprBin;
				b.binOp = op;
				b.x = v1;
				b.y = v2;
				b.finalTyp = getCustomSizedVec(v1.finalTyp.size + v2.finalTyp.size);
				return b;
			}
			default:
				err("Unknown operator");
		}
		return null;
	}

	int GetPrec(string op){
		switch(op){
			case "/":  return 7;
			case "*":  return 7;
			case "%":  return 7;
			case "+":  return 6;
			case "-":  return 6;
			case "~":  return 6;
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
	KExpr[10] vals;
	
	vals[0] = GetSingleExpr(node);
	while (GetPrec(cc.str) >= 0) {
		while (sp > 0 && GetPrec(cc.str) <= GetPrec(ops[sp-1])) {
			KExpr v = HandleOp(node, ops[sp-1], vals[sp-1], vals[sp]);
			vals[--sp] = v;
		}
		ops[sp++] = cc.str;
		gtok;
		vals[sp] = GetSingleExpr(node);
	}
	while (sp > 0) {
		KExpr v2 = HandleOp(node, ops[sp-1], vals[sp-1], vals[sp]);
		vals[--sp] = v2;
	}
	return vals[0];
}

