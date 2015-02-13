module nodes.kvar;
import common;




class KVar : KNode{
	//string typName;
	KTyp typ;
	EStor storage;
	string clock;
	Token[] reset;
	VarFlags Is;
	//KNode writer;
	//KExpr resetExpr;
	
	enum EStor{
		kinvalid,
		kreg,
		kwire,
		klatch,
		//kclock,
		kvar,
		//ksubu,
		//kfifo,
		//kram,
		//krom
	}
	
	struct VarFlags{
		bool isIn;
		bool isOut;
		bool port;
		bool signal;
		bool readOnly;
		bool writeOnly;
		bool everRead;
	}
}

KVar FindVar(KNode node, string name){
	KNode n = node.findNode(name);
	if(!n) err("Cannot find variable");
	KVar v = cast(KVar)n;
	if(!v) err("Identifier is not a valid variable");
	return v;
}

