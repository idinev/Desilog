module app;
import std.exception;
import common; 
import core.runtime;
import std.file;


void main() {
	
	DProj proj = new DProj;
	writeln(std.file.getcwd());
	std.file.chdir("..");
	std.file.chdir("examples");


	try {
		
		OnAddProjUnit(proj, "example2.example2");
		writeln("Success");		
		proj.dump(0);
	} catch (Exception e) {
		writeln("bad stuff: ", e.msg);
		if(1){
			writeln("-----------------");
			writeln(e);
		}
	}
}


