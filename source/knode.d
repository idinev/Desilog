module knode;
import tools;
import parser.token;
import parser.tokenizer;
import nodes.dpfile;
import std.stdio;
import core.runtime;

public class KNode{
	string name;
	KNode[] kids;
	KNode parent;


	KNode findNode(string name){
		foreach(n; kids){
			if(name == n.name)return n;
		}
		if(parent) return parent.findNode(name);
		return null;
	}

	final T findNodeOfKind(T)(string name){
		return cast(T)findNode(name);
	}

	final T hasNode(T)(string name){
		foreach(n; kids){
			if(name != n.name)continue;
			T t = cast(T)n;
			if(t) return t;
		}
		return null;
	}

	final int getKid(string name){
		foreach(int i, k; kids){
			if(name == k.name) return i;
		}
		return -1;
	}


	final void addKid(KNode kid){
		kid.parent = this;
		kids ~= kid;
	}
	
	final void readName(KNode parent){
		name = reqIdent;
		parent.addKid(this);
	}
	final void readUniqName(KNode parent){
		name = reqUniqIdent(parent);
		parent.addKid(this);
	}

	void dump(int tab){
		foreach(i;0..tab) write("\t");
		writeln(name, " (", this.classinfo, ")");
		foreach(k;kids){
			k.dump(tab+1);
		}
	}

	// foreach helper
	int opApply(T)(int delegate(ref T) dg){
		for (int i = 0; i < kids.length; i++){
			T t = cast(T)kids[i];
			if(t){ 
				int result = dg(t);
				if (result) return result;
			}
		}
		return 0;
	}
}






string reqUniqIdent(KNode parent){
	string s = reqIdent;
	if(parent.findNode(s)){
		curTokenizer.back();
		err("Unique identifier required");
	}	
	return s;
}


T reqNode(T)(KNode parent){
	string name = reqIdent;
	T t = parent.findNodeOfKind!T(name);
	if(t)return t;
	err("Cannot find symbol");
	return null;
}
