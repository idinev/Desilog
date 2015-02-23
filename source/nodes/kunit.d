module nodes.kunit;
import common;

// ==============================[ Intf ]=========================================================

class KIntf : KNode{
	KUnit unitImpl;
}




void ProcessKW_Interface(DPFile file){
	KIntf intf = new KIntf;
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
	bool dual;
	KClock[2] clk;
	KScope[2] writer;

	void populateProps(){
		int logSize = logNextPow2(size);
		addrTyp = getCustomSizedVec(logSize);
		KTyp[] setAddrArgs = [addrTyp];
		KTyp[] writeArgs = [typ];
		if(dual){
			addProp("data0", typ, true);
			addProp("data1", typ, true);
			addMethod("setAddr0", setAddrArgs, null);
			addMethod("setAddr1", setAddrArgs, null);
			addMethod("write0", writeArgs, null);
			addMethod("write1", writeArgs, null);
		}else{
			addProp("data", typ, true);
			addMethod("setAddr", setAddrArgs, null);
			addMethod("write", writeArgs, null);
		}
	}
}

void ProcKW_RAM(KUnit unit){
	KRAM ram = new KRAM;

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
	ram.size = reqGetConstIntegerExpr(1,4*1024*1024);
	req(']');
	req(';');

	ram.populateProps();
}





// ==============================[ Sub-unit instance ]=======================================================

class KSubUnit : KHandle{
	KIntf intf;
	KClock srcClk;
	KClock dstClk;
}
class KLink : KNode{
	IdxTok curlyStart;
}

void ProcKW_SubUnit(KUnit unit){
	KSubUnit sub = new KSubUnit;

	if(peek('<')){
		sub.srcClk = reqNode!KClock(unit);
		req('>');
	}

	sub.intf = reqNode!KIntf(unit);
	sub.readName(unit);
	if(peek('[')){
		sub.isArray = true;
		sub.arrayLen = reqGetConstIntegerExpr(1,1024);
		req(']');
	}

	int numSubClocks = 0;
	foreach(KClock sclk; sub.intf){
		numSubClocks++;
		if(!sub.dstClk)	sub.dstClk = sclk;
	}

	if(sub.srcClk && numSubClocks==0) err("Sub-unit interface doesn't have any clocks");

	req(';');

	foreach(port; sub.intf.kids){
		if(cast(KVar)port){
			KVar v = cast(KVar)port;
			sub.addProp(v.name, v.typ, v.Is.isOut);
		}else if(cast(KClock)port){
			// nothing to do? FIXME
		}
	}
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
class KTBForcer : KScope{

}

void ProcKW_OnClock(KUnit unit){
	KProcess proc = new KProcess;
	req('<');	proc.clk = reqNode!KClock(unit);	req('>');
	proc.readUniqName(unit);
	proc.curlyStart = reqTermCurly();
}
// ==============================[ UNIT ]=========================================================

class KUnit : KNode{
	KIntf intf;
}


void ProcKW_Unit(DPFile file){
	KUnit unit = new KUnit;
	string intfName = reqIdent;

	unit.intf = file.findNodeOfKind!KIntf(intfName);
	if(!unit.intf)err("Cannot find interface for this unit");
	if(unit.intf.unitImpl) err("Implementation of this interface already exists");
	unit.intf.unitImpl = unit; // pair-up
	file.addKid(unit);

	auto prevNodeWithDefs = g_curNodeWithDefs;
	g_curNodeWithDefs = unit;

	// copy variables/clocks/etc
	unit.kids ~= unit.intf.kids;

	req('{');
	
	for(;;){
		
		auto cases = [
			"reg", "wire", "latch", "struct", "enum", "type", "define", "on_clock", "link",
			"RAM", "sub_unit"
		];

		if(peek('}'))break;

		switch(reqAmong(cases)){
			case "reg":			ProcKW_Unit_Reg(unit); break;
			case "wire":		ProcKW_Unit_WireOrLatch(unit, true); break;
			case "latch":		ProcKW_Unit_WireOrLatch(unit, false); break;
			case "on_clock":	ProcKW_OnClock(unit); break;
			case "link":		ProcKW_Link(unit); break;
			case "struct":		ProcKW_Struct(unit); break;
			case "enum":		ProcKW_Enum(unit); break;
			case "type":		ProcKW_Type(unit); break;
			case "define":		ProcKW_Define(unit); break;
			case "RAM":			ProcKW_RAM(unit);	break;
			case "sub_unit":	ProcKW_SubUnit(unit); break;
			default: 	errInternal;
		}
	}

	g_curNodeWithDefs = prevNodeWithDefs;
}
