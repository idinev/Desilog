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

class KCasterFunc : KNode{
	KTyp dstTyp, srcTyp;
}

string makeCasterFuncName(KTyp dst, KTyp src){
	string casterFuncName = "dg_cast_" ~ mangledName(dst) ~ 
		"_from_" ~ mangledName(src);
	return casterFuncName;
}

string makeCasterFunc(KNode node, KTyp dst, KTyp src){
	string casterFuncName = makeCasterFuncName(dst, src);
	
	if(node.findNodeOfKind!KCasterFunc(casterFuncName)) return casterFuncName;
	
	int dsiz = calcTypSizeInBits(dst);
	int ssiz = calcTypSizeInBits(src);
	if(dsiz < ssiz)err("Cast destination is smaller than source");
	
	static void preloadSubCasters(KNode node, KTyp arg, bool isDest){
		
		void makeCF(KTyp base){
			int siz = calcTypSizeInBits(base);
			KTyp vectyp = getCustomSizedVec(siz);
			if(isDest){
				makeCasterFunc(node, vectyp, base);
			}else{
				makeCasterFunc(node, base, vectyp);
			}
		}
		
		switch(arg.kind){
			case KTyp.EKind.karray:
				if(arg.base.kind != KTyp.EKind.kvec){
					makeCF(arg.base);
				}
				break;
			case KTyp.EKind.kstruct:
				foreach(KVar m; arg){
					if(m.typ.kind != KTyp.EKind.kvec){
						makeCF(m.typ);
					}
				}
				break;
			default: break;
		}
	}
	
	preloadSubCasters(node, dst, true);
	preloadSubCasters(node, dst, false);
	
	KScope root = reqGetRootScope(node);
	KNode hostNode = root.parent; // where we put the caster-func
	KCasterFunc cfunc = new KCasterFunc;
	cfunc.name = casterFuncName;
	cfunc.dstTyp = dst;
	cfunc.srcTyp = src;
	hostNode.addKid(cfunc);
	return casterFuncName;
}
