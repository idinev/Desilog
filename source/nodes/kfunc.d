module nodes.kfunc;
import common;




class KFunc : KScope{
	KVar[] args;
	KTyp typ;
}


KVar[] ReadFunctionArgNames(KNode parent){
	KVar[] args;

	req('(');
	for(;;){
		if(peek(')'))break;
		KTyp typ = reqTyp(parent);
		
		for(;;){
			KVar v = new KVar;
			v.readName(parent);
			v.typ = typ;
			v.storage	= KVar.EStor.kvar;
			v.Is.readOnly = true;
			v.Is.funcArg = true;
			args ~= v;
			if(peek(','))continue;
			break;
		}
		if(peek(')'))break;
		req(';');
	}
	return args;
}

void ProcKW_Func(KNode parent){
	KFunc f = new KFunc;

	f.typ = reqTyp(parent);
	f.readUniqName(parent);
	f.args = ReadFunctionArgNames(f);

	f.curlyStart = reqTermCurly();
}
