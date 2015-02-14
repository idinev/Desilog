module nodes.kintf;
import common;

class KIntf : KNode{

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



class KUnit : KNode{
	KIntf intf;

	override KNode findImportedNode(string name){
		foreach(n; intf.kids){
			if(n.name == name) return n;
		}
		return null;
	}

}

class KRAM : KHandle{
	KTyp typ;
	int size;
	bool dual;
	KClock clk, clk2;
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

class KScope : KNode{
}

class KProcess : KScope{
	KClock clk;
}

void ProcKW_OnClock(KUnit unit){
	KProcess proc = new KProcess;
	proc.readUniqName(unit);
	req('<');	proc.clk = reqNode!KClock(unit);	req('>');
	proc.toks = reqTermCurly();

}

class KSubUnit : KNode{
	KIntf intf;
	int arrayLen;
}
class KLink : KNode{
}

void ProcKW_SubUnit(KUnit unit){
	KSubUnit sub = new KSubUnit;
	sub.intf = reqNode!KIntf(unit);
	sub.readName(unit);
	if(peek('[')){
		sub.arrayLen = reqGetConstIntegerExpr(1,1024);
		req(']');
	}
	req(';');
}

void ProcKW_Link(KUnit unit){
	KLink link = new KLink;
	unit.addKid(link);
	link.toks = reqTermCurly();
}

void ProcKW_Unit(DPFile file){
	KUnit unit = new KUnit;
	unit.readName(file);
	unit.intf = file.findNode!KIntf(unit.name);
	if(!unit.intf)err("Cannot find interface for this unit");

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

	// FIXME: elaborate OnClock etc here


}
