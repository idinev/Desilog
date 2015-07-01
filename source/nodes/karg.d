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

class KArgObjDat : KArg{
	XOffset arrIdx;
	KVar var;

	void setup(ref AHanAccess acc){
		arrIdx = acc.arrIdx;
		var = acc.var;
		finalTyp = acc.finalTyp;
	}

	override void onWrite(){
		OnVarWrite(var, proc);
	}
	override void onRead(){
		OnVarRead(var, proc);
	}
}
class KArgObjMethod : KArg{
	XOffset arrIdx;
	KMethod method;
	KExpr[] methodArgs;

	void setup(ref AHanAccess acc){
		arrIdx = acc.arrIdx;
		method = acc.method;
		methodArgs = acc.methodArgs;
		finalTyp = acc.finalTyp;
	}

}

class KArgSubuPort : KArgObjDat{
	KSubUnit sub;

}
class KArgRAMDat : KArgObjDat{
	KRAM ram;
	int portIdx;
}
class KArgFuncCall : KArg{
	KFunc func;
	KExpr[] args;
}

class KArgClockDat : KArgObjDat{

}


private{

	struct AHanAccess{
		XOffset arrIdx;
		KTyp finalTyp;
		KVar var;
		KMethod method;
		KExpr methodArgs[];
	}

	AHanAccess ReadArg_AHanAccess(KHandle handle, KNode node, bool isDest){
		AHanAccess res;
		if(handle.isArray){
			req('[');
			res.arrIdx = ReadXOffset(node);
			if(res.arrIdx.idx < 0 || res.arrIdx.idx >= handle.arrayLen){
				err("Index out of bounds");
			}
			req(']');
		}
		req('.');
		KNode memb;
		string mname = reqIdent;
		foreach(m; handle.kids){
			if(m.name == mname) memb = m;
		}
		if(!memb)err("Unknown method/member");
		if(KVar var = cast(KVar)memb){
			res.var = var;
			res.finalTyp = var.typ;
			if(var.Is.readOnly && isDest)err("Member is read-only");
			if(var.Is.writeOnly && !isDest) err("Member is write-only");
		}else if(KMethod met = cast(KMethod)memb){
			res.method = met;
			res.finalTyp = met.retTyp;
			if(!met.retTyp && !isDest)err("Method has no return data");
			req('(');
			foreach(int i, arg; met.argTyps){
				if(i)req(',');
				res.methodArgs ~= ReadExpr(node);
			}
			req(')');
		}else{
			errInternal;
		}

		return res;
	}



	KArg ReadArg_SubUnit(KSubUnit sub, KNode node, KScope proc, bool isDest){
		AHanAccess acc = ReadArg_AHanAccess(sub, node, isDest);

		if(acc.var){
			KArgSubuPort subPort = new KArgSubuPort;
			subPort.setup(acc);
			subPort.sub = sub;
			return subPort;
		}else{
			errInternal;
		}
		return null;
	}

	KArg ReadArg_Clock(KClock clk, KNode node, KScope proc, bool isDest){
		AHanAccess acc = ReadArg_AHanAccess(clk, node, isDest);
		assert(!isDest); // above func should have thrown exception
		if(acc.var){
			auto cdat = new KArgClockDat;
			cdat.setup(acc);
			return cdat;
		}else{
			errInternal;
		}

		return null;
	}

	KArg ReadArg_RAM(KRAM ram, KNode node, KScope proc, bool isDest){
		AHanAccess acc = ReadArg_AHanAccess(ram, node, isDest);

		if(acc.var){
			KArgRAMDat rdat = new KArgRAMDat;
			rdat.setup(acc);
			rdat.ram = ram;
			if(acc.var.name == "data1")  rdat.portIdx = 1;
			return rdat;
		}else{
			errInternal;
		}

		return null;
	}

	KArg ReadArg_Func(KFunc func, KNode node, KScope proc, bool isDest){
		if(isDest)err("Function results cannot be ignored");

		auto res = new KArgFuncCall;
		res.func = func;
		res.finalTyp = func.typ;
		req('(');
		foreach(int i, arg; func.args){
			if(i)req(',');
			res.args ~= ReadExpr(node);
		}
		req(')');
		return res;
	}
}



KArg ReadArg(KNode symbol, KNode node, bool isDest){
	KArg result;
	KScope proc = GetRootScope(node);
	if(KVar var = cast(KVar)symbol){
		KArgVar arg = new KArgVar;
		arg.var = var;
		arg.finalTyp = var.typ;
		result = arg;
	}else if(KSubUnit sub = cast(KSubUnit)symbol){
		result = ReadArg_SubUnit(sub, node, proc, isDest);
	}else if(KRAM ram = cast(KRAM)symbol){
		result = ReadArg_RAM(ram, node, proc, isDest);
	}else if(KFunc func = cast(KFunc)symbol){
		result = ReadArg_Func(func, node, proc, isDest);
	}else if(KClock clk = cast(KClock)symbol){
		result = ReadArg_Clock(clk, node, proc, isDest);
	}else{
		err("Unhandled symbol as statement");
	}

	result.proc = proc;
	result.isDest = isDest;

	if(result.finalTyp){
		ReadExtraOffsets(result, node, isDest);
	}

	if(isDest){
		result.onWrite();
	}else{
		result.onRead();
	}

	return result;
}

KArg reqReadArg(string symName, KNode node, bool isDest){
	KNode symbol = node.findNode(symName);
	if(!symbol) err("Unknown symbol: ", symName);

	return ReadArg(symbol, node, isDest);
}

XOffset ReadXOffset(KNode node){
	XOffset res;
	res.exp = ReadExpr(node);
	if(KExprNum en = cast(KExprNum)res.exp){
		res.idx = cast(int)en.val;
		res.exp = null;
	}
	return res;
}

KArg[] ReadFunctionArgs(KNode node, bool isDest = false){
	KArg[] res;
	for(;;){
		if(peek(')'))break;
		string symName = reqIdent;
		KArg arg = reqReadArg(symName, node, isDest);
		res ~= arg;
		if(peek(')'))break;
		req(',');
	}
	return res;
}

KScope GetRootScope(KNode node){
	KNode found = null;
	for(KNode n = node; n; n = n.parent){
		if(cast(KScope)n){
			found = n;
		}
	}
	return cast(KScope)found;
}

KScope reqGetRootScope(KNode node){
	KScope found = GetRootScope(node);
	if(!found) err("Node is not in a process/scope");
	return found;
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

		if(reader && !reader.varsRead.canFind(var)){
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
