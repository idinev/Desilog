module nodes.kvar;
import common;




class KVar : KNode{
	KTyp typ;
	EStor storage;
	string clock;
	Token[] reset;
	VarFlags Is;
	KNode writer;
	//KExpr resetExpr; FIXME re-add
	
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
	}
}

KVar reqFindVar(KNode node, string name){
	KVar v = node.findNode!KVar(name);
	if(!v) err("Cannot find variable");
	return v;
}

