module parser.tokenizer;

import std.ascii;
import std.algorithm;
import tools;
public import parser.token;


immutable auto triOps = [
	"xor", "and"
];
immutable auto duoOps = [
	"?=", "or"
];
immutable auto singleOps = `{}()[]<>=+*-.;,":`;



private{
	bool InRange(char c, char imin, char imax){
		return c >= imin && c <= imax;
	}
	
	bool isCharDigit(char c){
		return InRange(c,'0','9');
	}
	bool isCharHexDigit(char c){
		return InRange(c,'0','9') || InRange(c,'a','f') || InRange(c,'A','F');
	}
	
	bool IsNum(string str, ref TokTyp resTyp, ref size_t resCount){
		zint i = 0;
		
		const(char)* ptr = str.ptr; 
	
		TokTyp ityp = TokTyp.num;
		char c = str[i];
		
		int tlen = str.len;
		if(c=='\''){
			i++;
			while(str[i]=='0' || str[i]=='1')i++;
			if(str[i]!='\'')return false;
			i++;
			ityp = TokTyp.siznum;
		}else if(c=='0' && str[i+1]=='x' && isCharHexDigit(str[i+2])){
			i+=2;
			while(isCharHexDigit(str[i])){
				i++;
			}
			ityp = TokTyp.siznum;
		}else if(isCharDigit(c)){
			while(isCharDigit(str[i])){
				i++;
			}
			if(str[i]=='\''){
				if(!isCharDigit(str[i+1]))return false;
				i++;
				ityp = TokTyp.siznum;
				if(str[i]=='0' && str[i+1]=='x' && isCharHexDigit(str[i+2])){
					i+=2;
					while(isCharHexDigit(str[i])){
						i++;
					}
				}else if(isCharDigit(str[i])){
					while(isCharDigit(str[i])){
						i++;
					}
				}else{
					return false;
				}
				if(str[i]!='\'')return false;
				i++;
			}
		}else{
			return false;
		}
		
		resTyp = ityp;
		resCount = i;
		return true;
	}
}

Tokenizer curTokenizer;



class Tokenizer
{
	string fileName;
	string src;
	Token[] allToks;
	size_t readIdx;
	Token tok;
	this(string fileName)
	{
		this.fileName = fileName;
	}
	
	Token get(){
		tok = allToks[readIdx++];
		return tok;
	}
	void back(){
		tok = allToks[--readIdx];
	}
	
	void tokenize(){
		src = GetFilePaddedString(fileName);
		size_t idx = 0, base;
		
		Token t;
		
		Tokenizer prevTokenizer = curTokenizer;
		curTokenizer = this;
		
		void throwTantrum(string msg)
		{
			t = new Token;
			t.parent = this;
			t.str = src[base .. idx];
			t.typ = TokTyp.err;
			allToks ~= t;
			tok = t;
			err(msg);
		}
		
		while(true)
		{
			char c = src[idx++];
			if(c==9 || c==32 || c==10)continue;
			if(c=='/')
			{
				if(src[idx]=='/')
				{
					while(src[idx] != 10)idx++;
					continue;
				}
				if(src[idx]=='*')
				{
					base = idx;
					while(true)
					{
						idx++;
						if(src[idx]=='*' && src[idx+1]=='/')
						{
							idx+=2;
							break;
						}
						if(src[idx]==0)
						{
							throwTantrum("undelimited /*. Expected */");
						}
					}
					continue;
				}
			}
			
			base = idx - 1;
			t = new Token;
			t.parent = this;
			
			bool isFirstIdentChar(char c)
			{
				return isAlpha(c) || c == '_' || c == '@';
			}
			
			size_t lenOfNum;
			
			if(isFirstIdentChar(c))
			{
				t.typ = TokTyp.ident;
				c = src[idx];
				while(isFirstIdentChar(c) || isDigit(c))
				{
					c = src[++idx];
				}
			} 
			else if(IsNum(src[base..$], t.typ, lenOfNum))
			{
				idx += lenOfNum - 1;
			}
			else if(c=='"')
			{
				// quote
				t.typ = TokTyp.quot;
				char prevC;
				for(;;){
					prevC = c;
					c = src[idx++];
					if(c=='"' && prevC!='\\'){ idx++; break;}
					if(c==0)break;
					//if(c==10 && !skipNewline)break;
				}
			}
			else if(c==0)
			{
				t.typ = TokTyp.end;
			}
			else
			{
				string tri = src[base .. idx+2];
				string duo = src[base .. idx+1];
				
				if (triOps.canFind(tri))
				{
					t.typ = TokTyp.op;
					idx += 2;
				}
				else if (duoOps.canFind(duo))
				{
					t.typ = TokTyp.op;
					idx += 1;
				}
				else
				{
					t.typ = cast(TokTyp)c;
					if(!singleOps.canFind(c))
					{
						throwTantrum("Unknown operator");
					}
				}
			}
			t.str = src[base .. idx];
			allToks ~= t;
			if(t.typ == TokTyp.end) break;
		}
		
		
		this.readIdx = 0;
		this.tok = allToks[0];
		cc = this.tok;
		
		curTokenizer = prevTokenizer;
	}
	
	bool getLineNum(Token tok, ref int line, ref int col, ref string strLine)
	{
		immutable int tabWidth = 4;
		
		line = 0; col = 0; strLine = "";
		if(!allToks.canFind(tok)) return false;
		ptrdiff_t diff = tok.str.ptr - src.ptr;
		ptrdiff_t i;
		
		int nLine=0,nCol=0, nStartLine=0;
		for (i = 0; i < diff ; i++)
		{
			char c = src[i];
			if(c!=9)nCol++;
			else nCol = (nCol + tabWidth) & ~(tabWidth-1);
			if(c!=10)continue;
			nLine++;nCol=0;
			nStartLine = cast(int)(i+1);
		}
		
		int k;
		for(k = nStartLine; k < src.length; k++)
		{
			if(src[k]==10)break;
		}
		
		line = nLine;
		col = nCol;
		strLine = src[nStartLine .. k];
		return true;
	}
}


