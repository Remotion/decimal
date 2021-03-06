﻿// Written in the D programming language

/**
 *	Copyright Paul D. Anderson 2009 - 2013.
 *	Distributed under the Boost Software License, Version 1.0.
 *	(See accompanying file LICENSE_1_0.txt or copy at
 *	http://www.boost.org/LICENSE_1_0.txt)
**/

module xint;

import std.ascii;
import std.bigint;
import std.conv;
import std.stdio;
import std.string;
import std.traits;

unittest {
	writeln("===================");
	writeln("xint..........begin");
	writeln("===================");
}

alias UXInt!128 uint128; //16 bytes
alias UXInt!256 uint256; //32 bytes

alias XInt!128 int128; //16 bytes
alias XInt!256 int256; //32 bytes

//pragma( msg ,"uint128.sizeof ", uint128.sizeof); //16 bytes
//pragma( msg ,"uint256.sizeof ", uint256.sizeof); //32 bytes
//pragma( msg ,"int128.sizeof ", int128.sizeof); //16 bytes
//pragma( msg ,"int256.sizeof ", int256.sizeof); //32 bytes

public enum OverflowMode {
	IGNORE,
	CLAMP,
	THROW
};

public enum ulong BASE = 1UL << 32;


public struct UXInt(int Z,
	OverflowMode overflow = OverflowMode.IGNORE) 
{

	unittest {
		writeln("===================");
		writeln("unsigned......begin");
		writeln("===================");
	}

//--------------------------------
// structure
//--------------------------------

	// The number of uint digits in an extended integer
	private enum uint N = Z/32;

	/// Array of the (uint) digits of an extended integer
	///	The digits are stored in increasing value:
	/// least significant digit is digits[0],
	/// most significiant digit is digits[N-1]
	private uint[N] digits; // = 0;

//--------------------------------
// digits
//--------------------------------

	/// Returns the number of digits in the extended integer.
	@property
	public static uint size() {
		return N;
	}

	/// Returns the value of the nth digit in the extended integer.
	/// getDigit(0) returns the most significant digit.
	/// getDigit(size-1) returns the least significant digit.
	public const uint getDigit(uint n) {
writefln("n = %s", n);
writefln("N = %s", N);
writefln("N-n = %s", N-n);
writefln("N-n+1 = %s", N-n+1);
writefln("N-n-1 = %s", N-n-1);
		int i = N-n-1;
writefln("i = %s", i);
//writeln();
		return cast(uint)digits[i];
	}

	/// Returns the value of the nth word in the extended integer.
	/// getWord(0) returns the most significant word.
	/// getWord(size-1) returns the least significant word.
	public const ulong getWord(int index) {
		index *= 2;
		return pack(digits[N-1 - index], digits[N-2 - index]);
	}

	/// Sets the nth word in the extended integer to the specified value.
	/// setWord(size-1, value) sets the value of the most significant word.
	public void setWord(int index, ulong value) {
		index *= 2;
		digits[N-1 - index] = high(value);
		digits[N-2 - index] = low(value);
	}

	unittest {
		write("digits...");
		uint128 num;
		num = uint128([1u,2u,3u,4u]);
		uint first = num.getDigit(0);
		assert(first == 4);
	writefln("Z = %s", Z);
	writefln("N = %s", N);
	writefln("N-1 = %s", size-1);
		uint last = num.getDigit(3);
		assert(last == 1);
		ulong firstword = num.getWord(0);
		assert(firstword == 0x400000003);
		ulong lastword = num.getWord(1);
		assert(lastword == 0x200000001);
		writeln("test missing");
	}

//--------------------------------
// bit manipulation
//--------------------------------

	/// Sets a single bit in an unsigned extended integer.
	public void setBit(int n, bool value = true) {
		if (value) {
			this |= shl(ONE, n);
		}
		else {
			this &= complement(shl(ONE, n));
		}
	}

	/// Tests a single bit in an unsigned extended integer.
	public const bool testBit(int n) {
		UXInt!Z value = this & shl(ONE, n);
		return !value.isZero;
	}

	unittest {	// bit manipulation
		uint128 test = uint128(0);
		assert(!test.testBit(5));
		test.setBit(5);
		assert(test.testBit(5));
	}

/*	public const setBits(int n, int count, uint value) {
	};

	public const bool testBits(int n, int count, uint value) {
		return false;
	}*/

	unittest {	// get/set long values
		write("get/set long values...");
		writeln("test missing");
	}

//--------------------------------
// construction
//--------------------------------

	/// Private constructor for internal use.
	/// Constructs an extended integer from an array of
	/// unsigned integer values. In the internal array
	/// digits[0] is the least significant digit while
	/// digits[$-1] is most significant digit. This
	/// is the reverse of the public constructor and
	/// of the get/set digit and word methods.
	private this(const uint[] array) {
		ulong len = array.length >= N ? N : array.length;
		for (ulong i = 0; i < len; i++)
			digits[i] = array[i];
	}

	/// Constructs an extended integer from a list of unsigned long values.
	///	The list can be a single value, a comma-separated list or an array.
	/// The list is ordered left to right:
	/// Most significant digit first, least significant digit last.
	public this(const ulong[] list ...) {
		ulong len = list.length >= N/2 ? N/2 : list.length;
		for (ulong i = 0; i < len; i++) {
			digits[2*i]   = low(list[len-i-1]);
			digits[2*i+1] = high(list[len-i-1]);
		}
	}


	unittest {	// construction
		uint128 num, expected;
		assert(uint128(7) == uint128(7));
		assert(uint128(17) != uint128(7));
		assert(uint128(7UL) == uint128(7));
		assert(uint128([7UL]) == uint128(7));
		expected = 7503;
		num = uint128(7503UL);
		assert(num == expected);
		expected = uint128("138405920785042765774860");
		num = uint128(7503UL, 12UL);
		assert(num == expected);
		// array of unsigned longs
		num = uint128([7503UL, 12UL]);
		assert(num == expected);
		// array of unsigned ints
		num = uint128([7503U, 12U]);
		assert(num != expected);

		num = uint128([7503UL]);
		assert(num.digits[0] == 7503);
		assert(num.digits[0] != 7502);
		num = uint128(2^^16);
		assert(num == 65536);
		num = uint128(uint.max);
		assert(num == "4294967295");
		num = uint128(cast(ulong)uint.max + 1);
		num = 4294967296;
		assert(num.digits[0] == 0);
		assert(num.digits[1] == 1);
		num.digits[0] = 16;
		num.digits[1] = 32;
		assert(num == 137438953488);
	}

//--------------------------------
// constants
//--------------------------------

	public enum UXInt!Z ZERO = UXInt!Z(0);
	public enum UXInt!Z ONE  = UXInt!Z(1);

//--------------------------------
// copy
//--------------------------------

	/// Constructs a copy of the extended integer.
	public this(const UXInt!Z that) {
		this.digits = that.digits;
	}

	/// Returns a copy of the extended integer.
	public const UXInt!Z dup() {
		return UXInt!Z(this);
	}

	unittest {	// copy
		uint128 num = uint128(9305);
		assert(uint128(num) == num);
		assert(num.dup == num);
	}

//--------------------------------
// string constructor
//--------------------------------

	public this(const string str) {
		auto value = new uint[N];
		char[] chars = strip(str.dup);
		// if the string start withs a non-zero digit,
		// it must be a decimal number.
		if (chars[0] != '0') {
			parseDecimal(chars);
		}
		// Otherwise it may be hex or binary
		toLowerInPlace(chars);
		if (startsWith(chars, "0x")) {
			value = parseHex(chars[2..$]);
		} else if (startsWith(chars, "0b")) {
			value = parseBinary(chars[2..$]);
		} else {
			value = parseDecimal(chars);
		}
		this(value);
	}

	private static uint[] parseHex(/*ref*/ in char[] chars) {
		auto value = new uint[N];
		uint charValue = 0;
		foreach (char ch; chars) {
			if (ch == '_') continue;
			if (!isHexDigit(ch)) {
			throw new ConvException("Invalid hexadecimal character: [" ~ ch ~ "]");
			}
			value = mulDigit(value, 16);
			if (isDigit(ch)) {
				charValue = ch - '0';
			}
			else {
				charValue = ch - 'a' + 10;
			}
			value = addDigit(value, charValue);
		}
		return value;
	}

	private static uint[] parseBinary(/*ref*/ in char[] chars) {
		auto value = new uint[N];
		uint charValue = 0;
		foreach (char ch; chars) {
			if (ch == '_') continue;
			if (ch != '0' && ch != '1') throw
				new ConvException("[" ~ ch ~ "] is not a binary character");
			value = mulDigit(value, 2);
			if (ch == '1') value = addDigit(value, 1);
		}
		return value;
	}

	private static uint[] parseDecimal(ref char[] chars) {
		auto value = new uint[N];
		if (!isDigit(chars[0])) {
			throw new ConvException("Invalid initial character: [" ~ chars[0] ~ "]");
		}
		foreach (char ch; chars) {
			if (ch == '_') continue;
			if (!isDigit(ch)) {
			throw new ConvException("Invalid decimal character: [" ~ ch ~ "]");
			}
			value = mulDigit(value, 10U);
			value = addDigit(value, cast(uint)(ch - '0'));
		}
		return value;
	}

	unittest {
		string str;
		uint128 num;
		num = uint128(123);
		str = "123";
		assert(num == uint128(str));
		str = "0x7B";
		assert(num == uint128(str));
		str = "0b1111011";
		assert(num == uint128(str));
		str = "0_234_445";
		num = uint128(str);
		assert(num == 234445);
	}


//--------------------------------
// properties
//--------------------------------

	/// Returns zero, the initial value for extended integer types.
	@property
	public static UXInt!Z init() {
		return ZERO;
	}

	/// Returns the maximum value for this type.
	/// For unsigned extended integers the maximum value is 0xFF...FF.
	public static UXInt!Z max() {
		static UXInt!Z value;
		static bool initialized = false;
		if (initialized) return value;
		for (int i = 0; i < N; i++) {
			value.digits[i] = uint.max;
		}
		initialized = true;
		return value;
	}

	/// Returns the minimum value for this type.
	/// For unsigned extended integers the minimum value is 0x00...00.
	public static UXInt!Z min() {
		static UXInt!Z value;
		static bool initialized = false;
		if (initialized) return value;
		value = UXInt!Z(0);
		initialized = true;
		return value;
	}


	// TODO: move this to abs() or negate().
	/// Returns the larger of the two extended integers.
	public static UXInt!Z max(const UXInt!Z arg1, const UXInt!Z arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}

	unittest {
		int128 a = 5;
		int128 b = 7;
		assert(int128.max(a,b) == 7);
		assert( XInt!64.max == long.max);
		assert(UXInt!64.max == ulong.max);
		assert( XInt!64.min == long.min);
		assert(UXInt!64.min == ulong.min);
		assert(XInt!256.max.toString == "57896044618658097711785492504343953926634992332820282019728792003956564819967");
		assert(XInt!256.min.toString == "-57896044618658097711785492504343953926634992332820282019728792003956564819968");
		assert(UXInt!256.max.toString == "115792089237316195423570985008687907853269984665640564039457584007913129639935");
	//writefln("max(int128(5), int128(7)) = %s", max!int128(int128(5), int128(7)));
	/*writefln("UXInt!(256,true).max.toHexString = %s", UXInt!(256,true).max.toHexString);
	writefln("UXInt!(256,false).max.toHexString = %s", UXInt!(256,false).max.toHexString);
	writefln("UXInt!(256,true).min.toHexString = %s", UXInt!(256,true).min.toHexString);
	writefln("UXInt!(256,false).min.toHexString = %s", UXInt!(256,false).min.toHexString);
	writefln("UXInt!(256,true).max = %s", UXInt!(256,true).max);
	writefln("UXInt!(256,false).max = %s", UXInt!(256,false).max);
	writefln("UXInt!(256,true).min = %s", UXInt!(256,true).min);
	writefln("UXInt!(256,false).min = %s", UXInt!(256,false).min);*/
	}

//--------------------------------
// classification
//--------------------------------

	/// Returns true if the value of the extended integer is zero.
	public const bool isZero() {
		return numDigits(this.digits) == 0;
	}

	/// Returns true if the value of the extended integer is less than zero.
	/// For unsigned extended integers the return value is always false.
	public const bool isNegative() {
			return false;
	}

	/// Returns true if the value of the extended integer is odd.
	public const bool isOdd() {
		return digits[0] & 1;
	}

	/// Returns true if the value of the extended integer is even.
	public const bool isEven() {
		return !isOdd();
	}

//--------------------------------
// conversion
//--------------------------------

	/// Converts the extended integer value to a string.
	public const string toString() {
		char[] str;
		uint[] from = this.dup.digits;
		uint n = numDigits(from);
		if (n == 0) return "0";
		while (n > 0) {
			uint mod;
			char[1] ch;
			from = divmodDigit(from, n, 10, mod);
			std.string.sformat(ch, "%d", mod);
			str = ch ~ str;
			n = numDigits(from);
		}
		return str.idup;
	}

	/// Converts the extended integer value to a hexadecimal string.
	public const string toHexString() {
		char[] str;
		int length = numDigits(digits);
		if (length == 0) {
			return ("0x00000000");
		}
		for (int i = 0; i < length; i++) {
			str = std.string.format("_%08X", digits[i]) ~ str;
		}
		return "0x" ~ str[1..$].idup;
	}

/*	/// Converts the extended integer value to a hexadecimal string.
	public const string toBinaryString() {
		char[] str;
		int length = numDigits(digits);
		if (length == 0) {
			return ("0b00000000");
		}
		for (int i = 0; i < length; i++) {
			str = std.string.format("_%08X", digits[i]) ~ str;
		}
		return "0x" ~ str[1..$].idup;
	}*/

	unittest // toString
	{
		uint128 a;
		a = uint128([11UL]);
		assert("11" == a.toString);
		a = uint128(1234567890123);
		assert(a.toString == "1234567890123");
		a = uint128(0x4872EACF123346FF);
		assert(a.toString == "5220493093160306431");
		assert(uint128(156).toHexString == "0x0000009C");
	}

	/// Converts the unsigned extended integer to an unsigned integer.
	public const uint toUint() {
		return this > uint.max ? uint.max : cast(uint)digits[0];
	}

	/// Converts the unsigned extended integer to an unsigned long integer.
	public const ulong toUlong() {
		return this > ulong.max ? ulong.max : getWord(1);
	}

	/// Converts the unsigned extended integer to an integer.
	public const int toInt() {
		return this > int.max ? int.max : cast(int)digits[0];
	}

	/// Converts the unsigned extended integer to a long integer.
	public const long toLong() {
		return this > long.max ? long.max : cast(long)getWord(1);
	}

	unittest {	// conversion
		assert(uint128(8754).toUint == 8754);
		assert(uint128(9100).toUlong == 9100L);
		// TODO: test conversion from 3+ digit numbers
	}

	/// Converts the unsigned extended integer value to a big integer.
	public const BigInt toBigInt() {
		BigInt big = BigInt(0);
		for (int i = 0; i < N; i++) {
			big = big * BASE + digits[N-1-i];
		}
		return big;
	}

	/// Constructs an unsigned extended integer from a big integer.
	public this(const BigInt big) {
		static BigInt base = BigInt(BASE);
		// TODO: this returns abs(big) -- do we want cast(unsigned) big?
		BigInt value = cast(BigInt) big;
		ulong len = value.uintLength;
		if (len > N) len = N;
		for (int i = 0; i < len; i++) {
			digits[i] = cast(uint)(value % base).toLong;
			value /= base;
			if (value == 0) break;
		}
	}

	unittest {	// BigInt interoperability
		// TODO: test with multi-digits numbers
		// TODO: test with BigInts too large to fit into UXInt!Z.
		BigInt big = 5;
		uint128 num = 21;
		assert(big != num);
		assert(num != big);
		assert(big < num);
		assert(num > big);
		assert(uint128(big) == 5);
		big = num.toBigInt;
		assert(big == 21);
		assert(big == num);
	}

//--------------------------------
// internal values
//--------------------------------

//--------------------------------
// comparison
//--------------------------------

	/// Returns -1, 0, or 1, if this extended integer is, respectively,
	/// less than, equal to or greater than the argument.
	private const int opCmp(T:UXInt!Z)(const T that) {
		return compare(this.digits, that.digits);
	}

	/// Returns -1, 0, or 1, if this extended integer is, respectively,
	/// less than, equal to or greater than the argument.
	private const int opCmp(T)(const T that) {
		return opCmp(UXInt!Z(that));
	}

	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T:UXInt!Z)(const T that) {
		return this.digits == that.digits;
	}

	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T)(const T that){
		return opEquals(UXInt!Z(that));
	}

	unittest { // comparison
		assert(uint128(5) < uint128(6));
		assert(uint128(5) < 6);
		assert(uint128(3) < uint128(10));
		assert(uint128(195) >= uint128(195));
		assert(uint128(195) >= 195);

		assert(int128(5) < int128(6));
		assert(int128(5) < 6);
		assert(int128(3) < int128(10));
		assert(int128(195) >= int128(195));
		assert(int128(195) >= 195);

		assert(int128(-5) > int128(-6));
		assert(int128(-5) < int128(6));
		assert(int128(3) > int128(-10));
		assert(int128(10) > int128(-3));
		assert(int128(195) >= int128(195));
		assert(int128(195) >= -195);
	}

//	public static UXInt!Z max(const UXInt!Z arg1, const UXInt!Z arg2) {
//		if (arg1 < arg2) return arg2;
//		return arg1;
//	}
//	public static UXInt!Z max(const UXInt!Z arg1, const UXInt!Z arg2) {
//		if (arg1 < arg2) return arg2;
//		return arg1;
//	}

/*	public const T max(T)(const T arg1, const T arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/

	public static UXInt!Z min(const UXInt!Z arg1, const UXInt!Z arg2) {
		if (arg1 > arg2) return arg2;
		return arg1;
	}

unittest {
	write("max, min...");
	// TODO: fix this once and for all
/*	int128 a = 5;
	int128 b = 7;
writefln("max(a,b) = %s", max(a,b));
writefln("min(a,b) = %s", min(a,b));
//	assert(max(int128(5), int128(7)) == 7);*/
	writeln("test missing");
}

//--------------------------------
// indexing and assignment
//--------------------------------

/*	private const uint opIndex(const uint i) {
		return digits[i];
	}

	private void opIndexAssign(T)
			(const T that, const uint i) if (isIntegral!T) {
		digits[i] = cast(uint)that;
	}*/

	/// Assigns an unsigned extended integer value to this.
	private void opAssign(T:UXInt!Z)(const T that) {
		this.digits = that.digits;
	}

	/// Assigns an integral value to this.
	private void opAssign(T)(const T that) {
		opAssign(UXInt!Z(that));
	}

	unittest {	// assignment
		uint128 actual = uint128(123);
		uint128 expect = actual;
		assert(actual == expect);
		actual = 123L;
		assert(actual == expect);
		actual = BigInt(123);
		assert(actual == expect);
		actual = "123";
		assert(actual == expect);
	}

	/// Performs an operation on this and assigns the result to this.
	private ref UXInt!Z opOpAssign(string op, T:UXInt!Z)(const T that) {
		this = opBinary!op(that);
		return this;
	}

	/// Performs an operation on this and assigns the result to this.
	private ref UXInt!Z opOpAssign(string op, T)(const T that) {
		this = opBinary!op(that);
		return this;
	}

//--------------------------------
// unary operations
//--------------------------------

	private UXInt!Z opUnary(string op)() {
		static if (op == "+") {
			return plus();
		} else static if (op == "-") {
			return negate(this);
		} else static if (op == "~") {
			return complement(this);
		}else static if (op == "++") {
			this = add(this, ONE);
			return this;
		} else static if (op == "--") {
			this = sub(this, ONE);
			return this;
		}
	}

	/// Returns a copy of this unsigned extended integer
	public const UXInt!Z plus() {
		return UXInt!Z(this.digits);
	}

	/// Returns the one's complement of this unsigned extended integer
	public static UXInt!Z complement(const UXInt!Z arg) {
		auto cmp = arg.dup;
		for (uint i = 0; i < N; i++)
			cmp.digits[i] = ~arg.digits[i];
		return cmp;
	}

/*	public const UXInt!Z complement()() {
		return complement(this);
	}*/

	/// Returns the two's complement of this unsigned extended integer
	public static UXInt!Z negate(const UXInt!Z arg) {
		auto neg = complement(arg);
		return ++neg;
	}

/*	public const UXInt!Z negate()() {
		auto w = this.complement;
		return ++w;
	}*/

	unittest {	// opUnary
		uint128 op1 = 4;
		assert(+op1 == op1);
//		assert( -op1 == uint128(-4));
		assert( -(-op1) == uint128(4));
		assert(++op1 == uint128(5));
		assert(--op1 == uint128(4));
		op1 = uint128(0x000011111100UL);
		// TODO: test fails
//		assert(~op1 == 0xFFFFFFFFEEEEEEFFUL);
//		assert(-op1 == 0xFFFFFFFFEEEEEF00UL);
//		assert(negate(op1) == 0xFFFFFFFFEEEEEF00UL);

	}

//--------------------------------
// binary operations
//--------------------------------

	private const UXInt!Z opBinary(string op, T:UXInt!Z)(const T that)
	{
		static if (op == "+") {
			return add(this, that);
		} else static if (op == "-") {
			return sub(this, that);
		} else static if (op == "*") {
			return mul(this, that);
		} else static if (op == "/") {
			return div(this, that);
		} else static if (op == "%") {
			return mod(this, that);
		} else static if (op == "^^") {
			return pow(this, that);
		} else static if (op == "&") {
			return and(this, that);
		} else static if (op == "|") {
			return or(this, that);
		} else static if (op == "^") {
			return xor(this, that);
		} else static if (op == "<<") {
			return shl(this, that);
		} else static if (op == ">>") {
			return lshr(this, that);
		} else static if (op == ">>>") {
			return lshr(this, that);
		}
	}

	private const UXInt!Z opBinary(string op, T)(const T that) {
		return opBinary!(op, UXInt!Z)(UXInt!Z(that));
	}

	unittest {	// opBinary
		uint128 op1, op2;
		op1 = 4; op2 = 8;
		// test addition
		assert(op1 + op2 == 12);
		op1 = 4; int intOp = 8;
		assert(op1 + intOp == 12);
		// test subtraction
		assert(op2 - op1 == uint128(4));
		// test multiplication
		assert(op1 * op2 == 32);
		// test division
		op1 = 5; op2 = 2;
		assert(op1 / op2 == 2);
		assert(op1 % op2 == 1);
		// test power function
		assert(op1 ^^ op2 == 25);
		// test logical operations
		op1 = 10101; op2 = 10001;
		assert((op1 & op2) == 10001);
		assert((op1 | op2) == 10101);
		assert((op1 ^ op2) == 100);
		// test left and right shifts
		op2 = 2;
		assert(op1 << op2 == 40404);
		assert(op1 >> op2 == 2525);
		op1 = 4; op2 = uint128([0u,1u]);
		assert(op1 + op2 == 0x100000004);
		op1 = 0x0FFFFFFF;
		op2 = uint128.max;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = 35;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = 25;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = uint128.max;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1+op2 = %s", (op1+op2).toHexString);

	}

	/// Returns true if the result did not overflow,
	/// false if the result is too large for the size of the extended integer.)
	public static bool overflowOccurred(uint[] result) {
		int k = numDigits(result);
		return (k >= N);
	}

	/// Adds two unsigned extended integers and returns the sum.
	/// Tests the result for overflow.
	public const UXInt!Z add(const UXInt!Z x, const UXInt!Z y) {
		uint[] sum = addDigits(x.digits, y.digits);
		if (overflow == OverflowMode.IGNORE || !overflowOccurred(sum)) {
			return UXInt!Z(sum);
		}
		if (overflow == OverflowMode.CLAMP) {
			return UXInt!Z.max;
		}
		throw new IntegerException("Extended Integer Addition Overflow");
	}

	unittest {
		write("addition...");
		writeln("test missing");
	}

	/// Subtracts one unsigned extended integer from another and returns the difference.
	/// Performs a pre-test for overflow.
	public const UXInt!Z sub(const UXInt!Z x, const UXInt!Z y) {
		if (overflow != OverflowMode.IGNORE) {
			if (y > x) {
				if (OverflowMode.CLAMP) {
					return UXInt!Z.min;
				}
				else {
					throw new IntegerException("Extended Integer Subtraction Overflow");
				}
			}
		}
		uint[] diff = subDigits(x.digits, y.digits);
		return UXInt!Z(diff);
	}

	unittest {
		write("subtraction...");
		writeln("test missing");
	}
	/// Multiplies two unsigned extended integers and returns the product.
	/// Tests the result for overflow.
	public const UXInt!Z mul(const UXInt!Z x, const UXInt!Z y) {
		// special cases
		if (x == ZERO || y == ZERO) return ZERO;
		if (y == ONE) return x;
		if (x == ONE) return y;
		uint[] w = mulDigits(x.digits, y.digits);
		if (overflow == OverflowMode.IGNORE || !overflowOccurred(w)) {
			return UXInt!Z(w);
		}
		if (overflow == OverflowMode.CLAMP) {
			return UXInt!Z.max;
		}
		throw new IntegerException("Integer Multiplication Overflow");
	}

	unittest {
		write("mul...");
		int128 x = 2;
		int128 y = 6;
		assert(x*y == int128(12));
		x = -x;
		assert(x*y == int128(-12));
		y = -y;
		assert(x*y == int128(12));
		x = -x;
		assert(x*y == int128(-12));
		writeln("passed");
	}

	/// Divides one unsigned extended integer by another
	/// and returns the quotient.
	public const UXInt!Z div(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(divDigits(x.digits, y.digits));
	}

	unittest {
		write("div...");
		int128 x = 6;
		int128 y = 2;
		assert(x/y == int128(3));
		x = -x;
		assert(x/y == int128(-3));
		y = -y;
	//writefln("x = %s", x);
	//writefln("y = %s", y);
	//writefln("x/y = %s", (x/y).toHexString);
		assert(x/y == int128(3));
		x = -x;
		assert(x/y == int128(-3));
		writeln("passed");
	}

	/// Divides one unsigned extended integer by another
	/// and returns the remainder.
	public const UXInt!Z mod(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(modDigits(x.digits, y.digits));
	}

	unittest {
		write("mod...");
		int128 x = 7;
		int128 y = 2;
		assert(x % y == 1);
		x = -x;
		assert(x % y == -1);
		y = -y;
		assert(x % y == -1);
		x = -x;
		assert(x % y == 1);
		writeln("passed");
	}

	/// Raises an unsigned extended integer to an integer power
	/// and returns the result. Tests the result for overflow.
	public const UXInt!Z pow(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(pow(x, y.toUint));
	}

	/// Raises an unsigned extended integer to an integer power
	/// and returns the result. Tests the result for overflow.
	public const UXInt!Z pow(const UXInt!Z x, const uint n) {

		if (n < 0) throw new InvalidOperationException();

		if (n == 0) return ONE;

		uint[] result = powDigits(x.digits, n);
		if (overflow == OverflowMode.IGNORE || !overflowOccurred(result)) {
			return UXInt!Z(result);
		}
		if (overflow == OverflowMode.CLAMP) {
			return UXInt!Z.max;
		}
		throw new IntegerException("Integer Addition Overflow");
	}

	unittest {
		write("power...");
		writeln("test missing");
	}

	/// Returns the logical AND of two unsigned extended integers
	public const UXInt!Z and(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(andDigits(x.digits, y.digits));
	}

	/// Returns the logical OR of two unsigned extended integers
	public const UXInt!Z or(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(orDigits(x.digits, y.digits));
	}

	/// Returns the logical XOR of two unsigned extended integers
	public const UXInt!Z xor(const UXInt!Z x, const UXInt!Z y) {
		return UXInt!Z(xorDigits(x.digits, y.digits));
	}

	/// Shifts an unsigned extended integer left by an integral value.
	/// No check for overflow is made.
	public const UXInt!Z shl(const UXInt!Z x, const UXInt!Z y) {
		return shl(x, y.toUint);
	}

	/// Shifts an unsigned extended integer left by an integral value.
	/// No check for overflow is made.
	public const UXInt!Z shl(const UXInt!Z x, const uint n) {
		int digs = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		if (digs != 0) {
			array = shlDigits(array, digs);
		}
		array = shlBits(array, bits);
		return UXInt!Z(array);
	}

	/// Shifts an unsigned extended integer right by an integral value.
	public static UXInt!Z shr(const UXInt!Z x, const UXInt!Z y) {
		return shr(x, y.toInt);
	}

	/// Shifts an unsigned extended integer right by an integral value.
	public static UXInt!Z shr(const UXInt!Z x, const uint n) {
		int digits = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		array = shrDigits(array, digits);
		array = shrBits(array, bits);
		return UXInt!Z(array);
	}

	/// Shifts an unsigned extended integer right by an integral value.
	public const UXInt!Z lshr(const UXInt!Z x, const UXInt!Z y) {
		return lshr(x, y.toUint);
	}

	/// Shifts an unsigned extended integer right by an integral value.
	public const UXInt!Z lshr(const UXInt!Z x, const uint n) {
		int digs = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		if (digs !=0 ) {
			array = lshrDigits(array, digs);
		}
		array = lshrBits(array, bits);
		return UXInt!Z(array);
	}

	/// Returns the absolute value of the value of the extended integer.
	/// No effect on unsigned extended integers -- returns a copy.
	public static T abs(T:UXInt!Z)(const T arg) {
		return arg.dup;
	}

	public static T sqr(T:UXInt!Z)(const T x) {
		return T(sqrDigits(x.digits));
	}

/*	public static T max(T:UXInt!Z)(const T arg1, const T arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/

	unittest {
		writeln("===================");
		writeln("unsigned........end");
		writeln("===================");
	}

}	// end UXInt

//--------------------------------
// UXInt!Z operations
//--------------------------------

	/// Returns the absolute value of the value of the extended integer.
	/// No effect on unsigned extended integers -- returns a copy.
/*	public T abs(T:UXInt!Z)(const T arg) {
		static if (signed)
			return arg.isNegative ? negate(arg) : arg.dup;
		else
			return arg.dup;
	}*/

/*	public static UXInt!Z max(Z)( arg1, const UXInt!Z arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/
/*	public static UXInt!Z max(Z)( arg1, const UXInt!Z arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/


	public UXInt!Z divmod()(const UXInt!Z x, const UXInt!Z y, out UXInt!Z mod) {
		return divmodDigits(x.digits, y.digits, mod.digits);
	}

	public UXInt!Z wideMul(z)(const UXInt!Z x, const UXInt!Z y, out UXInt!Z mod) {
		return divmodDigits(x.digits, y.digits, mod.digits);
	}

unittest {	// divmod
	write("divmod...");
	int128 a = 5;
	int128 b = 7;
writefln("abs!int128(a) = %s", int128.abs(a));
writefln("sqr!uint128(uint128(5)) = %s", int128.sqr(b ));
//	writefln("max!128(a,b) = %s", max!128(a,b));

	writeln("test missing");
}

//============================================================================//

public struct XInt(int Z,
	OverflowMode overflow = OverflowMode.IGNORE) {

unittest {
	writeln("===================");
	writeln("signed........begin");
	writeln("===================");
}

//--------------------------------
// structure
//--------------------------------

	// The number of uint digits in the extended integer
	private enum uint N = Z/32;

	// digits are right to left:
	//	least significant digit is digits[0];
	//	most signiciant digit is digits[N-1]
	private uint[N] digits; // = 0;

	/// Returns zero, the initial value for XInt!(Z) types.
//	@property
	public static XInt!(Z) init() {
		return ZERO;
	}

	/// Returns the maximum value for this type.
	/// For unsigned extended integers the maximum value is 0xFF...FF.
	/// For signed extended integers the maximum value is 0x7F...FF.
	public static XInt!(Z) max() {
		static XInt!(Z) value;
		static bool initialized = false;
		if (initialized) return value;
		for (int i = 0; i < N; i++) {
			value.digits[i] = uint.max;
		}
		value.digits[N-1] = int.max;
		initialized = true;
		return value;
	}

	public static XInt!(Z) max(const XInt!(Z) arg1, const XInt!(Z) arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}

	/// Returns the minimum value for this type.
	/// For unsigned extended integers the minimum value is 0x00...00.
	/// For signed extended integers the minimum value is 0x80...00.
	public static XInt!(Z) min() {
		static XInt!(Z) value;
		static bool initialized = false;
		if (initialized) return value;
		value = XInt!(Z)(0);
		value.digits[N-1] = int.min;
		initialized = true;
		return value;
	}

unittest {
	int128 a = 5;
	int128 b = 7;
	assert(int128.max(a,b) == 7);
	assert(XInt!64.max == long.max);
	assert(UXInt!64.max == ulong.max);
	assert(XInt!64.min == long.min);
	assert(UXInt!64.min == ulong.min);
	assert(XInt!256.max.toString == "57896044618658097711785492504343953926634992332820282019728792003956564819967");
	assert(XInt!256.min.toString == "-57896044618658097711785492504343953926634992332820282019728792003956564819968");
	assert(UXInt!256.max.toString == "115792089237316195423570985008687907853269984665640564039457584007913129639935");
//writefln("max(int128(5), int128(7)) = %s", max!int128(int128(5), int128(7)));
/*writefln("XInt!(256,true).max.toHexString = %s", XInt!(256,true).max.toHexString);
writefln("XInt!(256,false).max.toHexString = %s", XInt!(256,false).max.toHexString);
writefln("XInt!(256,true).min.toHexString = %s", XInt!(256,true).min.toHexString);
writefln("XInt!(256,false).min.toHexString = %s", XInt!(256,false).min.toHexString);
writefln("XInt!(256,true).max = %s", XInt!(256,true).max);
writefln("XInt!(256,false).max = %s", XInt!(256,false).max);
writefln("XInt!(256,true).min = %s", XInt!(256,true).min);
writefln("XInt!(256,false).min = %s", XInt!(256,false).min);*/
}

//--------------------------------
// construction
//--------------------------------

	/// Constructs an extended integer from a list of (signed) long values. The list
	/// can be a single value, a comma-separated list or an array.
	/// The list is ordered right to left:
	/// most significant digit first, least significant digit last.
	public this(const long value) {
		digits[0] = low(value);
		digits[1] = high(value);
		if (digits[1] > 0x7FFFFFF) {
			for (int i = 2; i < N; i++) {
				digits[i] = 0xFFFFFFFF;
			}
		}
	}

	// needed for sign extension of int values
	public this(const int value) {
		this(cast(long)value);
	}

	/// Private constructor for internal use.
	/// Constructs an extended integer from a list of unsigned int (not long) values.
	/// The list must be an array. The list is ordered left to right:
	/// least significant value first, most significant value last.
	private this(const uint[] array) {
		uint len = cast(uint)(array.length >= N ? N : array.length);
		for (int i = 0; i < len; i++)
			digits[i] = array[i];
	}

	unittest {	// construction
		uint128 num = uint128(7503UL, 12UL);
		num = uint128(7503UL);
		assert(num.digits[0] == 7503);
		assert(num.digits[0] != 7502);
		num = uint128(2^^16);
		num = uint128(uint.max);
		num = uint128(cast(ulong)uint.max + 1);
		assert(num.digits[0] == 0);
		assert(num.digits[1] == 1);
		num.digits[0] = 16;
		num.digits[1] = 32;
	}

//--------------------------------
// copy
//--------------------------------

	/// Copy constructor.
	public this(const XInt!(Z) that) {
		this.digits = that.digits;
	}

	/// Returns a copy of the value of the extended integer.
	public const XInt!(Z) dup() {
		return XInt!(Z)(this);
	}

	unittest {	// copy
		uint128 num = uint128(9305);
		assert(uint128(num) == num);
		assert(num.dup == num);
//		assert(num.abs == uint128(9305));
//		assert(abs(num) == uint128(9305));
	}

//--------------------------------
// string constructor
//--------------------------------

//	public this(string str) {
//		//this.digits = that.digits;
//	}

//--------------------------------
// constants
//--------------------------------

	public enum XInt!Z ZERO = XInt!Z(0);
	public enum XInt!Z ONE  = XInt!Z(1);

//--------------------------------
// classification
//--------------------------------

	/// Returns true if the value of the extended integer is zero
	public const bool isZero() {
		return numDigits(this.digits) == 0;
	}

	/// Returns true if the value of the extended integer is less than zero
	public const bool isNegative() {
		return cast(int)digits[N-1] < 0;
	}

	/// Returns true if the value of the extended integer is odd.
	public const bool isOdd() {
		return digits[0] & 1;
	}

	/// Returns true if the value of the extended integer is even.
	public const bool isEven() {
		return !isOdd();
	}

//--------------------------------
// conversion
//--------------------------------

	/// Converts to a string.
	public const string toString() {
		char[] str;
		bool sign = this.isNegative;
		uint[] from = sign ? negate(this).digits : this.dup.digits;
		uint n = numDigits(from);
		if (n == 0) return "0";
		while (n > 0) {
			uint mod;
			char[1] ch;
			from = divmodDigit(from, n, 10, mod);
			std.string.sformat(ch, "%d", mod);
			str = ch ~ str;
			n = numDigits(from);
		}
		if (sign) str = "-" ~ str;
		return str.idup;
	}

	/// Converts to a hexadecimal string.
	public const string toHexString() {
		char[] str;
		int length = numDigits(digits);
		if (length == 0) {
			return ("0x00000000");
		}
		for (int i = 0; i < length; i++) {
			str = std.string.format("_%08X", digits[i]) ~ str;
		}
		return "0x" ~ str[1..$].idup;
	}

	unittest // toString
	{
		uint128 a;
		a = uint128([11UL]);
		assert("11" == a.toString);
		a = uint128(1234567890123);
		assert(a.toString == "1234567890123");
		a = uint128(0x4872EACF123346FF);
		assert(a.toString == "5220493093160306431");
		assert(uint128(156).toHexString == "0x0000009C");
		int128 b;
		b = int128(-11);
		assert(b.toString == "-11");
		assert("-11" == b.toString);
		b = int128(1234567890123);
		assert(b.toString == "1234567890123");
		assert(b.toHexString == "0x0000011F_71FB04CB");
		b = int128(0x4872EACF123346FF);
		assert(b.toString == "-13226250980549245185");
		assert(b.toHexString == "0xFFFFFFFF_FFFFFFFF_4872EACF_123346FF");
		assert(int128(156).toHexString == "0x0000009C");
		assert(int256(156).toHexString == "0x0000009C");
	}

	// reads left-to-right, i.e., getDigit(0) returns the highest order value
	public const uint getDigit(int n) {
		return cast(uint)digits[N-n];
	}

	// reads left-to-right, i.e., getWord(0) returns the highest order value
	public const ulong getWord(int index) {
		index *= 2;
		return pack(digits[N-1 - index], digits[N-2 - index]);
	}

	// reads left-to-right, i.e., setWord(0) sets the highest order value
	public void setWord(int index, ulong value) {
		index *= 2;
		digits[N-1 - index] = high(value);
		digits[N-2 - index] = low(value);
	}

unittest {	// get/set long values
	write("get/set long values...");
	writeln("test missing");
}

	/// Converts to an unsigned integer.
	public const uint toUint() {
		return cast(uint)digits[0];
	}

	/// Converts to an unsigned long integer.
	public const ulong toUlong() {
		return getWord(1);
	}

	/// Converts to an integer.
	public const int toInt() {
		return cast(int)digits[0];
	}

	/// Converts to a long integer.
	public const long toLong() {
		return digits[0];
	}

	unittest {	// conversion
		assert(uint128(8754).toUint == 8754);
		assert(uint128(9100).toUlong == 9100L);
	}

	/// Converts to a big integer.
	public const BigInt toBigInt() {
		BigInt big = BigInt(0);
		for (int i = 0; i < N; i++) {
			big = big * BASE + digits[N-1-i];
		}
		return big;
	}

	/// Construct from a big integer.
	public this(const BigInt big) {
//		if (big < 0) big = - big;
		BigInt arg = cast(BigInt) big;
		BigInt base = BigInt(BASE);
		int len = cast(int)arg.uintLength;
		if (len > N) len = N;
		for (int i = 0; i < len; i++) {
			digits[i] = cast(uint)(arg % base).toLong;
			arg /= base;
			if (arg == 0) break;
		}
	}

	unittest {	// BigInt interoperability
		BigInt big = 5;
		uint128 num = 21;
		assert(big != num);
		assert(num != big);
		assert(big < num);
		assert(num > big);
		assert(uint128(big) == 5);
		big = num.toBigInt;
		assert(big == 21);
		assert(big == num);
	}

//--------------------------------
// comparison
//--------------------------------

	/// Returns -1, 0, or 1, if this extended integer is, respectively,
	/// less than, equal to or greater than the argument.
	private const int opCmp(T:XInt!(Z))(const T that) {
		if (this.isNegative && !that.isNegative) return -1;
		if (that.isNegative && !this.isNegative) return  1;
		return compare(this.digits, that.digits);
	}

	/// Returns -1, 0, or 1, if this extended integer is, respectively,
	/// less than, equal to or greater than the argument.
	private const int opCmp(T)(const T that) if (isIntegral!T) {
		return opCmp(XInt!(Z)(that));
	}

	/// Returns -1, 0, or 1, if this extended integer is, respectively,
	/// less than, equal to or greater than the argument.
	private const int opCmp(T:BigInt)(const T that) {
		return compare(this.digits, XInt!(Z)(cast(BigInt)that).digits);
	}

	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T:XInt!(Z))(const T that) {
		return this.digits == that.digits;
	}

/*	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T,Z)(const T that) {
		return this.digits == XInt!Z(that).digits;
	}*/

	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T)(const T that) if (isIntegral!T) {
		return opEquals(XInt!(Z)(that));
	}

	 /// Returns true if this extended integer is equal to the argument.
	private const bool opEquals(T:BigInt)(const T that) {
		return this.digits == XInt!(Z)(cast(BigInt)that).digits;
	}

	unittest { // comparison
		assert(uint128(5) < uint128(6));
		assert(uint128(5) < 6);
		assert(uint128(3) < uint128(10));
		assert(uint128(195) >= uint128(195));
		assert(uint128(195) >= 195);

		assert(int128(5) < int128(6));
		assert(int128(5) < 6);
		assert(int128(3) < int128(10));
		assert(int128(195) >= int128(195));
		assert(int128(195) >= 195);

		assert(int128(-5) > int128(-6));
		assert(int128(-5) < int128(6));
		assert(int128(3) > int128(-10));
		assert(int128(10) > int128(-3));
		assert(int128(195) >= int128(195));
		assert(int128(195) >= -195);
	}

//	public static XInt!(Z) max(const XInt!(Z) arg1, const XInt!(Z) arg2) {
//		if (arg1 < arg2) return arg2;
//		return arg1;
//	}
//	public static XInt!(Z) max(const XInt!(Z) arg1, const XInt!(Z) arg2) {
//		if (arg1 < arg2) return arg2;
//		return arg1;
//	}

/*	public const T max(T)(const T arg1, const T arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}

	public static XInt!(Z) min(const XInt!(Z) arg1, const XInt!(Z) arg2) {
		if (arg1 > arg2) return arg2;
		return arg1;
	}*/

unittest {
/*	write("max, min...");
	int128 a = 5;
	int128 b = 7;
writefln("max(a,b) = %s", max(a,b));
writefln("min(a,b) = %s", min(a,b));
//	assert(max(int128(5), int128(7)) == 7);*/
	writeln("test missing");
}
//--------------------------------
// assignment
//--------------------------------

	private const uint opIndex(const uint i) {
		return digits[i];
	}

	private void opIndexAssign(T)
			(const T that, const uint i) if (isIntegral!T) {
		digits[i] = that;
	}

	/// Assigns a XInt!(Z) extended integer (copies that to this).
	private void opAssign(T:XInt!(Z))(const T that) {
		this.digits = that.digits;
	}

	/// Assigns a XInt!(Z) integral value
	private void opAssign(T)(const T that) if (isIntegral!T) {
		opAssign(XInt!(Z)(that));
	}

	private ref XInt!(Z) opOpAssign(string op, T:XInt!(Z)) (T that) {
		this = opBinary!op(that);
		return this;
	}

	/// Assigns an XInt!(Z) (copies that to this).
	private ref XInt!(Z) opOpAssign(T)
			(string op, const T that) if (isIntegral!T) {
		opOpAssign(XInt!(Z)(that));
	}

//--------------------------------
// unary operations
//--------------------------------

	private XInt!(Z) opUnary(string op)() {
		static if (op == "+") {
			return plus();
		} else static if (op == "-") {
			return negate(this);
		} else static if (op == "~") {
			return complement(this);
		}else static if (op == "++") {
			this = add(this, XInt!(Z)(1));
			return this;
		} else static if (op == "--") {
			this = sub(this, XInt!(Z)(1));
			return this;
		}
	}

	public const XInt!(Z) plus() {
		return XInt!(Z)(this.digits);
	}

	public static XInt!(Z) complement(const XInt!(Z) arg) {
		auto copy = arg.dup;
		for (uint i = 0; i < N; i++)
			copy.digits[i] = ~copy.digits[i];
		return copy;
	}

/*	public const XInt!(Z) complement()() {
		XInt!(Z) w;
		for (int i = 0; i < N; i++)
			w.digits[i] = ~digits[i];
		return w;
	}*/

	public static XInt!(Z) negate(const XInt!(Z) arg) {
		auto neg = complement(arg);
		neg++;
		// TODO: add opAssignEquals += long
		return neg;
	}

/*	public const XInt!(Z) negate()() {
		auto w = this.complement;
		return ++w;
	}*/

	unittest {	// opUnary
		uint128 op1 = 4;
		import std.stdio;
		assert(+op1 == op1);
//		assert( -op1 == uint128(-4));
//		assert( -(-op1) == uint128(4));
		assert(++op1 == uint128(5));
		assert(--op1 == uint128(4));
		op1 = uint128(0x000011111100UL);
//		assert(~op1 == 0xFFFFFFFFEEEEEEFFUL);
//		assert(op1.negate == 0xFFFFFFFFEEEEEF00UL);

	}

	unittest {	// opUnary
		int128 op1 = 4;
		import std.stdio;
		assert(+op1 == op1);
		assert(-op1 == int128(-4));
		assert(-(-op1) == int128(4));
		assert(++op1 == int128(5));
		op1 = int128(0x000011111100UL);
		assert(~op1 == 0xFFFFFFFFEEEEEEFFUL);
		assert(-op1 == 0xFFFFFFFFEEEEEF00UL);
	}

//--------------------------------
// binary operations
//--------------------------------

	private const XInt!(Z) opBinary(string op, T:XInt!(Z))(const T that)
	{
		static if (op == "+") {
			return add(this, that);
		} else static if (op == "-") {
			return add(this, negate(that));
		} else static if (op == "*") {
			return mul(this, that);
		} else static if (op == "/") {
			return div(this, that);
		} else static if (op == "%") {
			return mod(this, that);
		} else static if (op == "^^") {
			return pow(this, that);
		} else static if (op == "&") {
			return and(this, that);
		} else static if (op == "|") {
			return or(this, that);
		} else static if (op == "^") {
			return xor(this, that);
		} else static if (op == "<<") {
			return shl(this, that);
		} else static if (op == ">>") {
			return shr(this, that);
		} else static if (op == ">>>") {
			return lshr(this, that);
		}
	}

	private const XInt!(Z) opBinary(string op, T)(const T that) if (isIntegral!T) {
		return opBinary!(op, XInt!(Z))(XInt!(Z)(that));
	}

	private const XInt!(Z) opBinary(string op, T:BigInt)(const T that) {
		return opBinary!(op, XInt!(Z))(XInt!(Z)(cast(BigInt)that));
	}

	unittest {	// opBinary
		uint128 op1, op2;
		op1 = 4; op2 = 8;
		assert(op1 + op2 == 12);
		op1 = 4; int intOp = 8;
		assert(op1 + intOp == 12);
		assert(op2 - op1 == uint128(4));
		assert(op1 * op2 == 32);
		op1 = 5; op2 = 2;
		assert(op1 / op2 == 2);
		assert(op1 % op2 == 1);
		assert(op1 ^^ op2 == 25);
		op1 = 10101; op2 = 10001;
		assert((op1 & op2) == 10001);
		assert((op1 | op2) == 10101);
		assert((op1 ^ op2) == 100);
		op2 = 2;
		assert(op1 << op2 == 40404);
		assert(op1 >> op2 == 2525);
		op1 = 4; op2 = uint128([0u,1u]);
		assert(op1 + op2 == 0x100000004);
		op1 = 0x0FFFFFFF;
		op2 = uint128.max;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = 35;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = 25;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1-op2 = %s", (op1-op2).toHexString);
		op1 = uint128.max;
		op2 = 30;
writefln("op1 = %s", op1.toHexString);
writefln("op2 = %s", op2.toHexString);
writefln("op1+op2 = %s", (op1+op2).toHexString);

	}

	unittest {
		int128 a = 5;
		assert(a^^2 == 25);
		a = -5;
		assert(a^^2 == 25);
		assert(a^^3 == -125);
		a = -1234567890;
	//	assert(a^^2 == 1524157875019052100);
	writefln("a = %s", a.toHexString);
	writefln("a^^2 = %s", (a^^2).toHexString);
	writefln("a^^3 = %s", (a^^3).toHexString);

	}
		unittest {	// opBinary
		int128 op1, op2;
		op1 = 4; op2 = 8;
		assert(op1 + op2 == 12);
		op1 = 4; int iop = -8;
		assert(op1 + iop == -4);
		assert(op1 - iop == 12);
		assert(int128(iop) + op1 == -4);
		assert(op2 - op1 == 4);
		assert(op1 * op2 == 32);
		op1 = -4; op2 = -8;
		assert(op1 + op2 == -12);
		assert(op1 - op2 == 4);
		op1 = -4; op2 = 8;
		assert(op1 + op2 == 4);
		assert(op1 - op2 == -12);
		op1 = 5; op2 = 2;
//writefln("op1/op2 = %s", op1/op2);
//		assert(op1 / op2 == 2);
		assert(op1 % op2 == 1);
//		assert(op1 ^^ op2 == 25);
		op1 = 10101; op2 = 10001;
//writefln("op1 = %s", op1);
//writefln("op2 = %s", op2);
		assert((op1 & op2) == 10001);
		assert((op1 | op2) == 10101);
		assert((op1 ^ op2) == 100);
		op2 = 2;
writefln("op1 = %s", op1);
writefln("op2 = %s", op2);
writefln("op1 << op2 = %s", op1 << op2);
//		assert(op1 << op2 == 40404);
writefln("op1 >> op2 = %s", op1 >> op2);
		op1 = -16;
writefln("op1 = %s", op1);
writefln("op1 >> op2 = %s", op1 >> op2);
		op1 = 0xFFFFFFFF;
		op2 = 48;
writefln("op1 = %s", op1.toHexString);
writefln("op1 = %s", op1);
writefln("op1 >> op2 = %s", (op1 >> op2).toHexString);
writefln("op1 >> op2 = %s", (op1 >> op2));
//		assert(op1 >> op2 == 2525);
		op1 = 4; op2 = int128([0,1]);
//		assert(op1 + op2 == 0x100000004);
	}

	public static bool overflowOccurred(uint[] result) {
		int k = numDigits(result);
		return (k < N);
	}

	public const XInt!(Z) add(const XInt!(Z) x, const XInt!(Z) y) {
		uint[] sum = addDigits(x.digits, y.digits);
		if (overflow == OverflowMode.IGNORE || !overflowOccurred(sum)) {
			return XInt!(Z)(sum);
		}
		if (overflow == OverflowMode.CLAMP) {
			return XInt!(Z).max;
		}
		throw new IntegerException("Integer Addition Overflow");
	}

	public const XInt!(Z) sub(const XInt!(Z) x, const XInt!(Z) y) {
		if (overflow != OverflowMode.IGNORE) {
			if (y > x) {
				if (OverflowMode.CLAMP) {
					return XInt!(Z).min;
				}
				else {
					throw new IntegerException("Integer Subtraction Overflow");
				}
			}
		}
		uint[] diff = subDigits(x.digits, y.digits);
		return XInt!(Z)(diff);
	}

	public const XInt!(Z) mul(const XInt!(Z) x, const XInt!(Z) y) {
		// special cases
		if (x == ZERO || y == ZERO) return ZERO;
		if (y == ONE) return x;
		if (x == ONE) return y;
		if (x == negate(ONE)) return negate(y);
		if (y == negate(ONE)) return negate(x);
		XInt!(Z) xx = x.dup;
		XInt!(Z) yy = y.dup;
		bool sign = false;
		if (x.isNegative) {
			sign = !sign;
			// TODO: should be -x...
			xx = negate(x);
		}
		if (y.isNegative) {
			sign = !sign;
			yy = negate(y);
		}
		uint[] w = mulDigits(xx.digits, yy.digits);
		XInt!(Z) product = XInt!(Z)(w[0..N-1]);
		return sign ? -product : product;
	}

unittest {
	write("mul...");
	int128 x = 2;
	int128 y = 6;
	assert(x*y == int128(12));
	x = -x;
	assert(x*y == int128(-12));
	y = -y;
	assert(x*y == int128(12));
	x = -x;
	assert(x*y == int128(-12));
	writeln("passed");
}

	public const XInt!(Z) div(const XInt!(Z) x, const XInt!(Z) y) {
		bool sign = x.isNegative ^ y.isNegative;
		XInt!(Z) xx = x.isNegative ? negate(x) : x.dup;
		XInt!(Z) yy = y.isNegative ? negate(y) : y.dup;
		XInt!(Z) quotient = XInt!(Z)(divDigits(xx.digits, yy.digits));
		return sign ? negate(quotient) : quotient;
	}

unittest {
	write("div...");
	int128 x = 6;
	int128 y = 2;
	assert(x/y == int128(3));
	x = -x;
	assert(x/y == int128(-3));
	y = -y;
//writefln("x = %s", x);
//writefln("y = %s", y);
//writefln("x/y = %s", (x/y).toHexString);
	assert(x/y == int128(3));
	x = -x;
	assert(x/y == int128(-3));
	writeln("passed");
}

	public const XInt!(Z) mod(const XInt!(Z) x, const XInt!(Z) y) {
		XInt!(Z) xx = x.isNegative ? negate(x) : x.dup;
		XInt!(Z) yy = y.isNegative ? negate(y) : y.dup;
		XInt!(Z) remainder = XInt!(Z)(modDigits(xx.digits, yy.digits));
		return x.isNegative ? negate(remainder) : remainder;
	}

unittest {
	write("mod...");
	int128 x = 7;
	int128 y = 2;
	assert(x % y == 1);
	x = -x;
	assert(x % y == -1);
	y = -y;
	assert(x % y == -1);
	x = -x;
	assert(x % y == 1);
	writeln("passed");
}

	public const XInt!(Z) pow(const XInt!(Z) x, const XInt!(Z) y) {
		return XInt!(Z)(pow(x, y.toUint));
	}

	public const XInt!(Z) pow(const XInt!(Z) x, const uint n) {

		if (n < 0) throw new InvalidOperationException();

		if (n == 0) return ONE;

		bool sign = x.isNegative;
		XInt!(Z) xx = sign ? negate(x) : x.dup;
		uint[] result = powDigits(xx.digits, n);
		// TODO: insert overflow check here.
		// odd powers of negative numbers are negative
		return sign && (n & 1) ? -XInt!(Z)(result) : XInt!(Z)(result);
	}

	public const XInt!(Z) and(const XInt!(Z) x, const XInt!(Z) y) {
		XInt!(Z) result;
		for (int i = 0; i < N; i++)
			result[i] = (x[i] & y[i]);
		return result;
	}

	public const XInt!(Z) or(const XInt!(Z) x, const XInt!(Z) y) {
		XInt!(Z) result;
		for (int i = 0; i < N; i++)
			result[i] = (x[i] | y[i]);
		return result;
	}

	public const XInt!(Z) xor(const XInt!(Z) x, const XInt!(Z) y) {
		XInt!(Z) result;
		for (int i = 0; i < N; i++)
			result[i] = (x[i] ^ y[i]);
		return result;
	}

	public const XInt!(Z) shl(const XInt!(Z) x, const XInt!(Z) y) {
		return shl(x, y.toUint);
	}

	public const XInt!(Z) shl(const XInt!(Z) x, const uint n) {
		int digs = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		if (digs != 0) {
			array = shlDigits(array, digs);
		}
		array = shlBits(array, bits);
		return XInt!(Z)(array);
	}

	public static XInt!(Z) shr(const XInt!(Z) x, const XInt!(Z) y) {
		return shr(x, y.toInt);
	}

	public static XInt!(Z) shr(const XInt!(Z) x, const uint n) {
		int digits = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		array = shrDigits(array, digits);
		array = shrBits(array, bits);
		return XInt!(Z)(array);
	}

	public const XInt!(Z) lshr(const XInt!(Z) x, const XInt!(Z) y) {
		return lshr(x, y.toUint);
	}

	public const XInt!(Z) lshr(const XInt!(Z) x, const uint n) {
		int digs = n / 32;
		int bits = n % 32;
		uint [] array = x.digits.dup;
		if (digs !=0 ) {
			array = lshrDigits(array, digs);
		}
		array = lshrBits(array, bits);
		return XInt!(Z)(array);
	}

	public void setBit(int n, bool value = true) {
		const XInt!(Z) ONE = XInt!(Z)(1);
		if (value) {
			this |= shl(ONE, n);
		}
		else {
			this &= complement(shl(ONE, n));
		}
	}

	public const bool testBit(int n) {
		const XInt!(Z) ONE = XInt!(Z)(1);
		XInt!(Z) value = this & shl(ONE,n);
//	 throw(new Exception("Why is this three times??"));
		return !value.isZero;
	}

	unittest {	// bit manipulation
		uint128 test = uint128(0);
		assert(!test.testBit(5));
		test.setBit(5);
		assert(test.testBit(5));
	}

	public const setBits(int n, int count, uint value) {
	};

	public const bool testBits(int n, int count, uint value) {
		return false;
	}

	unittest {
		writeln("===================");
		writeln("signed..........end");
		writeln("===================");
	}

	/// Returns the absolute value of the value of the extended integer.
	/// No effect on unsigned extended integers -- returns a copy.
	public static T abs(T:XInt!(Z))(const T arg) {
		return arg.isNegative ? negate(arg) : arg.dup;
	}

	public static T sqr(T:XInt!(Z))(const T x) {
		return T(sqrDigits(x.digits));
	}

/*	public static T max(T:XInt!(Z))(const T arg1, const T arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/

}	// end XInt

//--------------------------------
// XInt!(Z) operations
//--------------------------------

	/// Returns the absolute value of the value of the extended integer.
	/// No effect on unsigned extended integers -- returns a copy.
/*	public T abs(T:XInt!(Z))(const T arg) {
		static if (signed)
			return arg.isNegative ? negate(arg) : arg.dup;
		else
			return arg.dup;
	}*/

/*	public static XInt!(Z) max(Z)( arg1, const XInt!(Z) arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/
/*	public static XInt!(Z) max(Z)( arg1, const XInt!(Z) arg2) {
		if (arg1 < arg2) return arg2;
		return arg1;
	}*/


	public XInt!(Z) divmod()(const XInt!(Z) x, const XInt!(Z) y, out XInt!(Z) mod) {
		return divmodDigits(x.digits, y.digits, mod.digits);
	}

	public XInt!(Z) wideMul(z)(const XInt!(Z) x, const XInt!(Z) y, out XInt!(Z) mod) {
		return divmodDigits(x.digits, y.digits, mod.digits);
	}

unittest {	// divmod
	write("divmod...");
	int128 a = 5;
	int128 b = 7;
writefln("abs!int128(a) = %s", int128.abs(a));
writefln("sqr!uint128(uint128(5)) = %s", int128.sqr(b ));
//	writefln("max!128(a,b) = %s", max!128(a,b));

	writeln("test missing");
}

//============================================================================//

unittest {
	writeln("===================");
	writeln("arrayops......begin");
	writeln("===================");
}

//--------------------------------
// digit pack/unpack methods
//--------------------------------

private uint low(const ulong nn)
	{ return nn & 0xFFFFFFFFUL; }

private uint high(const ulong nn)
	{ return (nn & 0xFFFFFFFF00000000UL) >> 32; }

private ulong pack(uint hi, uint lo) {
	ulong packed = (cast(ulong) hi) << 32;
	packed |= lo;
	return packed;
}

//================================
// array operations
//================================

	/// Returns the number of digits in the array.
	/// Trailing zero digits are not counted.
	/// If all digits are zero, returns length = 0.
	private int numDigits(const uint[] digits) {
		int count;
		for (count = cast(int)digits.length; count > 0; count--) {
			if (digits[count-1]) break;
		}
		return count;
	}

	unittest {
		uint[] array;
		array = [ 1, 2, 3, 5 ];
		assert(numDigits(array) == 4);
		array = [ 1, 2, 3, 0 ];
		assert(numDigits(array) == 3);
		array = [ 1, 0, 0, 0, 0 ];
		assert(numDigits(array) == 1);
		array = [ 0, 0, 0, 0, 0 ];
		assert(numDigits(array) == 0);
	}

	// shifts by whole digits (not bits)
	private uint[] shlDigits(const uint[] array, int n) {
		uint[] shifted = array.dup;
		if (n > 0) {
			shifted = new uint[n] ~ shifted;
		}
		return shifted;
	}

	// shifts by bits
	private uint[] shlBits(const uint[] x, int n) {
		uint nx = numDigits(x);
		uint[] shifted = new uint[nx + 1];
		uint shout, shin;
		for (uint i = 0; i < nx; i++) {
			ulong temp = x[i];
			temp <<= n;
			shout = high(temp);
			shifted[i] = low(temp) | shin;
			shin = shout;
		}
		shifted[nx] = shin;
		return shifted;
	}

	// shifts by bits
	private uint[] shrBits(const uint[] x, int n) {
		uint nx = numDigits(x);
		uint[] shifted = new uint[nx];
		uint shout, shin;
		for (uint i = 0; i < nx; i++) {
			long temp = cast(int)x[i];
			temp >>= n;
			shout = high(temp);
			shifted[i] = low(temp) | shin;
			shin = shout;
		}
		return shifted;
	}

	// shifts by whole digits (not bits)
	private uint[] shrDigits(const uint[] x, int n) {
		if (n >= x.length || n < 0) {
			throw new InvalidOperationException();
		}
		if (n > 0) {
			bool sign = cast(int)x[$-1] < 0;
			if (sign) {
				auto y = x[n..$].dup;
				for (int i = n; i < x.length; i++)
					y ~= 0xFFFFFFFF;
				return y;
			}
			return x[n..$].dup;
		}
		return x.dup;
	}

	// shifts by bits
	private uint[] lshrBits(const uint[] x, int n) {
		uint nx = numDigits(x);
		uint[] shifted = new uint[nx];
		uint shout, shin;
		for (uint i = 0; i < nx; i++) {
			ulong temp = x[i];
			temp >>= n;
			shout = high(temp);
			shifted[i] = low(temp) | shin;
			shin = shout;
		}
		return shifted;
	}

	// shifts by whole digits (not bits)
	private uint[] lshrDigits(const uint[] x, int n) {
		if (n >= x.length) {
			return [0];
		}
		if (n > 0) {
			return x[n..$].dup;
		}
		return x.dup;
	}

	unittest {
		uint[] array, shifted;
		array = [ 1, 2, 3, 5 ];
		shifted = shlDigits(array, 1);
		assert(shifted == [0, 1, 2, 3, 5]);
		assert(compare(array, shifted) < 0);
		shifted = shrDigits(shifted, 1);
		assert(compare(array, shifted) == 0);
		shifted = shlBits(array, 1);
		assert(shifted == [2, 4, 6, 10, 0]);
		shifted = shrBits(shifted, 1);
		assert(shifted == array);
		array = [ 1, 2, 3, 0 ];
		shifted = shrDigits(array, 1);
		assert(shifted == [2, 3, 0]);
		assert(compare(array, shifted) > 0);
		array = random(4);
		shifted = shlBits(array, 4);
		assert(compare(shifted, mulDigit(array, 16)) == 0);
	}

	private bool isZero(const uint[] a) {
		return numDigits(a) == 0;
	}

	private bool isOdd(const uint[] a) {
		return a[0] & 1;
	}

	private bool isEven(const uint[] a) {
		return !isOdd(a);
	}

unittest {
	uint[] a = [7];
	assert(isOdd(a));
	a = [7, 3, 0];
	assert(isOdd(a));
	a = [0, 0, 0];
	assert(isEven(a));
	a = [0, 0, 15];
	assert(isEven(a));
	a = [64, 0, 15];
	assert(isEven(a));
	a = [64, 0, 0];
	assert(isEven(a));
	a = [63, 0, 0];
	assert(isOdd(a));
}


//--------------------------------
// comparison
//--------------------------------

	/// Compares two arrays of digits.
	/// Returns -1, 0, or 1 if the first argument is, respectively,
	/// smaller than, equal to or larger than the second.
	private int compare(const uint[] a, const uint[] b) {
		return compare(a, numDigits(a), b, numDigits(b));
	}

	/// Compares two arrays of digits.
	/// Returns -1, 0, or 1 if the first argument is, respectively,
	/// smaller than, equal to or larger than the second.
	private int compare(const uint[] a, uint na, const uint[] b, uint nb) {

		// if lengths differ just compare lengths
		if (na < nb) return -1;
		if (na > nb) return +1;

		// same length; return the first difference
		for (int i = nb-1; i >= 0; i--) {
			if (a[i] < b[i]) return -1;
			if (a[i] > b[i]) return +1;
		}
		// no differences; return 0
		return 0;
	}

	/// Compares an array of digits to a single digit.
	/// Returns -1, 0, or 1 if the second argument is, respectively,
	/// smaller than, equal to or larger than the first.
	private int compare(const uint[] a, const uint k) {
		if (numDigits(a) > 1) return +1;
		if (a[0] < k) return -1;
		if (a[0] > k) return +1;
		return 0;
	}

	unittest {
		uint[] a, b;
		int c;
		a = [5];
		b = [6];
		assert(compare(a, b) < 0);
		a = [4, 3, 2, 0 ];
		b = [4, 3, 2];
		assert(compare(a, b) == 0);
		b = [4, 3, 2, 1];
		assert(compare(a, b) < 0);
		a = [5, 3, 2, 1 ];
		assert(compare(a, b) > 0);
	}

//--------------------------------
// addition and subtraction
//--------------------------------

	/// Returns the sum of the two arrays.
	private uint[] addDigits(const uint[] x, const uint[] y) {
		uint nx = numDigits(x);
		if (nx == 0) return y.dup;
		uint ny = numDigits(y);
		if (ny == 0) return x.dup;
		if (nx >= ny) return addDigits(x, nx, y, ny);
		else return addDigits(y, ny, x, nx);
	}

	/// Returns the sum of the two arrays with lengths specified.
	/// Precondition: nx >= ny
	private uint[] addDigits(
			const uint[] x, const uint nx, const uint[] y, const uint ny) {

		assert(nx >= ny);
		uint[] sum = new uint[nx + 1];
		uint carry = 0;
		ulong temp = 0;
		uint i = 0;
		while (i < ny) {
			temp = cast(ulong)x[i] + cast(ulong)y[i] + carry;
			sum[i] = low(temp);
			carry = high(temp);
			i++;
		}
		while (carry && i < nx) {
			temp = cast(ulong)x[i] + carry;
			sum[i] = low(temp);
			carry = high(temp);
			i++;
		}
		while (i < nx) {
			sum[i] = x[i];
			i++;
		}
		// TODO: overflow if size of extended integer exceeded, i.e. nx == N
		if (carry == 1) {
			sum[i] = carry;
		}
		return sum;
	}

	/// Returns the sum of the array and a single digit.
	private static uint[] addDigit(const uint[] x, const uint y) {
		return addDigit(x, numDigits(x), y);
	}

	/// Returns the sum of the array and a single digit.
	private static uint[] addDigit(const uint[] x, uint nx, const uint y) {
		uint[] sum = new uint[nx + 1];
		ulong temp = x[0] + y;
		sum[0] = low(temp);
		uint carry = high(temp);
		uint i = 1;
		while (carry && i < nx) {
			temp = cast(ulong)x[i] + carry;
			sum[i] = low(temp);
			carry = high(temp);
			i++;
		}
		while (i < nx) {
			sum[i] = x[i];
			i++;
		}
		if (carry == 1) {
			sum[i] = carry;
		}
		return sum;
	}

	// Subtracts one array from another.
	// Precondition: x >= y.
	private uint[] subDigits(const uint[] x, const uint[] y) {
		uint nx = numDigits(x);
		uint ny = numDigits(y);
		if (nx >= ny) return subDigits(x, nx, y, ny);
		else return subDigits(y, ny, x, nx);
// NOTE: we don't really want to do this. just a test.
//		return subDigits(x, nx, y, ny);
	}

	// Subtracts one array from another.
	// precondition: x >= y.
	private uint[] subDigits(
		const uint[] x, const uint nx, const uint[] y, const uint ny) {

		if (ny > nx) {
			writefln("should overflow");
		}
		uint[] diff = new uint[nx + 1];
		uint borrow = 0;
		uint base = 0;
		uint i = 0;
		while (i < ny) {
			if (x[i] >= y[i] + borrow) {
				diff[i] = x[i] - y[i] - borrow;
				borrow = 0;
			}
			else {
				diff[i] = (base - y[i]) + x[i] - borrow;
				borrow = 1;
			}
			i++;
		}
		while (borrow && i < nx) {
			if (x[i] >= borrow) {
				diff[i] = x[i] - borrow;
				borrow = 0;
			}
			else {
				diff[i] = (base - borrow) + x[i];
				borrow = 1;
			}
			i++;
		}
		while (i < nx) {
			diff[i] = x[i];
			i++;
		}
		if (borrow == 1) {
writefln("overflow occurred");
writefln("i = %s", i);
writefln("nx = %s", nx);
			diff[i] = borrow;
		}
		return diff;
	}

//--------------------------------
// multiplication, squaring, exponentiation
//--------------------------------

	// Returns the product of the two arrays.
	private uint[] mulDigits(const uint[] x, const uint[] y) {
		uint nx = numDigits(x);
		uint ny = numDigits(y);
		return mulDigits(x, nx, y, ny);
	}

	// Returns the product of the two arrays.
	private uint[] mulDigits(const uint[] x, uint nx, const uint[] y, uint ny) {
		uint[] p = new uint[nx + ny + 1];
		p[] = 0;
		for (uint i = 0; i < ny; i++) {
			ulong carry = 0;
			for (uint j = 0; j < nx; j++) {
				ulong temp = carry + p[i+j]
					+ cast(ulong)(x[j]) * cast(ulong)(y[i]);
				carry = high(temp);
				p[i+j] = low(temp);
			}
			p[i+nx] = low(carry);
		// if (nx >= N && carry > 1) { overflow }
		}
		return p;
	}

	/// Multiplies an array of digits by a single digit
	private uint[] mulDigit(const uint[] x, const uint k) {
		int nx = numDigits(x);
		return mulDigit(x, nx, k);
	}

	/// Multiplies an array of digits by a single digit
	private uint[] mulDigit(const uint[] x, uint nx, const uint k) {
		uint[] p = new uint[nx+1];
		ulong carry = 0;
		for (int i = 0; i < nx; i++) {
			ulong temp = cast(long)k * x[i] + carry;
			p[i] = low(temp);
			carry = high(temp);
		}
		p[nx] = low(carry);
		assert(high(carry) == 0);// if carry != 0 then overflow
		return p;
	}

	private ulong longMul(const uint x, const uint y) {
		return cast(ulong)x * cast(ulong)y;
	}

	// Returns the number of significant digits in the input array.
	/// Copies the significant digits in the input array to the output array.
	private uint copyDigits(const uint[] x, out uint[] y) {
		uint nx = numDigits(x);
		y = x[0..nx].dup;
		return nx;
	}

	// Returns the square of the argument.
	public uint[] sqrDigits(const uint[] x) {
		uint nx = numDigits(x);
		uint[] sqrx = new uint[2*nx];
		ulong overflow = 0;
		for (uint i = 0; i < nx; i++) {
			ulong inner = sqrx[2*i]	+ longMul(x[i], x[i]) + overflow;
			ulong carry = high(inner);
			sqrx[2*i] = low(inner);
			for (uint j = i+1; j < nx; j++) {
				ulong temp = longMul(x[j], x[i]);
				overflow = temp & 0x8000_0000_0000_0000 ? 0x010000_0000 : 0;
				inner = carry + sqrx[i+j] + (temp << 1);
				carry = high(inner);
				sqrx[i+j] = low(inner);
			}
			sqrx[i+nx] = low(carry);
		assert(high(carry) == 0);// if (carry >1) { overflow }
		}
		return sqrx;
	}

	unittest {
		uint[] d = [0xF4DEF769, 0x941F2754];
		d = sqrDigits(d);
		string expect = "0x55B40944_C7C01ADE_DF5C24BA_3137C911";
		writefln("actual = %s", (UXInt!128(d).toHexString()));
		assert(UXInt!128(d).toHexString() == expect);
	}

	// returns the argument raised to the specified power.
	public uint[] powDigits(const uint[] base, uint expo) {
		if (expo == 0) return [1];
		if (expo == 1) return base.dup;
		if (expo == 2) return sqrDigits(base);
		uint[] a = [1];
		uint[] s = base.dup;
		while (expo > 0) {
			if (expo & 1) a = mulDigits(a, s);
			expo /= 2;
			if (expo > 0) s = sqrDigits(s);
		}
		return a;
	}

	// greatest common denominator
	public uint[] gcdDigits(const uint[] xin, const uint[] yin) {
		uint[] x, y;
		uint nx = copyDigits(xin, x);
		uint ny = copyDigits(yin, y);
		if (nx == 0 && ny == 0) return [1];
		if (nx == 0) return y;
		if (ny == 0) return x;
		if (compare(x, nx, y, ny) == 0) return x;
		uint[] g = [1];

		while (isEven(x) && isEven(y)) {
			x = shrBits(x, 1);
			y = shrBits(y, 1);
			g = shlBits(g, 1);
		}
		while (!isZero(x)) {
			while (isEven(x)) {
				x = shrBits(x, 1);
			}
			while (isEven(y)) {
				y = shrBits(y, 1);
			}
			if (compare(x,y) >= 0) {
				uint [] t = subDigits(x,y);
				x = shrBits(t, 1);
			}
			else {
				uint[] t = subDigits(y,x);
				y = shrBits(t, 1);
			}
		}
		return mulDigits(g, y);
	}

	// greatest common denominator
	public uint[] xgcdDigits(const uint[] xin, const uint[] yin) {
		uint[] x, y;
		uint nx = copyDigits(xin, x);
		uint ny = copyDigits(yin, y);
		if (nx == 0 && ny == 0) return [1];
		if (nx == 0) return y;
		if (ny == 0) return x;
		if (compare(x, nx, y, ny) == 0) return x;
		uint[] g = [1];
		uint[] u, v, A, B, C, D;
		while (isEven(x) && isEven(y)) {
			x = shrBits(x, 1);
			y = shrBits(y, 1);
			g = shlBits(g, 1);
		}
		u = x;
		v = y;
		A = [1];
		B = [0];
		C = [0];
		D = [1];
		while (!isZero(x)) {
			while (isEven(u)) {
				u = shrBits(u, 1);
				if (A == B && isEven(A)) {
					A = shrBits(A,1);
					B = shrBits(B,1);
				}
				else {
					A = shrBits(addDigits(A, y),1);
					// NOTE: Won't this throw?
					B = shrBits(subDigits(B, x),1);
				}
			}
			while (isEven(v)) {
				v = shrBits(v, 1);
				if (C == D && isEven(C)) {
					C = shrBits(C,1);
					D = shrBits(D,1);
				}
				else {
					C = shrBits(addDigits(C, y),1);
					// NOTE: Won't this throw?
					D = shrBits(subDigits(D, x),1);
				}
			}
			if (compare(u,v) >= 0) {
				u = subDigits(u,v);
				A = subDigits(A,C);
				B = subDigits(B,D);
			}
			else {
				v = subDigits(v,u);
				C = subDigits(C,A);
				D = subDigits(D,B);
			}
		}

		return mulDigits(g, v);
	}

	unittest {
		uint[] b = [0xC2BA7913U]; //random(1);
		uint e = 4;
		uint[] p = powDigits(b, e);
		uint[] t = [1];
		for (int i = 0; i < e; i++) {
			t = mulDigits(t, b);
		}
		assert(compare(p,t) == 0);

		uint[] x, y, g;
		x = [174]; //random(1);;
		y = [36]; //random(1);
		g = gcdDigits(x,y);
		assert(compare(g, [6]) == 0);
//		g = xgcdDigits(x,y);
//writefln("g = %s", g);

	}

	unittest {
		for (int j = 0; j < 10; j++) {
			uint[] b = random(1);
			uint e = 7;
			uint[] p = powDigits(b, e);
			uint[] t = [1];
			for (int i = 0; i < e; i++) {
				t = mulDigits(t, b);
			}
		assert(compare(p,t) == 0);
		}
	}

//--------------------------------
// division and modulus
//--------------------------------

	/// Returns the quotient of the first array divided by the second.
	private uint[] divmodDigits(const uint[] xin, const uint[] yin, out uint[] mod) {
		// mutable copies
		uint[] x, y;
		uint nx = copyDigits(xin, x);
		uint ny = copyDigits(yin, y);
		if (ny == 0) throw new Exception("division by zero");
		// special cases
		if (nx == 0)  {
			mod = [0];
			return [0];
		}
		if (ny == 1) {
			return divmodDigit(x, nx, y[0], mod[0]);
		}
		return divmodDigits(x, numDigits(x), y, numDigits(y), mod);
	}

	/// Returns the quotient of the first array divided by the second.
	/// Preconditions: y != 0
	private uint[] divmodDigits(
			ref uint[] x, uint nx, ref uint[] y, uint ny, out uint[] mod) {

		// normalize the operands
		uint f = divDigit([0u, 1u], y[ny-1])[0];
		if (f != 1) {
			x = mulDigit(x, nx, f);
			nx = numDigits(x);
			y = mulDigit(y, ny, f);
			ny = numDigits(y);
		}

		uint[] q = new uint[nx-ny+1];
		uint[] ys = shlDigits(y, nx-ny);
		while (compare(x,ys) > 0) {
			q[nx-ny]++;
			x = subDigits(x, ys);
		}
		for (uint i = nx-1; i >= ny; i--) {
			uint ix = i-ny;
			if (x[i] == y[ny-1]) {
				q[ix] = uint.max;
			}
			else {
				q[ix] = divDigit(x[i-1..i+1], 2U, y[ny-1])[0];
			}
			uint[] yq = mulDigit(y[ny-2..ny], 2U, q[ix]);
			while ((compare(yq, x[i-2..i+1])) > 0) {
				q[ix]--;
				yq = subDigits(yq, y[ny-2..ny]);
			}
			uint[] yb = shlDigits(y, i-ny);
			uint[] xs = mulDigit(yb, i, q[ix]);
			if (compare(x, xs) < 0) {
				q[ix]--;
				xs = subDigits(xs, yb);
			}
			x = subDigits(x, xs);
		}
		mod = f == 1 ? x : divDigit(x, f);
		return q;
	}

	/// Divides an array of digits by a single digit
	private uint[] divmodDigit(const uint[] x, uint n, uint k, out uint mod) {
		if (n == 0) {
			mod = 0;
			return [0];
		}
		if (k == 1) {
			mod = 0;
			return x.dup;
		}
		if (k == 0) throw new Exception("division by zero");
		uint[] q = x.dup;
		ulong carry = 0;
		for (int i = n-1; i >= 0; i--) {
			ulong temp = carry * BASE + x[i];
			q[i] = low(temp / k);
			carry = temp % k;
		}
		mod = cast(uint)carry;
		return q;
	}

	/// Returns the quotient of the first array divided by the second.
	private uint[] divDigits(const uint[] xin, const uint[] yin) {
		// mutable copies
		uint[] x, y, mod;
		uint nx = copyDigits(xin, x);
		uint ny = copyDigits(yin, y);
		// special cases
		if (nx == 0) return [0];
		if (ny == 0) throw new Exception("division by zero");
		if (ny == 1) return divDigit(x, nx, y[0]);
		// divide arrays
		return divmodDigits(x, nx, y, ny, mod);
	}

	/// Returns the quotient of the first array divided by the second.
	private uint[] divDigits(ref uint[] x, uint nx, ref uint[] y, uint ny) {
		uint [] mod;
		return divmodDigits(x, nx, y, ny, mod);
	}

	/// Divides an array of digits by a single digit
	private uint[] divDigit(const uint[] x, uint k) {
		return divDigit(x, numDigits(x), k);
	}

	/// Divides an array of digits by a single digit
	private uint[] divDigit(const uint[] x, uint n, uint k) {
		if (n == 0) return [0];
		if (k == 1) return x.dup;
		if (k == 0) throw new Exception("division by zero");
		uint[] q = x.dup;
		ulong carry = 0;
		for (int i = n-1; i >= 0; i--) {
			ulong temp = carry * BASE + x[i];
			q[i] = low(temp / k);
			carry = temp % k;
		}
		return q;
	}

	/// Returns the quotient of the first array divided by the second.
	private uint[] modDigits(const uint[] xin, const uint[] yin) {
		// mutable copies
		uint[] x, y, mod;
		uint nx = copyDigits(xin, x);
		uint ny = copyDigits(yin, y);
		// special cases
		if (nx == 0) return [0];
		if (ny == 0) throw new Exception("division by zero");
		if (ny == 1) return [modDigit(x, nx, y[0])];
		// divide arrays
		divmodDigits(x, nx, y, ny, mod);
		return mod;
	}

	/// Returns the quotient of the first array divided by the second.
	private uint[] modDigits(ref uint[] x, uint nx, ref uint[] y, uint ny) {
		uint [] mod;
		divmodDigits(x, nx, y, ny, mod);
		return mod;
	}

	/// Divides an array of digits by a single digit and returns the remainder.
	private uint modDigit(const uint[] x, uint k) {
		return modDigit(x, numDigits(x), k);
	}

	/// Divides an array of digits by a single digit and returns the remainder.
	private uint modDigit(const uint[] x, uint n, const uint k) {
		ulong carry = 0;
		for (int i = n-1; i >= 0; i--) {
			ulong temp = carry * BASE + x[i];
			carry = temp % k;
		}
		return cast(uint)carry;
	}

unittest {
	uint[] input, output;
	uint k;
	input = [28, 20, 48, 76];
	output = divDigit(input, 2);
//writefln("output = %s", output);
//writefln("UXInt!Z(output) = %s", UXInt!Z(output));
	input = random(4);
//writefln("input = %s", input);
//writefln("UXInt!Z(input) = %s", UXInt!Z(input));
	k = randomDigit;
//writefln("k = %X", k);
	output = divDigit(input, k);
//writefln("UXInt!Z(output) = %s", UXInt!Z(output));
//writefln("output = %s", output);
	uint[] ka = [ k ];
	uint[] m = mulDigits(output, ka);
	uint r = modDigit(input, k);
//writefln("r = %X", r);
//writefln("UXInt!Z(m) = %s", UXInt!Z(m));
//writefln("UXInt!Z( ) = %s", UXInt!Z(addDigit(m, r)));
}

//--------------------------------
// logical operations
//--------------------------------

	/// Returns the logical and of the two arrays.
	/// precondition: a and b must have the same length
	private uint[] andDigits(const uint[] a, const uint[] b) {
		assert(a.length == b.length);
		uint[] and = new uint[a.length];
		for (int i = 0; i < a.length; i++) {
			and[i] = a[i] & b[i];
		}
		return and[];
	}

	/// Returns the logical or of the two arrays.
	/// precondition: a and b must have the same length
	private uint[] orDigits(const uint[] a, const uint[] b) {
		assert(a.length == b.length);
		uint[] or = new uint[a.length];
		for (int i = 0; i < a.length; i++) {
			or[i] = a[i] | b[i];
		}
		return or[];
	}

	/// Returns the logical xor of the two arrays.
	/// precondition: a and b must have the same length
	private uint[] xorDigits(const uint[] a, const uint[] b) {
		assert(a.length == b.length);
		uint[] xor = new uint[a.length];
		for (int i = 0; i < a.length; i++) {
			xor[i] = a[i] ^ b[i];
		}
		return xor[];
	}


//--------------------------------
// random numbers
//--------------------------------

	private uint[] random(uint n) {
		uint[] rand = new uint[n];
		for (int i = 0; i <n; i++) {
			rand[i] = randomDigit;
		}
		return rand;
	}

	private uint randomDigit() {
		return std.random.uniform(0, uint.max);
	}

unittest {
	writeln("random digits...");
	uint[] r = random(4);
/*writefln*/("UXInt!Z(r) = %s", UXInt!128(r));
	uint[] s = random(4);
//writefln("UXInt!Z(s) = %s", UXInt!Z(s));
//writefln("compare(r,s) = %s", compare(r,s));
	uint[] t;
	if (compare(r,s) > 0) {
		t = subDigits(r,s);
//writefln("t == r - s = %s", UXInt!Z(t));
//writefln("r ?= t - s = %s", UXInt!Z(addDigits(t,s)));
	}
	else {
		t = addDigits(r,s);
//writefln("t == r + s = %s", UXInt!Z(t));
//writefln("s ?= t - r = %s", UXInt!Z(subDigits(t,r)));
	}
	uint[] x = random(2);
	uint[] y = random(2);
	uint[] z = mulDigits(x,y);
//writefln("UXInt!Z(x) = %s", UXInt!Z(x));
//writefln("UXInt!Z(y) = %s", UXInt!Z(y));
//writefln("UXInt!Z(z) = %s", UXInt!Z(z));

	uint[] w = divDigits(z,y);
//writefln("UXInt!Z(w) = %s", UXInt!Z(w));
//writefln("UXInt!Z(x) = %s", UXInt!Z(x));
//	uint[] k = random(1);
//	z = mulDigits(x,k[0..1]);
//writefln("UXInt!Z(k) = %s", UXInt!Z(k));
//writefln("UXInt!Z(z) = %s", UXInt!Z(z));

//	uint[] rt = random(1);
//writefln("UXInt!Z(rt) = %s", UXInt!Z(rt));
//	uint[] px = mulDigits(rt,rt);
//writefln("UXInt!Z(px) = %s", UXInt!Z(px));
//	rt = sqrDigits(rt);
//writefln("UXInt!Z(rt) = %s", UXInt!Z(rt));
	writeln("passed");
}

unittest {
	writeln("===================");
	writeln("arrayops........end");
	writeln("===================");
}

//alias XInt!128 int128;

/*public XInt!Z abs(XInt!Z)(const XInt!Z arg) {
	return arg.isNegative ? negate(arg) : arg.dup;
}*/

	unittest {	// opBinary
		int128 op1, op2;
		op1 = 4; op2 = 8;
		assert(op1 + op2 == 12);
		op1 = 4; int iop = -8;
		assert(op1 + iop == -4);
		assert(op1 - iop == 12);
		assert(int128(iop) + op1 == -4);
		assert(op2 - op1 == 4);
		assert(op1 * op2 == 32);
		op1 = -4; op2 = -8;
		assert(op1 + op2 == -12);
		assert(op1 - op2 == 4);
		op1 = -4; op2 = 8;
		assert(op1 + op2 == 4);
		assert(op1 - op2 == -12);
		op1 = 5; op2 = 2;
//writefln("op1/op2 = %s", op1/op2);
//		assert(op1 / op2 == 2);
		assert(op1 % op2 == 1);
//		assert(op1 ^^ op2 == 25);
		op1 = 10101; op2 = 10001;
//writefln("op1 = %s", op1);
//writefln("op2 = %s", op2);
		assert((op1 & op2) == 10001);
		assert((op1 | op2) == 10101);
		assert((op1 ^ op2) == 100);
		op2 = 2;
writefln("op1 = %s", op1);
writefln("op2 = %s", op2);
writefln("op1 << op2 = %s", op1 << op2);
//		assert(op1 << op2 == 40404);
writefln("op1 >> op2 = %s", op1 >> op2);
		op1 = -16;
writefln("op1 = %s", op1);
writefln("op1 >> op2 = %s", op1 >> op2);
		op1 = 0xFFFFFFFF;
		op2 = 48;
writefln("op1 = %s", op1.toHexString);
writefln("op1 = %s", op1);
writefln("op1 >> op2 = %s", (op1 >> op2).toHexString);
writefln("op1 >> op2 = %s", (op1 >> op2));
//		assert(op1 >> op2 == 2525);
		op1 = 4; op2 = int128([0,1]);
//		assert(op1 + op2 == 0x100000004);
	}

/// The base class for all extended integer arithmetic exceptions.
class IntegerException: object.Exception {
	this(string msg, string file = __FILE__,
		uint line = cast(uint)__LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
};

/// Raised when a result would be undefined or impossible.
/// General Decimal Arithmetic Specification, p. 15.
class InvalidOperationException: IntegerException {
	this(string msg = "Invalid Integer Operation", string file = __FILE__,
		 uint line = cast(uint)__LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
};

/// Raised when a result would be undefined or impossible.
/// General Decimal Arithmetic Specification, p. 15.
class DivByZeroException: IntegerException {
	this(string msg = "Integer Division by Zero", string file = __FILE__,
		 uint line = cast(uint)__LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
};


unittest {
	writeln("===================");
	writeln("xinteger.........end");
	writeln("===================");
}

