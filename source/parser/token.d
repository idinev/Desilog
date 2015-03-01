module parser.token;
import parser.tokenizer;

enum TokTyp : char {
	end   = 0,
	err   = 'e',
	ident = 'i', // identifier
	num   = 'n', // hex/decimal integer
	siznum= 'z', // number with specific size
	op    = 'o', // operator 
	quot  = 'q', // "quote"
}


public class Token{
	string str;
	TokTyp typ;
	Tokenizer parent;
}

class NumToken : Token{
	int numBits;
	int minBits;
	ulong value;
}
