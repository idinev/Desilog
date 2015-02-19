module tools;
import std.stdio;
import std.file;
import std.algorithm;
import std.array;
import std.conv;
import parser.tokenizer;

Token cc;

alias typeof(uint.sizeof) zint;

struct IdxTok{
	zint firstTok;
}


enum MAX_VEC_SIZE = 64;
enum MAX_ARRAY_SIZE = 1024;

int len(Range)(Range r)
{
	return cast(int)r.length;
}

int logNextPow2(int value){
	int log = 0;
	while((1 << log) < value) log++;
	return log;
}

string GetFilePaddedString(string fileName)
{
	char[] rawTxt = (cast(char[])std.file.read(fileName));
	// remove 13
	size_t edi=0;
	foreach(char c; rawTxt) if(c!=13) rawTxt[edi++] = c;
	rawTxt.length = edi; 
	
	// prepend and append things
	char newLine = 10, endFile = 0;
	rawTxt = newLine ~ rawTxt ~ newLine ~ endFile ~ endFile ~ endFile ~ endFile;
	
	// convert to string (const)
	return rawTxt.idup;
}

string reqAmong(string[] toks)
{
	string cur = curTokenizer.tok.str;
	if(toks.canFind(cur)){
		gtok;
		return cur;
	}
	doThrowReqErr(toks, cur);
	return null;
}


Token gtok(){
	Token t = curTokenizer.get();
	cc = t;
	return t;
}

void StartOnTokens(Token[] toks){
	curTokenizer = toks[0].parent; // FIXME implement
}


bool peek(char exp){
	if(cc.typ == exp){
		gtok;
		return true;
	}
	return false;
}
bool peek(string exp){
	if(cc.str == exp){
		gtok;
		return true;
	}
	return false;
}

void req(char exp){
	if(cc.typ == exp){
		gtok;
		return;
	}
	failedReqTok(exp);
}
void req(string exp){
	if(cc.str == exp){
		gtok;
		return;
	}
	failedReqTok(exp);
}
string reqIdent(){
	if(cc.typ == TokTyp.ident){
		string s = cc.str;
		gtok;
		return s;
	}	
	failedReqIdent();
	return null;
}

int reqNum(){
	if(cc.typ == TokTyp.num){
		int res = to!int(cc.str);
		gtok;
		return res;
	}
	failedReqNum();
	return 0;
}
int reqNum(int imin, int imax){
	int r = reqNum();
	if(r < imin || r > imax){
		curTokenizer.back();
		err("Value out of range ",imin,"..",imax);
	}
	return r;
}
string reqURI(){
	string[] res;
	res ~= reqIdent;
	while(peek('.')){
		res ~= reqIdent;
	}
	return join(res,".");
}

zint reqTermTok(char terminator, char terminator2, ref char lastChar){
	zint i;
	int na=0, nb=0, nc=0;
	for(i = curTokenizer.readIdx; i < curTokenizer.allToks.length; i++){
		char c = curTokenizer.allToks[i].typ;
		if((c == terminator || c == terminator2) && !na && !nb && !nc){
			lastChar = c;
			curTokenizer.readIdx = i+1;
			gtok;
			return i+1;
		}
		if(c=='{') na++;
		if(c=='}') na--;
		if(c=='(') nb++;
		if(c==')') nb--;
		if(c=='[') nc++;
		if(c==']') nc--;
	}
	err("Cannot find end terminator: ", terminator);
	return 0;
}

IdxTok reqTermCurly(){
	req('{');
	char lastChar;
	zint start = curTokenizer.readIdx - 1;
	zint end = reqTermTok('}','}', lastChar);
	IdxTok res;	res.firstTok = start;
	return res;
}

IdxTok reqTermRange(char term1, char term2, ref char lastChar){
	zint start = curTokenizer.readIdx - 1;
	zint end = reqTermTok(term1,term2, lastChar);
	if(start == end) err("Expression is too short");
	IdxTok res;	res.firstTok = start;
	return res;
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


void errInternal(){
	err("Internal error");
}
void notImplemented(){
	err("Internal error: not implemented yet");
}


void err(T...)(T args)
{
	int tLine, tCol;
	string tLineStr;
	Token errTok = curTokenizer.tok;
	
	curTokenizer.getLineNum(errTok, tLine, tCol, tLineStr);
	stderr.write(curTokenizer.fileName, ":", tLine,":",(tCol+1));
	stderr.write(": Error: ", args, '\n');
	stderr.write("    ",tLineStr,"\n    ");
	foreach(i; 0..tCol)stderr.write(' ');
	for(int i=0; i < errTok.str.length && i < (tLineStr.length - tCol); i++) stderr.write('^');
	stderr.write('\n');
	stderr.flush();
	
	throw new Exception("Compile failed");
}


void reqMatch(Token[] res, string pattern){
	zint num=0;
	foreach(c; pattern){
		switch(c){
			case 'i': // any identifier
				res[num++] = cc;
				reqIdent;
				break;
			case 'u': // a unique identifier
				notImplemented;
				break;			
			default:
				req(c);
		}
	}
}




private
{
 	void doThrowReqErr(string[] toks, string cur) {
		string exp = "";
		foreach(s;toks) exp ~= "\n	" ~ s;
		err("Syntax error. Expected values:", exp);
	}
 	void failedReqTok(char exp){
 		err("Syntax error. Expected token: ", exp);
 	}
 	void failedReqTok(string exp){
 		err("Syntax error. Expected token: ", exp);
 	}
 	void failedReqIdent(){
 		err("Syntax error. Expected an identifier");
 	}
 	void failedReqNum(){
 		err("Syntax error. Expected an unsigned integer");
 	}
}
