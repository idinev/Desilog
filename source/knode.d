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
	bool wasVisited;

	KNode findImportedNode(string name){
		return null;
	}
	
	final KNode findNode(string name){
		KNode cur = this;
		do{
			foreach(n; cur.kids){
				if(name == n.name) return n;
			}
			KNode imp = cur.findImportedNode(name);
			if(imp)return imp;
			cur = cur.parent;
		}while(cur);
		return null;
	}

	final T findNode(T)(string name){
		KNode cur = this;
		do{
			foreach(n; cur.kids){
				if(name == n.name){
					T t = cast(T)n;
					if(t)return t;
				}
			}
			KNode imp = cur.findImportedNode(name);
			if(imp){
				T t = cast(T)imp;
				if(t)return t;
			}

			cur = cur.parent;
		}while(cur);
		return null;
	}

	final KNode findNode(string name, ClassInfo cls){
		KNode cur = this;
		do{
			foreach(n; cur.kids){
				if(name == n.name && cls == n.classinfo) return n;
			}
			cur = cur.parent;
		}while(cur);
		return null;
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
		this.parent = parent;
		parent.addKid(this);
	}
	final void readUniqName(KNode parent){
		name = reqUniqIdent(parent);
		this.parent = parent;
		parent.addKid(this);
	}

	void dump(int tab){
		foreach(i;0..tab) write("\t");
		writeln(name, " (", this.classinfo, ")");
		foreach(k;kids){
			k.dump(tab+1);
		}
	}
}


class DProj : KNode{

}


class KImport : KNode{
	DPFile mod;
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
	T t = parent.findNode!T(name);
	if(t)return t;
	err("Cannot find symbol");
	return null;
}
