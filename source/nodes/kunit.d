module nodes.kintf;
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
	int size;
	bool dual;
	KClock clk, clk2;
	KScope writer, writer2;
}

void ProcKW_RAM(KUnit unit){
	KRAM ram = new KRAM;

	if(peek("dual")){
		ram.dual = true;
	}
	req('<'); ram.clk = reqNode!KClock(unit);
	if(ram.dual){
		req(',');
		ram.clk2 = reqNode!KClock(unit); 
	}
	req('>');
	
	ram.typ = reqTyp(unit);
	ram.readUniqName(unit);
	req('[');
	ram.size = reqGetConstIntegerExpr(1,4*1024*1024);
	req(']');
	req(';');
}





// ==============================[ Sub-unit instance ]=======================================================

class KSubUnit : KHandle{
	KIntf intf;
}
class KLink : KNode{
	IdxTok curlyStart;
}

void ProcKW_SubUnit(KUnit unit){
	KSubUnit sub = new KSubUnit;
	sub.intf = reqNode!KIntf(unit);
	sub.readName(unit);
	if(peek('[')){
		sub.isArray = true;
		sub.arrayLen = reqGetConstIntegerExpr(1,1024);
		req(']');
	}
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

void ProcKW_OnClock(KUnit unit){
	KProcess proc = new KProcess;
	proc.readUniqName(unit);
	req('<');	proc.clk = reqNode!KClock(unit);	req('>');
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

	// copy variables/clocks/etc
	unit.kids ~= unit.intf.kids;

	req('{');
	
	for(;;){
		
		auto cases = [
			"}", "reg", "wire", "latch", "struct", "enum", "type", "on_clock", "link",
			"RAM", "sub_unit"
		];
		switch(reqAmong(cases)){
			case "}":	return;
			case "reg":			ProcKW_Unit_Reg(unit); break;
			case "wire":		ProcKW_Unit_WireOrLatch(unit, true); break;
			case "latch":		ProcKW_Unit_WireOrLatch(unit, false); break;
			case "on_clock":	ProcKW_OnClock(unit); break;
			case "link":		ProcKW_Link(unit); break;
			case "struct":		ProcKW_Struct(unit); break;
			case "enum":		ProcKW_Enum(unit); break;
			case "type":		ProcKW_Type(unit); break;
			case "RAM":			ProcKW_RAM(unit);	break;
			case "sub_unit":	ProcKW_SubUnit(unit); break;
			default: 	errInternal;
		}
	}
}