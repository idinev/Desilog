module nodes.dpfile;
import std.array;
import common;
import nodes.kintf;
import std.algorithm;

class DPFile : KNode{
	Tokenizer tokzer;
	bool isUnit;

	override KNode findImportedNode(string name){
		foreach(k; kids){
			KImport imp = cast(KImport)k;
			if(!imp)continue;
			foreach(n; imp.mod.kids){
				if(n.name == name) return n;
			}
		}
		return null;
	}
}

void ProcKW_Import(KNode parent, DProj proj){
	KImport imp = new KImport;
	imp.name = reqURI();
	imp.mod = proj.hasNode!DPFile(imp.name);
	if(!imp.mod){
		imp.mod = OnAddProjPack(proj, imp.name);
	}
	req(';');
	parent.addKid(imp);
}


class KTestBench : KNode{
	KIntf intf;

	Token[] force;
	Verify vfy;

	struct Verify{
		bool active;
		int offset, latency;
		string[] ins;
		string[] outs;
		Token[] table;
	}
}

string[] reqListOfIdents(){
	string[] res;
	for(;;){
		string s = cc.str;
		if(!peek(TokTyp.ident))break;
		res ~= s;
		if(!peek(','))break;
	}
	return res;
}

void ProcKW_Testbench(DPFile file){
	KTestBench tb = new KTestBench;
	tb.readName(file);
	req('<'); tb.intf = reqNode!KIntf(file); req('>');
	req('{');
	for(;;){
		switch(reqAmong(["}", "force", "verify"])){
			case "}": return;
			case "force":
				tb.force = reqTermCurly;
				break;
			case "verify":
				req('(');
				tb.vfy.offset = reqGetConstIntegerExpr(0,100000);
				req(',');
				tb.vfy.latency = reqGetConstIntegerExpr(0,1000);
				req(')'); 
				req("in");  req('('); tb.vfy.ins  = reqListOfIdents(); req(')');
				req("out"); req('('); tb.vfy.outs = reqListOfIdents(); req(')');
				tb.vfy.table = reqTermCurly;
				break;
			default: errInternal;
		}
	}
}


DPFile OnAddProjPack(DProj proj, string uri){
	DPFile file = new DPFile;
	file.name = uri;
	proj.addKid(file);
	file.parent = null; // on purpose

	Tokenizer prevTokzer = curTokenizer;
	
	string fname = uri.split(".").join("/") ~ ".dpack";
	file.tokzer = new Tokenizer(fname);
	curTokenizer = file.tokzer;
	file.tokzer.tokenize();
	gtok;
	
	for(;;){
		if(cc.typ == TokTyp.end)break;
		switch(reqAmong(["interface", "import", "struct", "enum", "type"])) {
			case "interface":	ProcessKW_Interface(file); break;
			case "import":		ProcKW_Import(file, proj);break;
			case "struct":		ProcKW_Struct(file); break;
			case "enum":		ProcKW_Enum(file); break;
			case "type":		ProcKW_Type(file); break;
			default:	errInternal;
		}
	}

	curTokenizer = prevTokzer;
	curTokenizer.back();
	gtok;

	return file;
}

void OnAddProjUnit(DProj proj, string uri){
	DPFile file = new DPFile;
	file.name = uri;
	proj.addKid(file);
	file.parent = null; // on purpose
	file.isUnit = true;

	string fname = uri.split(".").join("/") ~ ".du";
	file.tokzer = new Tokenizer(fname);
	curTokenizer = file.tokzer;
	file.tokzer.tokenize();
	gtok;
	
	for(;;){
		if(cc.typ == TokTyp.end)break;
		switch(reqAmong(["interface", "unit", "import", "testbench"])) {
			case "interface":		ProcessKW_Interface(file); break;
			case "unit":			ProcKW_Unit(file);	break;
			case "import":			ProcKW_Import(file, proj);break;
			case "testbench":		ProcKW_Testbench(file); break;
			default:	errInternal;
		}
	}

	 
	/*
	// find other units to load
	foreach(u; file.kids){ // foreach process
		KUnit unit = cast(KUnit)u;
		if(!unit)continue;
		foreach(s; unit.kids){
			KSubUnit sub = cast(KSubUnit)s;
			if(!sub) continue;

			if(sub.name.canFind('.')){
				// the name was declared as a full URI
				sub.URI = sub.name;

				continue;
			}
			// name declared as a local or imported single-identifier
			if(file.hasNode!KIntf(sub.name)){
				// local unit
				sub.URI = file.URI ~ "." ~ sub.name;
				continue;
			}
			// Intf must be defined in an imported package
			foreach(p; file.kids){
				KImport imp = cast(KImport)p;
				if(!imp)continue;
				KIntf intf = imp.hasNode!KIntf(sub.name);

			}
		}
	}*/
}

