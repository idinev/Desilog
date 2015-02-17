module parser.expr;
import common;
import std.conv;
// import parser.stmt;



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
	
	if(off.exp) err("Constant integer expression required");
	
	if(off.idx < imin || off.idx > imax){
		err("Value out of acceptable range [", imin, ":", imax, "]", imin, imax);
	}
	return off.idx;
}


//=======================================================


private{

	KExpr GetSingleExpr(KNode node) {
		switch(cc.typ){
			case TokTyp.ident:
			{
				string symName = reqIdent;
				KNode symbol = node.findNode(symName);
				if(!symbol) err("Unknown symbol");

				KExprVar v = new KExprVar();
				v.arg = ReadArg(symbol, node, false);
				v.finalTyp = v.arg.finalTyp;
				return v;
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

