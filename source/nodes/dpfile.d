module nodes.dpfile;
import std.array;
import common;
import nodes.kunit;
import std.algorithm;


class DProj : KNode{
	
}

class DPFile : KNode{
	Tokenizer tokzer;
	bool isUnit;

	override KNode findNode(string name){
		foreach(n; kids){
			if(name == n.name)return n;
		}
		foreach(KImport imp; this){
			foreach(n; imp.mod.kids){
				if(n.name == name) return n;
			}
		}
		return null;
	}
}

class KImport : KNode{
	DPFile mod;
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

// ===============================================================

class TBVEntry{
	KExpr[] ins;
	KExpr[] outs;
};

class KTestBench : KNode{
	KEntity intf;

	IdxTok[] idxForcers;
	Verify vfy;

	struct Verify{
		bool active;
		int offset, latency;
		string[] ins;
		string[] outs;
		IdxTok table;

		KArg[] argIns;
		KArg[] argOuts;

		TBVEntry[] entries;
	}
}


void ProcKW_Testbench(DPFile file){
	KTestBench tb = new KTestBench;
	tb.readName(file);
	req('<'); tb.intf = reqNode!KEntity(file); req('>');
	req('{');
	for(;;){
		switch(reqAmong(["}", "force", "verify"])){
			case "}": return;
			case "force":
				tb.idxForcers ~= reqTermCurly;
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


void Elaborate_Testbench(KTestBench tb){
	foreach(fc; tb.idxForcers){
		curTokenizer.startFrom(fc);
		KTBForcer forcer = new KTBForcer;
		tb.addKid(forcer);
		forcer.code = ReadStatementList(forcer);
	}
	if(tb.vfy.table.firstTok){
		KScope dummyScope = new KScope;
		tb.addKid(dummyScope);

		req('(');
		tb.vfy.offset = reqGetConstIntegerExpr(0, 1024);
		req(',');
		tb.vfy.latency = reqGetConstIntegerExpr(1, 1024);
		req(')'); req("in"); req('(');
		
		tb.vfy.argIns = ReadFunctionArgs(dummyScope, true);
		req("out"); req('(');
		tb.vfy.argOuts = ReadFunctionArgs(dummyScope, false);

		req('{');
		for(;;){
			if(peek('}'))break;

			TBVEntry ventry = new TBVEntry;

			foreach(int i, a; tb.vfy.argIns){
				if(i)req(',');
				ventry.ins ~= ReadExpr(dummyScope);
			}

			req(':');

			foreach(int i, a; tb.vfy.argOuts){
				if(i)req(',');
				ventry.outs ~= ReadExpr(dummyScope);
			}

			req(';');
			tb.vfy.entries ~= ventry;
		}
	}
}


// ===============================================================

class KDefine : KNode{
	Token[] toks;
}


void ProcKW_Define(KNode parent){
	KDefine a = new KDefine;
	a.name = reqUniqIdent(parent);
	if(peek('(')){
		notImplemented;
	}
	req('=');

	for(;;){
		if(peek(';'))break;
		a.toks ~= cc;
		gtok;
	}
	parent.addKid(a);
}



// ===============================================================

KNode g_curNodeWithDefs;


DPFile OnAddProjPack(DProj proj, string uri){
	DPFile file = new DPFile;
	file.name = uri;
	proj.addKid(file);
	file.parent = null; // on purpose

	auto prevNodeWithDefs = g_curNodeWithDefs;
	g_curNodeWithDefs = file;

	Tokenizer prevTokzer = curTokenizer;
	
	string fname = uri.split(".").join("/") ~ ".dpack";
	file.tokzer = new Tokenizer(fname);
	curTokenizer = file.tokzer;
	file.tokzer.tokenize();
	gtok;

	
	for(;;){
		if(cc.typ == TokTyp.end)break;
		switch(reqAmong(["entity", "import", "struct", "enum", "type", "define"])) {
			case "entity":	ProcessKW_Entity(file); break;
			case "import":		ProcKW_Import(file, proj);break;
			case "struct":		ProcKW_Struct(file); break;
			case "enum":		ProcKW_Enum(file); break;
			case "type":		ProcKW_Type(file); break;
			case "define":		ProcKW_Define(file); break;
			default:	errInternal;
		}
	}

	g_curNodeWithDefs = prevNodeWithDefs;
	curTokenizer = prevTokzer;
	curTokenizer.back();
	gtok;

	//file.dump(0);

	return file;
}

void OnAddProjUnit(DProj proj, string uri){
	DPFile file = new DPFile;
	file.name = uri;
	proj.addKid(file);
	file.parent = null; // on purpose
	file.isUnit = true;
	g_curNodeWithDefs = file;

	string fname = uri.split(".").join("/") ~ ".du";
	file.tokzer = new Tokenizer(fname);
	curTokenizer = file.tokzer;
	file.tokzer.tokenize();
	gtok;
	
	for(;;){
		if(cc.typ == TokTyp.end)break;
		switch(reqAmong(["entity", "unit", "import", "define", "testbench"])) {
			case "entity":			ProcessKW_Entity(file); break;
			case "unit":			ProcKW_Unit(file);	break;
			case "import":			ProcKW_Import(file, proj);break;
			case "define":			ProcKW_Define(file); break;
			case "testbench":		ProcKW_Testbench(file); break;
			default:	errInternal;
		}
	}

	//file.dump(0);


	foreach(KUnit unit; file){
		g_curNodeWithDefs = unit;
		foreach(KVar var; unit){
			if(!var.reset.firstTok)continue;
			curTokenizer.startFrom(var.reset);
			var.resetExpr = ReadExpr(unit);
		}
		// elaborate processes/combi/functions
		foreach(KScope proc; unit){
			curTokenizer.startFrom(proc.curlyStart);

			proc.code = ReadStatementList(proc);
		}
	}

	g_curNodeWithDefs = file;

	foreach(KTestBench tb; file){
		Elaborate_Testbench(tb);
	}
	 
	/*
	 * FIXME
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
			if(file.hasNode!KEntity(sub.name)){
				// local unit
				sub.URI = file.URI ~ "." ~ sub.name;
				continue;
			}
			// Intf must be defined in an imported package
			foreach(p; file.kids){
				KImport imp = cast(KImport)p;
				if(!imp)continue;
				KEntity intf = imp.hasNode!KEntity(sub.name);

			}
		}
	}*/
}

