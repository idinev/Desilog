module nodes.ktyp;
import common;
import std.conv;

class KTyp : KNode{
	EKind kind;
	int size;
	KTyp base;
	
	
	enum EKind{
		kvec,
		karray,
		kstruct,
		kenum,
		//kenumEntry,
		kmethod
	}
}

KTyp[int] allCustomSizedVecs;
KTyp getCustomSizedVec(int siz){
	foreach(t; baseTyps){
		if(siz == t.size && t.kind == KTyp.EKind.kvec)return t;
	}
	KTyp t = allCustomSizedVecs.get(siz, null);
	if(t)return t;
	t = new KTyp;
	t.name="vec[" ~ to!string(siz) ~ "]";
	t.kind = KTyp.EKind.kvec;
	t.size = siz;
	return t;
}


KTyp reqTyp(KNode node){
	string name = reqIdent;

	if(name == "vec"){
		req('[');
		int siz = reqGetConstIntegerExpr(1, MAX_VEC_SIZE);
		req(']');
		return getCustomSizedVec(siz);
	}

	foreach(t; baseTyps){
		if(name == t.name)return t;
	}

	KTyp t = node.findNode!KTyp(name);
	if(t) return t;

	err("Cannot find type");
	return null;
}


class KMethod : KNode{
	KTyp[] argTyps;
	KTyp retTyp;
}


class KHandle : KNode{
	bool isArray;
	int arrayLen;

	final void addProp(string name, KTyp typ, bool readOnly){
		KVar p = new KVar;
		p.parent = this;
		p.name = name;
		p.typ = typ;
		p.Is.readOnly = readOnly;
		kids ~= p;
	}
}

class KClock : KHandle{
	this(){
		KTyp bit = getCustomSizedVec(1);
		addProp("clk", 	  bit, true);
		addProp("active", bit, true);
	}
}

class KEnumEntry : KNode{
}

void ReadVarDecls(KNode parent, KVar base){
	KTyp typ = reqTyp(parent);

	for(;;){
		KVar v = new KVar;
		v.readName(parent);
		v.typ = typ;
		v.storage	= base.storage;
		v.clock		= base.clock;
		v.Is		= base.Is;

		if(peek('=')){
			char lastChar;
			v.reset = reqTermRange(',', ';', lastChar);
			if(lastChar==';')return;
			continue;
		}
		if(peek(';'))return;
		req(',');
	}
}


void ReadScopedVarDecls(KNode parent, KVar base){
	req('{');
	for(;;){
		if(peek('}'))return;
		ReadVarDecls(parent, base);
	}
}

void ProcKW_Struct(KNode parent){
	KTyp str = new KTyp;
	str.readUniqName(parent);
	str.kind = KTyp.EKind.kstruct;

	KVar base = new KVar;

	ReadScopedVarDecls(str, base);
}

void ProcKW_Enum(KNode parent){
	KTyp enu = new KTyp;
	enu.readUniqName(parent);
	enu.kind = KTyp.EKind.kenum;

	req('{');
	for(;;){
		KEnumEntry e = new KEnumEntry;
		e.readName(enu);

		if(peek('}'))return;
		req(',');
	}
}

void ProcKW_Type(KNode parent){
	KTyp typ = new KTyp;
	typ.readUniqName(parent);
	typ.base = reqTyp(parent);
	typ.kind = KTyp.EKind.karray;
	if(peek('[')){
		typ.size = reqGetConstIntegerExpr(1, MAX_ARRAY_SIZE);
		req(']');
	}else{
		// is an alias, copy contents instead
		typ.kind = typ.base.kind;
		typ.size = typ.base.size;
		typ.base = null;
	}
	req(';');
}

void ProcKW_Unit_Reg(KUnit parent){
	KVar base = new KVar;
	base.storage = KVar.EStor.kreg;
	req('<');	base.clock = reqIdent; req('>');

	ReadScopedVarDecls(parent, base);
}

void ProcKW_Unit_WireOrLatch(KUnit parent, bool isWire){
	KVar base = new KVar;
	base.storage = isWire ? KVar.EStor.kwire : KVar.EStor.klatch;

	ReadScopedVarDecls(parent, base);
}

void ProcKW_Intf_Clock(KIntf intf){
	KClock clk = new KClock;
	clk.readUniqName(intf);
	req(';');
}


void ProcKW_Intf_InOut(KIntf intf, bool isIn){
	KVar base = new KVar;
	base.Is.isIn = isIn;
	base.Is.isOut = !isIn;
	
	auto cases = ["reg", "wire", "latch"];
	switch(reqAmong(cases)){
		case "reg":	
			base.storage = KVar.EStor.kreg;
			req('<');	base.clock = reqIdent; req('>');
			ReadScopedVarDecls(intf, base);
			break;
		case "wire":
			base.storage = KVar.EStor.kwire;
			ReadScopedVarDecls(intf, base);
			break;
		case "latch":
			base.storage = KVar.EStor.klatch;
			ReadScopedVarDecls(intf, base);
			break;
		default: 		errInternal;
	}
}


private{
	KTyp makeBtinVec(int size, string name){
		KTyp t = new KTyp;
		t.name = name;
		t.kind = KTyp.EKind.kvec;
		t.size = size;
		return t;
	}
	
	KTyp[] baseTyps = [
		makeBtinVec(1, "bit"),
		makeBtinVec(2, "u2"),
		makeBtinVec(4, "u4"),
		makeBtinVec(8, "u8"),
		makeBtinVec(16,"u16"),
		makeBtinVec(32,"u32"),
		makeBtinVec(64,"u64"),
	];
}
