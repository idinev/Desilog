module nodes.karg;
import common;

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

private{
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

}