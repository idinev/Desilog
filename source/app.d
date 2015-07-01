module app;
import std.exception;
import std.file;
import std.stdio;
import std.conv;
import common; 
import gen.gen_vhdl;
import gen.run_vsim;

// Example cmdline:
//   desilog -top ram.ram -idir ../examples/unittests -odir ../examples/out


string cfgOutDir = "autogen";
string cfgInDir;
string cfgChgDir;
string cfgTop;
int    cfgTestBenchPeriod = 10; // how many picoseconds per period
int    cfgTestBenchDuration = 300; // duration of the testbench
string cfgTestBenchVSim;
bool   cfgDevErr = false;
bool   cfgDevAst = false;
bool   cfgVhdlAltera = true;
bool   cfgVhdlGeneric = false;

private{
	int printHelp(){
		writeln(
`Desilog compiler. Built on ` __DATE__`
Usage:
	desilog -top <unit.name> [-idir <inputDir> ] [-odir <outputDir> ] [-cd <startDir> ]
Example:
	desilog -top example2.tb_example2 -idir examples -odir autogen

		-top <modname>		Specify .du file which to start compilation from. 
		-cd	 <dirname>		Change to specified folder at beginning.
		-idir <dirname>		Folder containing sourcecode .du and .dpack files. Default is current-folder.
		-odir <dirname>		Folder where to generate VHDL files into. Default is "./autogen"  .
		-tb.vsim <name>		Run the specified bench through ModelSim's vsim. 
		-tb.period <num>	Clock-period in picoseconds of the generated test-benches. Default is 10ps.
		-dev.err			Print stacktrace on compile-error, useful for debugging. 
		-dev.ast			Dump AST, useful for debugging
		-vhdl.generic		Generate non-Altera abstraction vhdl files
`);
		return -1;
	}


	bool parseArgs(string[] cmdArgs){
		if(cmdArgs.length == 1) return false;
		for(int aidx=1; aidx<cmdArgs.length;){
			string arg = cmdArgs[aidx++];
			switch(arg){
				case "-odir":
					cfgOutDir = cmdArgs[aidx++];
					break;
				case "-idir":
					cfgInDir = cmdArgs[aidx++];
					break;
				case "-cd":
					cfgChgDir = cmdArgs[aidx++];
					break;
				case "-top":
					cfgTop = cmdArgs[aidx++];
					break;
				case "-tb.vsim":
					cfgTestBenchVSim = cmdArgs[aidx++];
					break;
				case "-tb.period":
					string strPS = cmdArgs[aidx++];
					cfgTestBenchPeriod = to!int(strPS);
					break;
				case "-dev.err":
					cfgDevErr = true;
					break;
				case "-dev.ast":
					cfgDevAst = true;
					break;
				case "-vhdl.generic":
					cfgVhdlAltera = false;
					cfgVhdlGeneric = true;
					break;
				default:
					stderr.writefln("Error: unknown cmd arg: %s", arg);
					stderr.writefln("-------------------");
					return false;
			}
		}
		return true;
	}

	bool verifyArgs(){
		if(!cfgTop){
			stderr.writefln("Please specify -top <unit.name>");
		}
		return true;
	}
}

int main(string[] cmdArgs) {

	string startDir = std.file.getcwd();
	
	if(!parseArgs(cmdArgs)) return printHelp();
	if(!verifyArgs()) return printHelp();


	DProj proj = new DProj;

	try {
		if(cfgChgDir){
			startDir = cfgChgDir;
			chdir(startDir);
		}

		if(cfgInDir) chdir(cfgInDir);

		OnAddProjUnit(proj, cfgTop);
		writeln("Success");

		if(cfgDevAst) proj.dump(0);

		chdir(startDir);
		if(!exists(cfgOutDir)) mkdir(cfgOutDir);
		chdir(cfgOutDir);

		GenerateAllVHDL(proj);

		if(cfgTestBenchVSim){
			RunVSimOnVHDLFiles(cfgTestBenchVSim);
		}

		chdir(startDir);
	} catch (Exception e) {
		writeln("Failed: ", e.msg);
		if(cfgDevErr){
			writeln("\n\n\n\n");
			writeln("------[ stacktrace ]-----------");
			writeln(e);
		}
		return -1;
	}
	return 0;
}


