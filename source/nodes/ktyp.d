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
	}
}

// global "KTyp" to be used as dummy-types of variables
__gshared KTyp g_specTypKClock = new KTyp;
__gshared KTyp g_specTypKRAM_1port = new KTyp;

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

KTyp getTyp(string name, KNode node){
	if(name == "vec"){
		req('[');
		int siz = reqGetConstIntegerExpr(1, MAX_VEC_SIZE);
		req(']');
		return getCustomSizedVec(siz);
	}
	
	foreach(t; baseTyps){
		if(name == t.name)return t;
	}
	
	KTyp t = node.findNodeOfKind!KTyp(name);
	return t;
}


KTyp reqTyp(KNode node){
	string name = reqIdent;
	KTyp t = getTyp(name, node);
	if(t)return t;

	err("Cannot find type");
	return null;
}

int calcTypSizeInBits(KTyp typ){
	switch(typ.kind){
		case KTyp.EKind.kvec:
			return typ.size;
		case KTyp.EKind.karray:
			return typ.size * calcTypSizeInBits(typ.base);
		case KTyp.EKind.kstruct:
			int siz = 0;
			foreach(KVar m; typ){
				siz += calcTypSizeInBits(m.typ);
			}
			return siz;
		case KTyp.EKind.kenum:
			return logNextPow2(cast(int)typ.kids.length);
		default:
			errInternal;
			return 0;
	}
}
int calcTypArrayLength(KTyp typ){
	switch(typ.kind){
		case KTyp.EKind.karray:
			return typ.size;
		case KTyp.EKind.kenum:
			return cast(int)typ.kids.length;
		default:
			err("Only arrays and enums have lengthof() value");
			return 0;
	}
}

string mangledName(KTyp typ){
	if(typ.kind == KTyp.EKind.kvec){
		return "vec" ~ to!string(typ.size);
	}else{
		return typ.name;
	}
}


class KMethod : KNode{
	KTyp[] argTyps;
	KTyp retTyp;
}


class KHandle : KNode{
	bool isArray;
	int arrayLen;

	bool isPort;
	bool isInPort;
	bool isOutPort;

	final void addProp(string name, KTyp typ, bool readOnly){
		KVar p = new KVar;
		p.parent = this;
		p.handle = this;
		p.name = name;
		p.typ = typ;
		p.Is.readOnly = readOnly;
		p.storage = KVar.EStor.kwire;
		kids ~= p;
	}
	final void addMethod(string name, KTyp[] args, KTyp res){
		KMethod m = new KMethod;
		m.name = name;
		m.argTyps = args;
		m.retTyp = res;
		kids ~= m;
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
	if(peek('{')){
		for(;;){
			if(peek('}'))return;
			ReadVarDecls(parent, base);
		}
	}else{
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
	base.Is.signal = true;
	base.storage = KVar.EStor.kreg;
	req('<');	base.clock = reqIdent; req('>');

	ReadScopedVarDecls(parent, base);
}

void ProcKW_Unit_WireOrLatch(KUnit parent, bool isWire){
	KVar base = new KVar;
	base.Is.signal = true;
	base.storage = isWire ? KVar.EStor.kwire : KVar.EStor.klatch;

	ReadScopedVarDecls(parent, base);
}

void ProcKW_Intf_Clock(KEntity intf){
	KClock clk = new KClock;
	clk.readUniqName(intf);
	clk.isPort = true;
	clk.isInPort = true;
	req(';');
}


void ProcKW_Intf_InOut(KEntity intf, bool isIn){
	KVar base = new KVar;
	base.Is.port = true;
	base.Is.isIn = isIn;
	base.Is.readOnly = isIn;
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
