module app;
import std.exception;
import std.file;
import std.stdio;
import std.conv;
import common; 

// Example cmdline:
//   desilog -top ram.ram -idir ../examples/unittests -odir ../examples/out


string cfgOutDir = "autogen";
string cfgInDir;
string cfgChgDir;
string cfgTop;
int    cfgTestBenchPeriod = 10; // how many picoseconds per period
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
		-tb.period <num>	Clock-period in picoseconds of the generated test-benches. Default is 10ps.
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
				case "-tb.period":
					string strPS = cmdArgs[aidx++];
					cfgTestBenchPeriod = to!int(strPS);
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
		//proj.dump(0);

		chdir(startDir);
		if(!exists(cfgOutDir)) mkdir(cfgOutDir);
		chdir(cfgOutDir);

		GenerateAllVHDL(proj);
		chdir(startDir);
	} catch (Exception e) {
		writeln("Failed: ", e.msg);
		if(1){
			writeln("-----------------");
			writeln(e);
		}
		return -1;
	}
	return 0;
}


