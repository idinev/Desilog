module app;
import std.exception;
import std.file;
import std.stdio;
import common; 

// Example cmdline:
//   desilog -top ram.ram -idir ../examples/unittests -odir ../examples/out


string cfgOutDir = "autogen";
string cfgInDir;
string cfgTop;

private{
	int printHelp(){
		writeln(
`Desilog compiler. Built on ` __DATE__`
Usage:
	desilog -top <unit.name> [-idir <inputDir>] -odir <outputDir> 
Example:
	desilog -top example2.tb_example2 -idir examples -odir autogen

		
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
				case "-top":
					cfgTop = cmdArgs[aidx++];
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
	if(!verifyArgs) return printHelp();


	DProj proj = new DProj;

	try {
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


