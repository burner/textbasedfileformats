module textbasedfileformats.json;

import std.algorithm.comparison : among, min;
import std.algorithm.searching : findAmong, startsWith;
import std.algorithm.iteration : filter;
import std.array : appender, empty, popBack, back;
import std.ascii : isDigit;
import std.bigint;
import std.conv : to;
import std.exception : enforce, assertThrown;
import std.format : format;
import std.stdio;
import std.file;
import std.string : representation;
import std.sumtype;
import std.math : isClose, isNaN, isInfinity, pow;
import std.uni : isWhite;

@safe:

alias Payload = SumType!
	( string
	, long
	, bool
	, double
	, typeof(null)
	, BigInt
	, This[]
	, This[string]);

@safe unittest {
	Payload v = 10;
}

string toString(ref Payload p) @trusted {
	import std.array : appender;
	auto app = appender!string();
	toString(app, p);
	return app.data;
}

private void objToString(A)(auto ref A app, Payload[string] obj) @safe {
	app.put("{");
	int i;
	foreach(string key, ref val; obj) {
		if(i > 0) {
			app.put(",");
		}
		++i;
		app.put("\"");
		app.put(key);
		app.put("\":");
		toString(app, val);
	}
	app.put("}");
}

private void arrToString(A)(auto ref A app, Payload[] arr) @safe {
	app.put("[");
	foreach(i, ref it; arr) {
		if(i > 0) {
			app.put(",");
		}
		toString(app, it);
	}
	app.put("]");
}

void toString(A)(auto ref A app, ref Payload p) @trusted {
	p.match!
		( (typeof(null)) => app.put("null")
		, (string s) { app.put("\""); app.put(s); app.put("\""); }
		, (bool b) => app.put(b ? "true" : "false")
		, (long l) => app.put(to!string(l))
		, (double d) => app.put(to!string(d))
		, (BigInt bi) => bi.toString(app, "d")
		, (Payload[] arr) => arrToString(app, arr)
		, (Payload[string] obj) => objToString(app, obj)
		);
}

private immutable tokenEnd = [ ' ', '\t', '\r', '\n', ',', ':', '{', '}', '[', ']'];
private immutable whiteSpace = [ ' ', '\t', '\r', '\v', '\f'];

private bool isTokenStop(char c) pure @safe @nogc {
	foreach(it; tokenEnd) {
		if(c == it) {
			return true;
		}
	}
	return false;
}

private double exp10(int exp) pure @trusted @nogc {
	enum min = -19;
	enum max = 19;
	static __gshared immutable expmuls = {
		double[max - min + 1] ret;
		double m = 0.1;
		foreach_reverse (i; min .. 0) { ret[i-min] = m; m *= 0.1; }
		m = 1.0;
		foreach (i; 0 .. max) { ret[i-min] = m; m *= 10.0; }
		return ret;
	}();
	if (exp >= min && exp <= max) return expmuls[exp-min];
	return 10.0 ^^ exp;
}

private bool matches(string toMatch)(string input) {
	const bool sw = input.startsWith(toMatch);
	if(!sw) {
		return false;
	}

	const rest = input[toMatch.length .. $];
	if(rest.empty) {
		return true;
	}

	foreach(it; tokenEnd) {
		if(rest[0] == it) {
			return true;
		}
	}
	return false;
}

unittest {
	string tt = "null, true";
	assert(tt.matches!("null"));
}

Payload parseJson(string input) {
	JsonDomParser jdp;
	JsonParser jp =
		{ input: input
		, onArrayBegin: &jdp.onArrayBegin
		, onArrayEnd: &jdp.onArrayEnd
		, onObjectBegin: &jdp.onObjectBegin
		, onObjectEnd: &jdp.onObjectEnd
		, onInteger: &jdp.onInteger
		, onFloatingPoint: &jdp.onFloatingPoint
		, onNull: &jdp.onNull
		, onKey: &jdp.onKey
		, onString: &jdp.onString
		, onBool: &jdp.onBool
		};
	jp.parse();
	enforce(jp.input.empty, "Input not completly consumed");
	return jdp.ret;
}

alias Integer = SumType!
	( long
	, BigInt
	);

struct Position {
	uint row;
	uint column;
}

void callIfNotNull(D,Args...)(D del, Args args) {
	if(del !is null) {
		del(args);
	}
}

enum State {
	none,
	object,
	array
}

struct JsonDomParser {
@safe:
	Payload ret;
	Payload[] stack;
	string[] keyStack;
	State[] state;

	JsonParser parser;

	Payload parse() {
		this.parser.parse();
		return ret;
	}

	void onObjectBegin(Position) {
		Payload[string] t;
		this.stack ~= Payload(t);
		this.state ~= State.object;
	}

	void onObjectEnd(Position) {
		Payload tmp = this.stack.back;
		this.stack.popBack();
		if(this.stack.empty) {
			() @trusted { // TODO
				this.ret = tmp;
			}();
		} else {
			this.stack.back.match!
				( (ref Payload[string] obj) @trusted {
					obj[this.keyStack.back] = tmp;
					this.keyStack.popBack();
					return 0;
				}
				, (ref Payload[] arr) @trusted {
					arr ~= tmp;
					return 0;
				}
				, _ => 0
			);
		}
		this.state.popBack();
	}

	void onArrayBegin(Position) {
		Payload[] t;
		this.stack ~= Payload(t);
		this.state ~= State.array;
	}

	void onArrayEnd(Position) {
		Payload tmp = this.stack.back;
		this.stack.popBack();
		if(this.stack.empty) {
			() @trusted { // TODO
				this.ret = tmp;
			}();
		} else {
			this.stack.back.match!
				( (ref Payload[string] obj) @trusted {
					obj[this.keyStack.back] = tmp;
					this.keyStack.popBack();
					return 0;
				}
				, (ref Payload[] arr) @trusted {
					arr ~= tmp;
					return 0;
				}
				, _ => 0
			);
		}
		this.state.popBack();
	}

	void onKey(string key, Position) {
		this.keyStack ~= key;
	}

	void onBool(bool b, Position) {
		if(this.stack.empty) {
			() @trusted {
				this.ret = Payload(b);
			}();
			return;
		}
		this.stack.back.match!
			( (ref Payload[string] obj) @trusted {
				obj[this.keyStack.back] = Payload(b);
				return 0;
			}
			, (ref Payload[] arr) @trusted {
				arr ~= Payload(b);
				return 0;
			}
			, _ => 0
		);
		if(this.state.back == State.object) {
			this.keyStack.popBack();
		}
	}

	void onNull(Position) {
		if(this.stack.empty) {
			() @trusted {
				this.ret = Payload(null);
			}();
			return;
		}
		this.stack.back.match!
			( (ref Payload[string] obj) @trusted {
				obj[this.keyStack.back] = Payload(null);
				return 0;
			}
			, (ref Payload[] arr) @trusted {
				arr ~= Payload(null);
				return 0;
			}
			, _ => 0
		);
		if(this.state.back == State.object) {
			this.keyStack.popBack();
		}
	}

	void onInteger(Integer i, Position) @trusted {
		if(this.stack.empty) {
			this.ret = i.match!
					( (long l) => Payload(l)
					, (BigInt l) => Payload(l)
					);
			return;
		}
		this.stack.back.match!
			( (ref Payload[string] obj) {
				obj[this.keyStack.back] = i.match!
					( (long l) => Payload(l)
					, (BigInt l) => Payload(l)
					);
				return 0;
			}
			, (ref Payload[] arr) {
				long l = arr.length;
				arr ~= i.match!
					( (long l) => Payload(l)
					, (BigInt l) => Payload(l)
					);
				return 0;
			}
			, _ => 0
		);
		if(this.state.back == State.object) {
			this.keyStack.popBack();
		}
	}

	void onFloatingPoint(double d, Position) @trusted {
		if(this.stack.empty) {
			this.ret = Payload(d);
			return;
		}
		this.stack.back.match!
			( (ref Payload[string] obj) {
				obj[this.keyStack.back] = d;
				return 0;
			}
			, (ref Payload[] arr) {
				arr ~= Payload(d);
				return 0;
			}
			, _ => 0
		);
		if(this.state.back == State.object) {
			this.keyStack.popBack();
		}
	}

	void onString(string s, Position) @trusted {
		if(this.stack.empty) {
			this.ret = Payload(s);
			return;
		}
		this.stack.back.match!
			( (ref Payload[string] obj) {
				obj[this.keyStack.back] = s;
				return 0;
			}
			, (ref Payload[] arr) {
				arr ~= Payload(s);
				return 0;
			}
			, _ => 0
		);
		if(this.state.back == State.object) {
			this.keyStack.popBack();
		}
	}
}

struct JsonParser {
@safe:
	string input;
	uint row;
	uint column;

	void delegate(Position) onObjectBegin;
	void delegate(Position) onObjectEnd;
	void delegate(Position) onArrayBegin;
	void delegate(Position) onArrayEnd;
	void delegate(string, Position) onKey;
	void delegate(Integer, Position) onInteger;
	void delegate(string, Position) onString;
	void delegate(bool, Position) onBool;
	void delegate(double,Position) onFloatingPoint;
	void delegate(Position) onNull;

	void stripWhitespace() {
		outer: while(!this.input.empty) {
			if(this.input[0] == '\n') {
				this.input = this.input[1 .. $];
				this.row++;
				this.column = 1;
				continue outer;
			}
			foreach(it; whiteSpace) {
				if(this.input[0] == it) {
					this.column++;
					this.input = this.input[1 .. $];
					continue outer;
				}
			}
			return;
		}
	}

	Position getCurrentPosition() {
		return Position(this.row, this.column);
	}

	void parse() {
		this.parseValue();
	}

	void parseValue() {
		this.stripWhitespace();
		if(this.input.startsWith("{")) {
			this.input = this.input[1 .. $];
			this.column++;
			this.parseObject();
			return;
		} else if(this.input.startsWith("[")) {
			this.input = this.input[1 .. $];
			this.column++;
			this.parseArray();
			return;
		} else if(this.input.startsWith("\"")) {
			callIfNotNull(this.onString, this.parseString(),
					this.getCurrentPosition());
			return;
		} else if(matches!("null")(this.input)) {
			callIfNotNull(this.onNull, this.getCurrentPosition());
			this.column += 4;
			this.input = this.input[4 .. $];
			Payload ret;
			() @trusted {
				ret = null;
			}();
			return;
		} else if(matches!("false")(this.input)) {
			callIfNotNull(this.onBool, false, this.getCurrentPosition());
			this.column += 5;
			this.input = this.input[5 .. $];
			return;
		} else if(matches!("true")(this.input)) {
			callIfNotNull(this.onBool, true, this.getCurrentPosition());
			this.column += 4;
			this.input = this.input[4 .. $];
			return;
		} else if(!this.input.empty
			&& ((this.input[0] >= '0' && this.input[0] <= '9')
				|| this.input[0] == '-'
				|| this.input[0] == '+'))
		{
			this.parseNumber();
			return;
		}
		throw new Exception("Failed to parse Payload, startsWith "
				~ this.input[0 .. min(this.input.length, 10)]);
	}

	void parseNumber() {
		enforce(!input.empty, "Passed empty range to parseNumber");

		BigInt collector;
		bool neg = false;

		void returnInt() {
			collector = neg
				? -collector
				: collector;

			const long r = collector.toLong();
			Integer i = r == long.max || r == long.min
				? Integer(collector)
				: Integer(r);
			this.onInteger(i, this.getCurrentPosition());
		}

		// negative sign
		if (input[0] == '-')
		{
			this.input = this.input[1 .. $];
			this.column++;
			neg = true;
		}

		enforce(!input.empty, "Input empty before integer parsing started");
		if (input[0] == 'I') {
			enum inf = "Infinity";
			if (input.matches!(inf)()) {
				this.column += inf.length;
				this.input = this.input[inf.length .. $];
				callIfNotNull(this.onFloatingPoint
					, neg ? -double.infinity : double.infinity
					, this.getCurrentPosition());
				return;
			}
			enforce(false, "Invalid number, expected 'Infinity'");
		}
		if (!neg && input[0] == 'N') {
			enum nan = "NaN";
			if (input.matches!("NaN")()) {
				this.column += nan.length;
				this.input = this.input[nan.length .. $];
				callIfNotNull(this.onFloatingPoint
					, double.nan
					, this.getCurrentPosition());
				return;
			}
			enforce(false, "Invalid number, expected 'NaN'");
		}

		// integer part of the number
		enforce(!this.input.empty && this.input[0].isDigit(), "Invalid number, expected digit '"
				~ this.input[0 .. min(10, this.input.length)] ~ "'");

		if(this.input[0] == '0') {
			this.input = this.input[1 .. $];
			this.column++;
			if (input.empty) { // return 0
				long r = 0;
				this.onInteger(Integer(r), this.getCurrentPosition());
				return;
			}

			enforce(this.input.empty || !this.input[0].isDigit()
					|| isTokenStop(this.input[0])
				, "Invalid number, 0 must not be followed by another digit '"
				~ input[0 .. min(10, input.length)] ~ "'");
		}

		while (!input.empty && isDigit(input[0])) {
			collector = collector * 10 + (input[0] - '0');
			this.input = this.input[1 .. $];
			this.column++;

			if (input.empty || isTokenStop(input[0])) // return integer
			{
				returnInt();
				return;
			}
		}

		int exponent = 0;

		enforce(!input.empty, "post decimal point part empty");
		if (input[0] == '.')
		{
			this.input = this.input[1 .. $];
			this.column++;

			enforce(!input.empty || input[0].isDigit()
					, "Invalid number, expected digit '"
					~ input[0 .. min(10, input.length)] ~ "'");

			while (true)
			{
				uint digit = input[0] - '0';
				if (digit > 9) {
					break;
				}

				collector = collector * 10 + digit;
				exponent--;
				this.input = this.input[1 .. $];
				this.column++;

				if(input.empty || isTokenStop(input[0])) {
					long expPow = pow(10, -exponent);
					if(expPow == 0 || expPow == -0) {
						callIfNotNull(this.onFloatingPoint, 0.0,
								this.getCurrentPosition());
						return;
					}
					BigInt integralPart = collector / expPow;
					integralPart = integralPart * expPow;
					BigInt floatPart = collector - integralPart;
					integralPart = integralPart / expPow;
					string d = integralPart.toDecimalString() ~ "." ~
						floatPart.toDecimalString();
					callIfNotNull(this.onFloatingPoint, d.to!double(),
							this.getCurrentPosition());
					return;
				}
			}

			enforce(exponent != 0, "Missing fractional number part");
		}

		// exponent
		enforce(!input.empty);
		if (input[0] == 'e' || input[0] == 'E')
		{
			this.input = this.input[1 .. $];
			this.column++;
			enforce(!input.empty, "Missing exponent");

			bool negexp = void;
			if (input[0] == '-')
			{
				negexp = true;
				this.input = this.input[1 .. $];
				this.column++;
			}
			else
			{
				negexp = false;
				if (input[0] == '+') {
					this.input = this.input[1 .. $];
					this.column++;
				}
			}

			enforce(!input.empty && input[0].isDigit, "Missing exponent");

			uint exp = 0;
			while (true)
			{
				exp = exp * 10 + (input[0] - '0');
				this.input = this.input[1 .. $];
				this.column++;
				if (input.empty || !input[0].isDigit()) {
					break;
				}
			}

			if (negexp) {
				exponent -= exp;
			}
			else  {
				exponent += exp;
			}
		}

		if (exponent == 0) {
			returnInt();
			return;
		}

		if (neg) {
			collector = -collector;
		}

		//_front.number = exp10(exponent) * int_part.toDecimalString.to!double;
		callIfNotNull(this.onFloatingPoint
				, collector.toDecimalString.to!double() * exp10(exponent)
				, this.getCurrentPosition());
	}

	void parseObject() {
		callIfNotNull(this.onObjectBegin, this.getCurrentPosition());
		bool notFirst = false;
		this.stripWhitespace();
		while(!this.input.empty && this.input[0] != '}') {
			if(notFirst) {
				this.stripWhitespace();
				enforce(!this.input.empty && this.input[0] == ','
						, "Expected ',' got '" ~ (!this.input.empty ? to!string(this.input[0]) : "")
						~ "'");
				this.input = this.input[1 .. $];
				this.column++;
			}
			this.stripWhitespace();
			string key = this.parseString();
			callIfNotNull(this.onKey, key, getCurrentPosition());
			this.stripWhitespace();
			enforce(!this.input.empty && this.input[0] == ':'
					, "Expected ':' got '" ~ (!this.input.empty ? to!string(this.input[0]) : "")
					~ "'");
			this.input = this.input[1 .. $];
			this.column++;
			this.stripWhitespace();
			this.parseValue();
			notFirst = true;
			this.stripWhitespace();
		}
		this.stripWhitespace();
		enforce(!this.input.empty && this.input[0] == '}', "Expected '}' got '"
				~ (this.input.empty ? "" : to!string(this.input[0]))
				~ "'");
		callIfNotNull(this.onObjectEnd, this.getCurrentPosition());
		this.input = this.input[1 .. $];
		this.column++;
	}

	void parseArray() {
		callIfNotNull(this.onArrayBegin, this.getCurrentPosition());
		bool notFirst = false;
		this.stripWhitespace();
		while(!this.input.empty && this.input[0] != ']') {
			if(notFirst) {
				enforce(!this.input.empty && this.input[0] == ',', "Expected ',' got '"
						~ (this.input.empty ? "" : to!string(this.input[0]))
						~ "'");
				this.input = this.input[1 .. $];
				this.column++;
			}
			this.stripWhitespace();
			this.parseValue();
			this.stripWhitespace();
			notFirst = true;
		}
		this.stripWhitespace();
		enforce(!this.input.empty && this.input[0] == ']'
				, "Expected ']' got '" ~ (!this.input.empty ? to!string(this.input[0]) : "")
				~ "'");
		this.input = this.input[1 .. $];
		this.column++;
		this.stripWhitespace();
		callIfNotNull(this.onArrayEnd, this.getCurrentPosition());
	}

	string parseString() {
		enforce(!this.input.empty && this.input[0] == '"', "Expected '\"' got '"
				~ (this.input.empty ? "" : to!string(this.input[0]))
				~ "'");
		this.input = this.input[1 .. $];
		size_t idx = 0;
		while(idx < this.input.length) {
			if(idx > 0 && this.input[idx] == '"' && this.input[idx - 1] != '\\') {
				break;
			}
			if(idx == 0 && this.input[idx] == '"') {
				break;
			}
			++idx;
		}

		string ret = this.input[0 .. idx];
		enforce(idx + 1 <= this.input.length, "string out of range");
		this.input = this.input[idx+1 .. $];
		this.column += idx + 1;
		return ret;
	}
}

private void toStringCmp(string old, Payload pl) {
	import std.string : replace;

	string oldNoWhiteSpace = old.replace(" ","")
		.replace("\t", "")
		.replace("\n", "");

	string fromPl = toString(pl);
	assert(oldNoWhiteSpace == fromPl
			, "\nold: " ~ oldNoWhiteSpace ~ "\nnew: "~ fromPl);
}

unittest {
	string tp = `{}`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{ "hello": null }`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{ "hello": [] }`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{ "hello": "world" }`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{ "hello": [ null, true, false] }`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{ "hello": [ null ,
		true, false
	]}`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

unittest {
	string tp = `{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}]}`;
	auto p = parseJson(tp);
	toStringCmp(tp, p);
}

private string numberToString(Payload p) @safe pure{
	return p.match!
			( (long l) => l.to!string()
			, (double d) => format("%f", d)
			, (_) => "Not a number"
			);
}

@safe unittest
{
	import core.exception;
	import std.exception;

	@safe void test(V)(string input, V expected, string rest, int line = __LINE__) {
		Payload rslt = expected;
		Payload r;
		auto p = JsonParser(input);
		void onInteger(Integer i, Position) @trusted {
			r = i.match!
					( (BigInt bi) => Payload(bi)
					, (long l) => Payload(l)
					);
		}

		void onFloat(double d, Position) @trusted {
			r = Payload(d);
		}

		p.onFloatingPoint = &onFloat;
		p.onInteger = &onInteger;

		try {
			() @trusted {
				p.parseNumber();
			}();
		} catch(Exception e) {
			throw new AssertError(e, __FILE__, line);
		}
		() @trusted {
			bool okay = r.match!
				( (long a) => rslt.match!
				  	( (long b) {
						return a == b;
					  }
					, (double b) => false
					, (_) => false
					)
				, (double a) => rslt.match!
				  	( (long b) => false
					, (double b) {
						return isNaN(a)
							? isNaN(a) == isNaN(b)
							: isInfinity(a)
								? isInfinity(a) == isInfinity(b)
								: isClose(a, b);
					  }
					, (_) => false
					)
				, (_) => false
				);
			if(!okay) {
				string expStr = numberToString(rslt);
				string gotStr = numberToString(r);
				throw new AssertError(format("input %s\nexp: %s\ngot: %s"
							, input, expStr, gotStr), __FILE__, line);
			}
		}();
	}

	test("NaN", double.nan, "");
	test("NaN ", double.nan, " ");
	test("Infinity", double.infinity, "");
	test("Infinity ", double.infinity, " ");
	test("-Infinity", -double.infinity, "");
	test("-Infinity ", -double.infinity, " ");
	test("0", 0, "");
	test("0 ", 0, " ");
	test("12", 12, "");
	test("12 ", 12, " ");
	test("1249", 1249, "");
	test("1249 ", 1249, " ");
	test("123", 123, "");
	test("123.0", 123.0, "");
	test("123.0 ", 123.0, " ");
	test("123.456", 123.456, "");
	test("123.456 ", 123.456, " ");
	test("-0", 0, "");
	test("-0 ", 0, " ");
	test("-0e+10 ", 0.0, " ");
	test("123.456e1", 1234.56, "");
	test("123.456e1 ", 1234.56, " ");
	test("123.456e+1", 1234.56, "");
	test("123.456e+1 ", 1234.56, " ");
	test("123.456e-1", 12.3456, "");
	test("123.456e-1 ", 12.3456, " ");
	test("123.456e-01", 12.3456, "");
	test("123.456e-01 ", 12.3456, " ");
	test("0.123e-12", 0.123e-12, "");
	test("0.123e-12 ", 0.123e-12, " ");
}

@trusted unittest {
	foreach(ma; dirEntries("JSONTestSuite/test_parsing/", SpanMode.depth)
			.filter!(n => n.name.startsWith("JSONTestSuite/test_parsing/y_")))
	{
		try {
			string s = readText(ma.name);
			auto p = parseJson(s);
		} catch(Exception e) {
			writeln(ma.name);
		}
	}
}

@trusted unittest {
	foreach(ma; dirEntries("JSONTestSuite/test_parsing/", SpanMode.depth)
			.filter!(n => n.name.startsWith("JSONTestSuite/test_parsing/n_"))
			.filter!(n => !n.name.startsWith("JSONTestSuite/test_parsing/n_string")))
	{
		bool okay;
		try {
			auto r = parseJson(readText(ma.name));
		} catch(Exception e) {
			okay = true;
		}
		if(!okay) {
			writeln(ma.name);
		}
	}
}
