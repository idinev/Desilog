module nodes.karg;
import std.algorithm;
import common;

struct XOffset{
	KVar sMember; // struct member
	KExpr exp; // dynamic offset. idx=0
	int idx;  // constant offset. arg=null
	int bits; // if is a vector sub-slice
};


class KArg{
	KTyp finalTyp;
	XOffset[] offsets;
	KScope proc;
	bool isDest;

	void onWrite(){}
	void onRead(){}
}

class KArgVar : KArg{
	KVar var;

	override void onWrite(){
		OnVarWrite(var, proc);
	}
	override void onRead(){
		OnVarRead(var, proc);
	}
}

class KArgSubuPort : KArg{
	KSubUnit sub;

	XOffset arrIdx;
	KVar port;

	override void onWrite(){
		OnVarWrite(port, proc);
	}
	override void onRead(){
		OnVarRead(port, proc);
	}
}

class KArgCall : KArg{
	XOffset funcArgs[];
}


KArg ReadArg(KNode symbol, KNode node, bool isDest){
	KArg result;
	if(KVar var = cast(KVar)symbol){
		KArgVar arg = new KArgVar;
		arg.var = var;
		arg.finalTyp = var.typ;
		result = arg;
	}else if(KSubUnit sub = cast(KSubUnit)symbol){
		XOffset arrIdx;

		if(sub.isArray){
			req('[');
			arrIdx = ReadXOffset(node);
			req(']');
		}
		req('.');
		KNode memb;
		string mname = reqIdent;
		foreach(m; sub.kids){
			if(m.name == mname) memb = m;
		}

		if(KVar port = cast(KVar)memb){
			KArgSubuPort subPort = new KArgSubuPort;
			subPort.sub = sub;
			subPort.arrIdx = arrIdx;
			subPort.port = port;
			subPort.finalTyp = port.typ;
			result = subPort;
		}else{
			err("Unknown port");
		}
	}else{
		err("Unhandled symbol as statement");
	}

	result.proc = reqGetRootScope(node);
	result.isDest = isDest;

	if(isDest){
		result.onWrite();
	}else{
		result.onRead();
	}

	if(result.finalTyp){
		ReadExtraOffsets(result, node, isDest);
	}
	return result;
}

XOffset ReadXOffset(KNode node){
	XOffset res;
	res.exp = ReadExpr(node);
	if(res.exp.kind == KExpr.ESimple.knum){
		KExprNum en = cast(KExprNum)res.exp;
		res.idx = en.val;
		res.exp = null;
	}
	return res;
}

private{
	void ReadExtraOffsets(KArg arg, KNode node, bool isDest){
		for(;;){
			
			if(peek('.')){
				if(arg.finalTyp.kind == KTyp.EKind.kstruct){
					XOffset off;
					off.sMember = reqGetStructMember(arg.finalTyp);
					arg.offsets ~= off;
					arg.finalTyp = off.sMember.typ;
				}else{
					err("operator '.' accepts only structures");
				}
			}else if(peek('[')){
				if(arg.finalTyp.kind == KTyp.EKind.karray){
					XOffset off = ReadXOffset(node);
					arg.offsets ~= off;
				}else if(arg.finalTyp.kind == KTyp.EKind.kvec){
					if(arg.finalTyp.size == 1)err("Cannot slice a single bit");
					XOffset bitOffs;
					bitOffs = ReadXOffset(node);
					if(peek(',')){
						XOffset bitSize = ReadXOffset(node);
						if(bitSize.exp) err("Slice size must be constant");
						if(bitSize.idx < 1 || bitSize.idx > arg.finalTyp.size) err("Slice size out of bounds");
						bitOffs.bits = bitSize.idx;
					}else{
						bitOffs.bits = 1;
					}
					req(']');

					// FIXME: more negative checking

					arg.offsets ~= bitOffs;
					arg.finalTyp = getCustomSizedVec(bitOffs.bits);
				}else{
					err("operator '[] accepts only arrays or vectors");
				}
			}else{
				break;
			}
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
	
	void OnVarWrite(KVar var, KScope writer){
		if(var.Is.readOnly) err("Read-only variable");

		KScope prevWr = var.writer;
		if(prevWr && prevWr != writer){
			err("Signal already written in another process: ", prevWr.name);
		}
		var.writer = writer;

		if(KProcess process = cast(KProcess)writer){
			if(var.storage == KVar.EStor.kreg){
				if(var.clock != process.clk.name){
					err("Signal cannot be written in this process, "
						"as it uses a different clock: ", process.clk.name);
				}
			}
		}
	}
	void OnVarRead(KVar var, KScope reader){
		if(var.Is.writeOnly)err("Write-only variable");
		var.Is.everRead = true;

		if(!reader.varsRead.canFind(var)){
			reader.varsRead ~= var;
		}
	}

	KVar reqGetStructMember(KNode struc){
		string mname = reqIdent;
		foreach(KVar v; struc){
			if(mname == v.name) return v;
		}
		err("Unknown structure member");
		return null;
	}
}
