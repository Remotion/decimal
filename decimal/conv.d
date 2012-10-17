// Written in the D programming language

/**
 *	A D programming language implementation of the
 *	General Decimal Arithmetic Specification,
 *	Version 1.70, (25 March 2009).
 *	http://www.speleotrove.com/decimal/decarith.pdf)
 *
 *	Copyright Paul D. Anderson 2009 - 2012.
 *	Distributed under the Boost Software License, Version 1.0.
 *	(See accompanying file LICENSE_1_0.txt or copy at
 *	http://www.boost.org/LICENSE_1_0.txt)
**/

module decimal.conv;

import std.array: insertInPlace;
import std.bigint;
import std.string;
import std.format;
import decimal.integer;

import decimal.context;
import decimal.rounding: round;
import decimal.dec32;
import decimal.dec64;
import decimal.dec128;
import decimal.decimal;
import decimal.test;

//--------------------------------
//   to!string conversions
//--------------------------------

/// to!string(BigInt).
T to(T: string)(const BigInt num) {
	string outbuff = "";
	void sink(const(char)[] s) {
		outbuff ~= s;
	}
	num.toString(&sink, "%d");
	return outbuff;
}

/// to!string(int).
T to(T: string)(const long n) {
	return format("%d", n);
}

/// to!string(USizedInt!Z).
T to(T: string)(const uint128 n) {
	return n.toString();
}

//--------------------------------
//  uint128 conversions
//--------------------------------

BigInt toBigInt(const uint128 arg) {
	BigInt big = BigInt(0);
	big = BigInt(arg.toString);
	return big;
}

//--------------------------------
//  decimal tests
//--------------------------------

/// Returns true if T is a decimal type.
public template isDecimal(T) {
	enum bool isDecimal =
		is(T: Dec32) || is(T: Dec64) || is(T: Dec128) || is(T: BigDecimal);
}

/// Returns true if T is an arbitrary-precision decimal type.
public template isBigDecimal(T) {
	enum bool isBigDecimal = is(T: BigDecimal);
}

/// Returns true if T is a fixed-precision decimal type.
public template isFixedDecimal(T) {
	enum bool isFixedDecimal = is(T: Dec32) || is(T: Dec64) || is(T: Dec128);
}

/// Converts a decimal number to an arbitrary-precision decimal type
public T toDecimal(T, U)(const U num) if (isDecimal!T && isBigDecimal!U) {
		static if (is(typeof(num) == T)) {
		return num.dup;
	}
	return T(num);
}

/// Converts a decimal number to a fixed-precision decimal type
public T toDecimal(T, U)(const U num) if (isDecimal!T && isFixedDecimal!U) {
	static if (is(typeof(num) == T)) {
		return num.dup;
	}
	bool sign = num.sign;
	if (num.isFinite) {
		return T(sign, num.coefficient, num.exponent);
	} else if (num.isInfinite) {
		return T.infinity(sign);
	} else if (num.isSignaling) {
		return T.snan(num.payload);
	} else if (num.isQuiet) {
		return T.nan(num.payload);
	}
	return T.nan;
}

/// Converts a decimal number to a big decimal
public BigDecimal toBigDecimal(T)(const T num) if (isDecimal!T) {
	static if (is(typeof(num) == BigDecimal)) {
		return num.dup;
	}
	bool sign = num.sign;
	if (num.isFinite) {
		auto mant = num.coefficient;
		int  expo = num.exponent;
		return BigDecimal(sign, mant, expo);
	} else if (num.isInfinite) {
		return BigDecimal.infinity(sign);
	} else if (num.isSignaling) {
		return BigDecimal.snan(num.payload);
	} else if (num.isQuiet) {
		return BigDecimal.nan(num.payload);
	}
	return BigDecimal.nan;
}

/// Converts a decimal number to a string
/// using "scientific" notation, per the spec.
public string sciForm(T)(const T num) if (isDecimal!T) {

	if (num.isSpecial) {
		string str = toSpecialString!T(num);
		return num.isSigned ? "-" ~ str : str;
	}

	char[] mant = to!string(num.coefficient).dup;
	int  expo = num.exponent;
	bool signed = num.isSigned;

	int adjx = expo + mant.length - 1;
	// if the exponent is small use decimal notation
	if (expo <= 0 && adjx >= -6) {
		// if the exponent is not zero, insert a decimal point
		if (expo != 0) {
			int point = std.math.abs(expo);
			// if the coefficient is too small, pad with zeroes
			if (point > mant.length) {
				mant = rightJustify(mant, point, '0');
			}
			// if no chars precede the decimal point, prefix a zero
			if (point == mant.length) {
				mant = "0." ~ mant;
			}
			// otherwise insert the decimal point into the string
			else {
				insertInPlace(mant, mant.length - point, ".");
			}
		}
		return signed ? ("-" ~ mant).idup : mant.idup;
	}
	// if the exponent is large enough use exponential notation
	if (mant.length > 1) {
		insertInPlace(mant, 1, ".");
	}
	string xstr = to!string(adjx);
	if (adjx >= 0) {
		xstr = "+" ~ xstr;
	}
	string str = (mant ~ "E" ~ xstr).idup;
	return signed ? "-" ~ str : str;
};  // end sciForm

/// Converts a decimal number to a string
/// using "engineering" notation, per the spec.
public string engForm(T)(const T num) if (isDecimal!T) {

	if (num.isSpecial) {
		string str = toSpecialString!T(num);
		return num.isSigned ? "-" ~ str : str;
	}

	char[] mant = to!string(num.coefficient).dup;
	int  expo = num.exponent;
	bool signed = num.isSigned;

	int adjx = expo + mant.length - 1;
	// if exponent is small, don't use exponential notation
	if (expo <= 0 && adjx >= -6) {
		// if exponent is not zero, insert a decimal point
		if (expo != 0) {
			int point = std.math.abs(expo);
			// if coefficient is too small, pad with zeroes
			if (point > mant.length) {
				mant = rightJustify(mant, point, '0');
			}
			// if no chars precede the decimal point, prefix a zero
			if (point == mant.length) {
				mant = "0." ~ mant;
			}
			// otherwise insert a decimal point
			else {
				insertInPlace(mant, mant.length - point, ".");
			}
		}
		return signed ? ("-" ~ mant).idup : mant.idup;
	}
	// use exponential notation
	if (num.isZero) {
		adjx += 2;
	}
	int mod = adjx % 3;
	// the % operator rounds down; we need it to round to floor.
	if (mod < 0) {
		mod = -(mod + 3);
	}
	int dot = std.math.abs(mod) + 1;
	adjx = adjx - dot + 1;
	if (num.isZero) {
		dot = 1;
		int count = 3 - std.math.abs(mod);
		mant.length = 0;
		for(int i = 0; i < count; i++) {
			mant ~= '0';
		}
	}
	while(dot > mant.length) {
		mant ~= '0';
	}
	if (mant.length > dot) {
		insertInPlace(mant, dot, ".");
	}
	string str = mant.idup;
	if (adjx != 0) {
		string xstr = to!string(adjx);
		if (adjx > 0) {
			xstr = '+' ~ xstr;
		}
		str = str ~ "E" ~ xstr;
	}
	return signed ? "-" ~ str : str;
}  // end engForm()

/// Returns a string representation of a special value.
/// If the number is not a special value an empty string is returned.
/// NOTE: The sign of the number is not included in the string.
private string toSpecialString(T)(const T num,
		bool shortForm = false, bool lower = false, bool upper = false)
		if (isDecimal!T) {

	string str = "";
	if (num.isInfinite) {
		str = shortForm ? "Inf" : "Infinity";
	}
	else if (num.isNaN) {
		str = !shortForm && num.isSignaling ? "sNaN" : "NaN";
		if (num.payload) {
			str ~= to!string(num.payload);
		}
	}
	if (lower) str = toLower(str);
	else if (upper) str = toUpper(str);
	return str;
}

/// Converts a decimal number to a string in decimal format (xxx.xxx).
/// NOTE: The sign of the number is not included in the string.
private string decimalForm(T)
	(const T number, const int precision = 6) if (isDecimal!T) {

	T num = number.dup;
	// check if rounding is needed:
	int diff = num.exponent + precision;
	if (diff < 0) {
		int numPrecision = num.digits + num.exponent + precision;
		DecimalContext context = num.context.setPrecision(numPrecision);
		round!T(num, context);
	}

	// convert the coefficient to a string
	char[] mant = to!string(num.coefficient).dup;
	auto expo = num.exponent;
	auto sign = num.isSigned;
	if (expo >= 0) {
		if (expo > 0) {
			// add zeros up to the decimal point
			mant ~= replicate("0", expo);
		}
		if (precision) {
			// add zeros trailing the decimal point
			mant ~= "." ~ replicate("0", precision);
		}
	}
	else { // (expo < 0)
		int point = -expo;
		// if coefficient is too small, pad with zeros on the left
		if (point > mant.length) {
			mant = rightJustify(mant, point, '0');
			}
		// if no chars precede the decimal point, prefix a zero
		if (point == mant.length) {
			mant = "0." ~ mant;
		}
		// otherwise insert a decimal point
		else {
			insertInPlace(mant, mant.length - point, ".");
		}
		// if result is less than precision, add zeros
		if (point < precision) {
			mant ~= replicate("0", precision - point);
		}
	}
	return mant.idup;
//	return sign ? ("-" ~ mant).idup : mant.idup;
}

unittest {
	write("decimalForm...");
	Dec64 num;
	string expect, actual;
	expect = "123.456789";
	num = Dec64("123.4567890123");
	actual = decimalForm(num);
	assertEqual(expect, actual);
	expect = "123.456790";
	num = Dec64("123.456789500");
	actual = decimalForm(num);
	assertEqual(expect, actual);
	writeln("passed");
}

/// Converts a decimal number to a string using exponential notation.
private string exponentForm(T)(const T number, const int precision = 6,
	const bool lowerCase = false, const bool padExpo = true) if (isDecimal!T) {

	T num = number.dup;
	if (num.context.precision > precision + 1) {
		int numPrecision = precision + 1;
		DecimalContext ctx = num.context.setPrecision(numPrecision);
		round!T(num, ctx);
	}
	char[] mant = to!string(num.coefficient).dup;
	auto expo = num.exponent;
	auto sign = num.isSigned;
	int adjx = expo + mant.length - 1;
	if (mant.length > 1) {
		insertInPlace(mant, 1, ".");
	}
	string xstr = to!string(std.math.abs(adjx));
	if (padExpo && xstr.length < 2) {
		xstr = "0" ~ xstr;
	}
	xstr = adjx < 0 ? "-" ~ xstr : "+" ~ xstr;
	string expoChar = lowerCase ? "e" : "E";
	string str = (mant ~ expoChar ~ xstr).idup;
	return sign ? "-" ~ str : str;
}  // end exponentForm

unittest {
	write("exponentForm...");
	Dec64 num;
	string expect, actual;
	num = Dec64("123.4567890123");
	actual = exponentForm!Dec64(num);
	expect = "1.234568E+02";
	assertEqual(expect, actual);
	num = Dec64("123.456789500");
	actual = exponentForm!Dec64(num);
//	expect = "123.456790";
	assertEqual(expect, actual);
	writeln("passed");
}

//public string toString(T)(const T num, string fmt) {
//	return "surprise!";
//}

private void writeTo(T)(const T num, scope void delegate(const(char)[]) sink,
	const char formatChar, const int precision) if (isDecimal!T) {


}

/// toString(num, width, precision, expo)
private string formatDecimal(T)(const T num,
	const char formatChar, const int precision) if (isDecimal!T) {

	bool lowerCase = std.uni.isLower(formatChar);
	bool upperCase = std.uni.isUpper(formatChar);

	// special values
	if (num.isSpecial) {
		return toSpecialString!T(num, false, lowerCase, upperCase);
	}

	switch (std.uni.toUpper(formatChar)) {
		case 'F':
			return decimalForm(num, precision);
		case 'G':
			int expo = num.exponent;
			if (expo > -5 && expo < precision) {
				return decimalForm(num, precision);
			}
			break;
		case 'E':
			break;
		default:
			break;
	}
	return exponentForm(num, precision, lowerCase, true);
}

/// Returns the string with the prefix inserted at the front. If the
/// prefix string is empty, returns the original string.
private string addPrefix(string str, string prefix) {
	if (prefix == "") {
		return str;
	}
	return prefix ~ str;
}

/// Returns the string with a prefix inserted at the front. The prefix
/// character is based on the value of the flags.
/// If none of the flags are true, returns the original string.
private string addPrefix(string str, bool flSign, bool flPlus, bool flSpace) {

	if (!flSign && !flPlus && !flSpace) return str;

	string prefix;
	if      (flSign) prefix = "-";
	else if (flPlus) prefix = "+";
	else if (flSpace) prefix = " ";
	return prefix ~ str;
}

/// Returns a string that is at least as long as the specified width. If the
/// string is already greater than or equal to the specified width the original
/// string is returned. If the specified width is negative or if the
/// flag is set the widened string is left justified.
private string setWidth(const string str, int width,
		bool justifyLeft = false, bool padZero = false) {

	if (str.length >= std.math.abs(width)) return str;

	char fillChar = padZero ? '0' : ' ';
	if (width < 0) {
		justifyLeft = true;
		width = -width;
	}
	if (justifyLeft) {
		fillChar = ' ';
		return leftJustify!string(str, width, fillChar);
	}
	return rightJustify!string(str, width, fillChar);
}

/*
        auto f = FormatSpec!char(formatString);
        f.writeUpToNextSpec(sink);
        toString(sink, f);

void toString(scope void delegate(const(char)[]) sink, string fmt) {
	auto spec = FormatSpec(fmt);
}*/

private void sink(const(char)[] str) {
    auto app = std.array.appender!(string)();
	app.put(str);
}

/// Returns a string representing the value of the number, formatted as
/// specified by the formatString.
public string toString(T)(const T num, const string formatString = "") if (isDecimal!T) {
    auto a = std.array.appender!(const(char)[])();
//	string outbuff = "";
	void sink(const(char)[] s) {
		a.put(s);
	}
	writeTo!T(num, &sink, formatString);
    auto f = FormatSpec!char(formatString);
    f.writeUpToNextSpec(a);
    string str = formatDecimal!T(num, f.spec, f.precision);
	// add trailing zeros
	if (f.flHash && str.indexOf('.' < 0)) {
		str ~= ".0";
	}
	// add prefix
	string prefix;
	if (num.isSigned)   prefix = "-";
	else if (f.flPlus)  prefix = "+";
	else if (f.flSpace) prefix = " ";
	else prefix = "";
	str = addPrefix(str, prefix);
	// adjust width
	str = setWidth(str, f.width, f.flZero, f.flDash);
	return str;
}

unittest {
	write("toString...");
	string expect, actual;
	Dec32 num = 2;
	actual = toString!Dec32(num, "%9.6e"); //3.3g41");
	actual = toString!Dec32(num, "%-9.6e"); //3.3g41");
	actual = toString!Dec32(num, "%9.6e"); //3.3g41");
	expect = "    2e+00";
	assertEqual(expect, actual);
	writeln("passed");
}


// (V)TODO: Doesn't work yet. Uncertain how to merge the string versions
// with the sink versions.
/// Converts a decimal number to a string representation.
void writeTo(T)(const T num, scope void delegate(const(char)[]) sink,
		string fmt = "") if (isDecimal!T) {


};  // end writeTo

/// Converts a string into a BigDecimal.
public BigDecimal toNumber(const string inStr) {
	BigDecimal num;
	BigDecimal NAN = BigDecimal.nan;
	bool sign = false;
	// strip, copy, tolower
	char[] str = strip(inStr).dup;
	toLowerInPlace(str);
	// get sign, if any
	if (startsWith(str, "-")) {
		sign = true;
		str = str[1..$];
	} else if (startsWith(str, "+")) {
		str = str[1..$];
	}
	// check for NaN
	if (startsWith(str, "nan")) {
		num = NAN;
		num.sign = sign;
		// if no payload, return
		if (str == "nan") {
			return num;
		}
		// set payload
		str = str[3..$];
		// payload has a max length of 6 digits
		if (str.length > 6) return NAN;
		// ensure string is all digits
		foreach(char c; str) {
			if (!isDigit(c)) {
				return NAN;
			}
		}
		// convert string to number
		uint payload = std.conv.to!uint(str);
		// check for overflow
		if (payload > ushort.max) {
			return NAN;
		}
		num.payload = cast(ushort)payload;
		return num;
	};
	// check for sNaN
	if (startsWith(str, "snan")) {
		num = BigDecimal.snan;
		num.sign = sign;
		if (str == "snan") {
			num.payload = 0;
			return num;
		}
		// set payload
		str = str[4..$];
		// payload has a max length of 6 digits
		if (str.length > 6) return NAN;
		// ensure string is all digits
		foreach(char c; str) {
			if (!isDigit(c)) {
				return NAN;
			}
		}
		// convert string to payload
		uint payload = std.conv.to!uint(str);
		// check for overflow
		if (payload > ushort.max) {
			return NAN;
		}
		num.payload = cast(ushort)payload;
		return num;
	};
	// check for infinity
	if (str == "inf" || str == "infinity") {
		num = BigDecimal.infinity(sign);
		return num;
	};
	// at this point, num must be finite
	num = BigDecimal.zero(sign);
	// check for exponent
	int pos = indexOf(str, 'e');
	if (pos > 0) {
		// if it's just a trailing 'e', return NaN
		if (pos == str.length - 1) {
			return NAN;
		}
		// split the string into coefficient and exponent
		char[] xstr = str[pos + 1..$];
		str = str[0..pos];
		// assume exponent is positive
		bool xneg = false;
		// check for minus sign
		if (startsWith(xstr, "-")) {
			xneg = true;
			xstr = xstr[1..$];
		}
		// check for plus sign
		else if (startsWith(xstr, "+")) {
			xstr = xstr[1..$];
		}
		// ensure it's not now empty
		if (xstr.length < 1) {
			return NAN;
		}
		// ensure exponent is all digits
		foreach(char c; xstr) {
			if (!isDigit(c)) {
				return NAN;
			}
		}
		// trim leading zeros
		while(xstr[0] == '0' && xstr.length > 1) {
			xstr = xstr[1..$];
		}
		// make sure it will fit into an int
		if (xstr.length > 10) {
			return NAN;
		}
		if (xstr.length == 10) {
			// try to convert it to a long (should work) and
			// then see if the long value is too big (or small)
			long lex = std.conv.to!long(xstr);
			if ((xneg && (-lex < int.min)) || lex > int.max) {
				return NAN;
			}
			num.exponent = cast(int) lex;
		} else {
			// everything should be copacetic at this point
			num.exponent = std.conv.to!int(xstr);
		}
		if (xneg) {
			num.exponent = -num.exponent;
		}
	} else {
		num.exponent = 0;
	}
	// remove trailing decimal point
	if (endsWith(str, ".")) {
		str = str[0..$ -1];
	}
	// strip leading zeros
	while(str[0] == '0' && str.length > 1) {
		str = str[1..$];
	}
	// remove internal decimal point
	int point = indexOf(str, '.');
	if (point >= 0) {
		// excise the point and adjust the exponent
		str = str[0..point] ~ str[point + 1..$];
		int diff = str.length - point;
		num.exponent = num.exponent - diff;
	}
	// ensure string is not empty
	if (str.length < 1) {
		return NAN;
	}
	// ensure string is all digits
	foreach(char c; str) {
		if (!isDigit(c)) {
			return NAN;
		}
	}
	// convert coefficient string to BigInt
	num.coefficient = BigInt(str.idup);
	num.digits = decimal.rounding.numDigits(num.coefficient);
	return num;
}

/// Returns an abstract string representation of a number.
/// The abstract representation is described in the specification. (p. 9-12)
public string toAbstract(T)(const T num) if (isDecimal!T) {
	if (num.isFinite) {
		return format("[%d,%s,%d]", num.sign ? 1 : 0,
		              to!string(num.coefficient), num.exponent);
	}
	if (num.isInfinite) {
		return format("[%d,%s]", num.sign ? 1 : 0, "inf");
	}
	if (num.isQuiet) {
		if (num.payload) {
			return format("[%d,%s%d]", num.sign ? 1 : 0, "qNaN", num.payload);
		}
		return format("[%d,%s]", num.sign ? 1 : 0, "qNaN");
	}
	if (num.isSignaling) {
		if (num.payload) {
			return format("[%d,%s%d]", num.sign ? 1 : 0, "sNaN", num.payload);
		}
		return format("[%d,%s]", num.sign ? 1 : 0, "sNaN");
	}
	return "[0,qNAN]";
}

// (V)TODO: Does exact representation really return a round-trip value?
/// Returns a full, exact representation of a number. Similar to toAbstract,
/// but it provides a valid string that can be converted back into a number.
public string toExact(T)(const T num) if (isDecimal!T) {
	if (num.isFinite) {
		return format("%s%sE%s%02d", num.sign ? "-" : "+",
		              to!string(num.coefficient),
		              num.exponent < 0 ? "-" : "+", std.math.abs(num.exponent));
	}
	if (num.isInfinite) {
		return format("%s%s", num.sign ? "-" : "+", "Infinity");
	}
	if (num.isQuiet) {
		if (num.payload) {
			return format("%s%s%d", num.sign ? "-" : "+", "NaN", num.payload);
		}
		return format("%s%s", num.sign ? "-" : "+", "NaN");
	}
	if (num.isSignaling) {
		if (num.payload) {
			return format("%s%s%d", num.sign ? "-" : "+", "sNaN", num.payload);
		}
		return format("%s%s", num.sign ? "-" : "+", "sNaN");
	}
	return "+NaN";
}

//--------------------------------
//  unittests
//--------------------------------

unittest {
	writeln("===================");
	writeln("conv..........begin");
	writeln("===================");
}

unittest {
	write("toDecimal...");
	BigDecimal big;
	Dec32 expect, actual;
	big = BigDecimal(12345E-8);
	expect = Dec32(12345E-8);
	actual = toDecimal!(Dec32,BigDecimal)(big);
	assertEqual(expect, actual);
	assertEqual(typeid(typeof(expect)), typeid(typeof(actual)));
	Dec64 rexpect, ractual;
	big = BigDecimal(12345E-8);
	rexpect = Dec64(12345E-8);
	ractual = toDecimal!(Dec64,BigDecimal)(big);
	assertEqual(rexpect, ractual);
	assertEqual(typeid(typeof(rexpect)), typeid(typeof(ractual)));
	Dec64 d64 = Dec64(12345E-8);
	expect = Dec32(12345E-8);
	actual = toDecimal!(Dec32,Dec64)(d64);
	assertEqual(expect, actual);
	assertEqual(typeid(typeof(rexpect)), typeid(typeof(ractual)));
	writeln("passed");
}

unittest {	// toBigDecimal
	Dec32 small;
	BigDecimal big;
	small = 5;
	big = toBigDecimal!Dec32(small);
	assertTrue(big.toString == small.toString);
}

unittest {	// isXxxDecimal
	assertTrue(isFixedDecimal!Dec32);
	assertTrue(!isFixedDecimal!BigDecimal);
	assertTrue(isDecimal!Dec32);
	assertTrue(isDecimal!BigDecimal);
	assertTrue(!isBigDecimal!Dec32);
	assertTrue(isBigDecimal!BigDecimal);
}

unittest {
	write("sciForm...");
	writeln("test missing");
}

unittest {
	write("engForm...");
	writeln("test missing");
}

unittest {
	write("toSpecialString...");
	BigDecimal num;
	string expect, actual;
	num = BigDecimal("inf");
	actual = toSpecialString(num);
	expect = "Infinity";
	assertEqual(expect, actual);
	actual = toSpecialString(num, true);
	expect = "Inf";
	assertEqual(expect, actual);
	writeln("passed");
}

unittest {
	write("decimalForm...");
	Dec32 num;
	string expect, actual;
	num = Dec32(125);
	expect = "125.000";
	actual = decimalForm(num, 3);
	assertEqual(expect, actual);
	num = Dec32(125E5);
	expect = "12500000";
	actual = decimalForm(num);
	assertEqual(expect, actual);
	num = Dec32(1.25);
	expect = "1.25";
	actual = decimalForm(num);
	assertEqual(expect, actual);
	num = Dec32(125E-5);
	expect = "0.001250";
	actual = decimalForm(num, 6);
	assertEqual(expect, actual);
	writeln("passed");
}

unittest {
	write("exponentForm...");
	Dec32 num;
	string expect, actual;
	num = Dec32(125);
	expect = "1.25E+02";
	actual = exponentForm(num);
	assertEqual(expect, actual);
	expect = "1.25e+2";
	actual = exponentForm(num, 6, true, false);
	assertEqual(expect, actual);
	num = Dec32(125E5);
	expect = "1.25E+07";
	actual = exponentForm(num);
	assertEqual(expect, actual);
	num = Dec32(1.25);
	expect = "1.25E+00";
	actual = exponentForm(num);
	assertEqual(expect, actual);
	num = Dec32(125E-5);
	expect = "1.25E-03";
	actual = exponentForm(num);
	assertEqual(expect, actual);
	writeln("passed");
}

unittest {	// sciForm
	Dec32 num = Dec32(123); //(false, 123, 0);
	assertTrue(sciForm!Dec32(num) == "123");
	assertTrue(num.toAbstract() == "[0,123,0]");
	num = Dec32(-123, 0);
	assertTrue(sciForm!Dec32(num) == "-123");
	assertTrue(num.toAbstract() == "[1,123,0]");
	num = Dec32(123, 1);
	assertTrue(sciForm!Dec32(num) == "1.23E+3");
	assertTrue(num.toAbstract() == "[0,123,1]");
	num = Dec32(123, 3);
	assertTrue(sciForm!Dec32(num) == "1.23E+5");
	assertTrue(num.toAbstract() == "[0,123,3]");
	num = Dec32(123, -1);
	assertTrue(sciForm!Dec32(num) == "12.3");
	assertTrue(num.toAbstract() == "[0,123,-1]");
	num = Dec32("inf");
	assertTrue(sciForm!Dec32(num) == "Infinity");
	assertTrue(num.toAbstract() == "[0,inf]");
	string str = "1.23E+3";
	BigDecimal dec = BigDecimal(str);
	assertTrue(engForm!BigDecimal(dec) == str);
	str = "123E+3";
	dec = BigDecimal(str);
	assertTrue(engForm!BigDecimal(dec) == str);
	str = "12.3E-9";
	dec = BigDecimal(str);
	assertTrue(engForm!BigDecimal(dec) == str);
	str = "-123E-12";
	dec = BigDecimal(str);
	assertTrue(engForm!BigDecimal(dec) == str);
}

unittest {
	write("addPrefix....");
	string str, expect, actual;
	str = "100.54";
	expect = "100.54";
	actual = addPrefix(str, "");
	assertEqual(expect, actual);
	assert(expect is actual);
	expect = "-100.54";
	actual = addPrefix(str, "-");
	assertEqual(expect, actual);
	expect = " 100.54";
	actual = addPrefix(str, " ");
	assertEqual(expect, actual);
	expect = "+100.54";
	actual = addPrefix(str, "+");
	assertEqual(expect, actual);
	writeln("passed");
}

unittest {
	write("setWidth...");
	string str, expect, actual;
	str = "10E+05";
	expect = "  10E+05";
	actual = setWidth(str, 8);
	assertEqual(expect, actual);
	expect = "10E+05  ";
	actual = setWidth(str, 8, true);
	assertEqual(expect, actual);
	expect = "10E+05  ";
	actual = setWidth(str, -8);
	assertEqual(expect, actual);
	expect = "0010E+05";
	actual = setWidth(str, 8, false, true);
	assertEqual(expect, actual);
	writeln("passed");
}

unittest {
	write("writeTo...");
	writeln("test missing");
}

unittest {	// toNumber
	BigDecimal f = BigDecimal("1.0");
	assertTrue(f.toString() == "1.0");
	f = BigDecimal(".1");
	assertTrue(f.toString() == "0.1");
	f = BigDecimal("-123");
	assertTrue(f.toString() == "-123");
	f = BigDecimal("1.23E3");
	assertTrue(f.toString() == "1.23E+3");
	f = BigDecimal("1.23E-3");
	assertTrue(f.toString() == "0.00123");
}

unittest {
	write("toAbstract...");
	writeln("test missing");
}

unittest {
	write("toExact...");
	writeln("test missing");
}

unittest {
	writeln("===================");
	writeln("conv............end");
	writeln("===================");
}
