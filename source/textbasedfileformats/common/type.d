module textbasedfileformats.common.type;

import std.sumtype;
import std.bigint;
import std.datetime.systime;

///
alias Payload = SumType!
	( string
	, long
	, bool
	, double
	, typeof(null)
	, BigInt
	, SysTime
	, This[]
	, This[string]);
