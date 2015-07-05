module nodes.kunit;
import common;
import std.conv;

// ==============================[ Intf ]=========================================================

class KEntity : KNode{
	KUnit unitImpl;
}




void ProcessKW_Entity(DPFile file){
	KEntity intf = new KEntity;
	intf.readUniqName(file);
	req('{');
	
	for(;;){
		auto cases = ["}", "clock","in","out"];
		switch(reqAmong(cases)){
			case "}":		return;
			case "clock":	ProcKW_Intf_Clock(intf); break;
			case "in":		ProcKW_Intf_InOut(intf, true); break;
			case "out":		ProcKW_Intf_InOut(intf, false); break;   
			default: 		errInternal;
		}
	}
}

// ==============================[ RAM ]=========================================================



class KRAM : KHandle{
	KTyp typ;
	KTyp addrTyp;
	int size;
	bool isRom;
	bool dual;
	bool regOut;
	KClock[2] clk;
	KScope[2] writer;
	KExpr[] romData;

	void populateProps(){
		int logSize = logNextPow2(size);
		addrTyp = getCustomSizedVec(logSize);
		KTyp bit = getCustomSizedVec(1);

		void addDualProp(bool dual, string name0, string name1, KTyp typ, bool readOnly){
			addProp(name0, typ, readOnly);
			if(dual) addProp(name1, typ, readOnly);
		}

		addDualProp(dual, "data0",  "data1",  typ, true);
		addDualProp(dual, "addr0",  "addr1",  addrTyp, false);
		if(!isRom){
			addDualProp(dual, "wdata0", "wdata1", typ, false);
			addDualProp(dual, "write0", "write1", bit, false);
		}
	}
}

static void ReadROMContents(KRAM rom){
	req('='); req('{');

	int idx = 0;
	for(;;idx++){
		rom.romData ~= ReadExpr(rom);
		if(peek('}'))break;
		req(',');
	}
}

void ProcKW_RAM(KUnit unit, bool isRom){
	KRAM ram = new KRAM;
	ram.isRom = isRom;

	if(peek("dual")){
		ram.dual = true;
	}
	req('<'); ram.clk[0] = reqNode!KClock(unit);
	if(ram.dual){
		req(',');
		ram.clk[1] = reqNode!KClock(unit); 
	}
	req('>');
	
	ram.typ = reqTyp(unit);
	ram.readUniqName(unit);
	req('[');
	ram.size = reqGetConstIntegerExpr(1,1024*1024*1024);
	req(']');
	if(ram.isRom){
		ReadROMContents(ram);
	}

	req(';');

	ram.populateProps();
}



// ==============================[ Sub-unit instance ]=======================================================

class KSubUnit : KHandle{
	KEntity intf;
	KClock srcClk; // belongs to parent
	KClock dstClk; // belongs to the sub-unit, is input
}
class KLink : KScope{
}

void ProcKW_SubUnit(KUnit unit){
	KSubUnit sub = new KSubUnit;

	if(peek('<')){
		sub.srcClk = reqNode!KClock(unit);
		req('>');
	}

	sub.intf = reqNode!KEntity(unit);
	sub.readName(unit);
	if(peek('[')){
		sub.isArray = true;
		sub.arrayLen = reqGetConstIntegerExpr(1,1024);
		req(']');
	}


	foreach(port; sub.intf.kids){
		if(auto v = cast(KVar)port){
			KVar p = copyVarFromSubu(v);
			p.handle = sub;
			sub.addKid(p);
		}else if(cast(KClock)port){
			KClock c = new KClock;
			c.name = port.name;
			sub.addKid(c);
		}else{
			errInternal;
		}
	}

	if(sub.srcClk){
		int numSubClocks = 0;
		foreach(KClock sclk; sub){
			numSubClocks++;
			if(!sub.dstClk)	sub.dstClk = sclk;
		}
		if(numSubClocks==0) err("Sub-unit interface doesn't have any clocks");

		RenameSubuInputPortClock(sub, sub.dstClk.name, sub.srcClk.name);
	}
	
	req(';');
}

void ProcKW_Link(KUnit unit){
	KLink link = new KLink;
	unit.addKid(link);
	link.curlyStart = reqTermCurly();
}


// ==============================[ Scope ]=========================================================

class KScope : KNode{
	IdxTok curlyStart;
	KStmt[] code;

	KVar[] varsRead;
	
	override void dump(int tab){
		super.dump(tab);
		foreach(k; code){
			foreach(i;0..tab+1) write("\t");
			writeln(k.classinfo);
		}
	}
}

class KProcess : KScope{
	KClock clk;
}
class KCombi : KScope{
}
class KTBForcer : KScope{

}

void ProcKW_OnClock(KUnit unit){
	KProcess proc = new KProcess;
	req('<');	proc.clk = reqNode!KClock(unit);	req('>');
	proc.readUniqName(unit);
	proc.curlyStart = reqTermCurly();
}

void ProcKW_Combi(KUnit unit){
	KCombi comb = new KCombi;

	// compose unique name
	int numCombi = 1;
	foreach(KCombi c; unit) numCombi++;
	comb.name = "dg_comb_proc" ~ to!string(numCombi);

	unit.addKid(comb);
	comb.curlyStart = reqTermCurly();
}

// ==============================[ UNIT ]=========================================================

class KUnit : KNode{
	KEntity entity;
}


void ProcKW_Unit(DPFile file){
	KUnit unit = new KUnit;
	string intfName = reqIdent;

	unit.entity = file.findNodeOfKind!KEntity(intfName);
	if(!unit.entity)err("Cannot find interface for this unit: ",intfName);
	if(unit.entity.unitImpl) err("Implementation of this interface already exists");
	unit.entity.unitImpl = unit; // pair-up
	file.addKid(unit);

	auto prevNodeWithDefs = g_curNodeWithDefs;
	g_curNodeWithDefs = unit;

	// copy variables/clocks/etc
	unit.kids ~= unit.entity.kids;

	req('{');
	
	for(;;){
		
		auto cases = [
			"reg", "wire", "latch", "struct", "enum", "type", "define", "func", "on_clock", "combi", "link",
			"RAM", "ROM", "sub_unit"
		];

		if(peek('}'))break;

		switch(reqAmong(cases)){
			case "reg":			ProcKW_Unit_Reg(unit); break;
			case "wire":		ProcKW_Unit_WireOrLatch(unit, true); break;
			case "latch":		ProcKW_Unit_WireOrLatch(unit, false); break;
			case "on_clock":	ProcKW_OnClock(unit); break;
			case "combi":		ProcKW_Combi(unit); break;
			case "link":		ProcKW_Link(unit); break;
			case "struct":		ProcKW_Struct(unit); break;
			case "enum":		ProcKW_Enum(unit); break;
			case "type":		ProcKW_Type(unit); break;
			case "define":		ProcKW_Define(unit); break;
			case "func":		ProcKW_Func(unit); break;
			case "RAM":			ProcKW_RAM(unit, false);break;
			case "ROM":			ProcKW_RAM(unit, true);	break;
			case "sub_unit":	ProcKW_SubUnit(unit); break;
			default: 	errInternal;
		}
	}

	g_curNodeWithDefs = prevNodeWithDefs;
}
