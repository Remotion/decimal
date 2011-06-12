﻿// Written in the D programming language

/**
 * A D programming language implementation of the
 * General Decimal Arithmetic Specification,
 * Version 1.70, (25 March 2009).
 * (http://www.speleotrove.com/decimal/decarith.pdf)
 *
 * License: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: Paul D. Anderson
 */
/*          Copyright Paul D. Anderson 2009 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module decimal.bid;

import decimal.decimal;
import std.array: insertInPlace;
import std.bigint;
import std.bitmanip;
import std.conv;
import std.stdio;
import std.string;

struct Dec32 {

    /// The number of bits in the signed value of the decimal number.
    /// This is equal to the number of bits in the underlying integer;
    /// (must be 32, 64, or 128).
    immutable uint svalBits = 32;

    /// the number of bits in the sign bit (1, obviously)
    immutable uint signBits = 1;

    /// The number of bits in the unsigned value of the decimal number.
    immutable uint unsignedBits = 31; // = svalBits - signBits;

    /// The number of bits in the (biased) exponent.
    immutable uint expoBits = 8;

    /// The number of bits in the coefficient when the value is
    /// explicitly represented.
    immutable uint explicitBits = 23;

    /// The number of bits used to indicate special values and implicit
    /// representation
    immutable uint testBits = 2;

    /// The number of bits in the coefficient when the value is implicitly
    /// represented. The three missing bits (the most significant bits)
    /// are always '100'.
    immutable uint implicitBits = 21; // = explicitBits - testBits;

    /// The number of bits in the payload of a NaN.
    immutable uint payloadBits = 21; // = implicitBits;

    /// The number of special bits.
    /// These bits are used to indicate infinities and NaNs.
    /// The number includes the two test bits.
    immutable uint specialBits = 6;

    /// The number of bits that follow the special bits in infinities or NaNs.
    /// These bits are always set to zero in special values.
    /// Their number is simply the remaining number of bits
    /// when all others are accounted for.
    immutable uint anonBits = 4;
            // = svalBits - payloadBits - specialBits - signBits;

    /// The exponent bias. The exponent is stored as an unsigned number and
    /// the bias is subtracted from the unsigned value to give the true
    /// (signed) exponent.
    immutable int BIAS = 101;

    /// The maximum biased exponent.
    /// The largest binary number that can fit in the width of the
    /// exponent without setting the first to bits to 11.
    immutable uint MAX_BSXP = 0xBF;

    // The value of the special bits when the number is a signaling NaN.
    immutable uint SV_SNAN = 0x3E;
    // The value corresponding to a (positive) signaling NaN.
    immutable uint snan_val = 0x7E000000;
    // The value of the special bits when the number is a quiet NaN.
    immutable uint SV_QNAN = 0x3C;
    // The value corresponding to a (positive) quiet NaN.
    immutable uint qnan_val = 0x7C000000;
    // The value of the special bits when the number is infinity.
    immutable uint SV_INF  = 0x38;
    // The value corresponding to (positive) infinity.
    immutable uint inf_val = 0x78000000;

    // The maximum coefficient that fits in an explicit number.
    immutable uint MAX_XPLC = 0x7FFFFF; // = 8388607;
    // The maximum coefficient allowed in an implicit number.
    immutable uint MAX_IMPL = 9999999;  // = 0x98967F;
    // The maximum exponent allowed in this representation.
    immutable int  MAX_EXPO  =   90;    // = MAX_BSXP - BIAS;
    // The minimum exponent allowed in this representation.
    immutable int  MIN_EXPO  = -101;    // = 0 - BIAS.
    // The min and max exponents aren't symmetrical.

    // union providing different views of the number representation.
    private union {

        // entire 32-bit integer
        uint value = qnan_val;

        // A = unsigned value and sign bit
        mixin (bitfields!(
            uint, "uValue", unsignedBits,
            bool, "signed", signBits)
        );
        // Ex = explicit finite number:
        //     full coefficient, exponent and sign
        mixin (bitfields!(
            uint, "mantEx", explicitBits,
            uint, "expoEx", expoBits,
            bool, "signEx", signBits)
        );
        // Im = implicit finite number:
        //      partial coefficient, exponent, test bits and sign bit.
        mixin (bitfields!(
            uint, "mantIm", implicitBits,
            uint, "expoIm", expoBits,
            uint, "testIm", testBits,
            bool, "signIm", signBits)
        );
        // Sv = special values: infinities, qNaN and sNan:
        //      payload, unused bits, special bits and sign bit.
        mixin (bitfields!(
            uint, "pyldSv", payloadBits,
            uint, "anonSv", anonBits,
            uint, "spclSv", specialBits,
            bool, "signSv", signBits)
        );
    }

    public:

    @property bool sign() {
        return signed;
    }

    @property bool sign(bool value) {
        signed = value;
        return signed;
    }

    @property
    const int exponent() {
        if (this.isExplicit) {
            return expoEx;
        }
        else {
            return expoIm;
        }
    }

    // TODO: Need to add range checks >= minExpo and <= maxExpo
    // TODO: Need to define exceptions. Out of range exponents: infinity or zero.
    @property
     int exponent(int expo) {
        if (this.isExplicit) {
            expoEx = expo;
        }
        else if (this.isFinite) {
            expoIm = expo;
        }
        else {
            expo = 0;
        }
        return expo;
    }

    @property
    const uint coefficient() {
        if (this.isExplicit) {
            return mantEx;
        }
        else if (this.isFinite) {
            return mantIm | (0B100 << implicitBits);
        }
        else if (this.isSpecial) {
            return mantIm;  // the "coefficient" of a NaN is the payload.
        }
        else {
            return 0;       // infinities have a zero coefficient.
        }
    }

    // If the new coefficient is > MAX_XPLC this could cause an
    // explicit number to become an implicit number, and vice versa.
    @property
    uint coefficient(uint mant) {
        if (mant > MAX_XPLC) {
            mant &= 0x7FFFFFF;  // only store the last 21 bits.
        }
        else {
            mantEx = mant;
            testIm = 0B00;
        }
        if (this.isExplicit) {
            mant = value;
        }
        else {
            mant = value | 0x7FFFFFFF;
        }
        return mant;
    }

    @property
    int digits() {
        return 7;
    }


    immutable Dec32 qNaN = Dec32(qnan_val);
    immutable Dec32 sNaN = Dec32(snan_val);
    immutable Dec32 Infinity = Dec32(inf_val);
    immutable Dec32 Zero = Dec32(0);

    // floating point properties
    static Dec32 init()       { return nan; }
    static Dec32 infinity()   { return Dec32(inf_val ); }
    static Dec32 nan()        { return Dec32(qnan_val); }
    static Dec32 epsilon()    { return qNaN; }
    static Dec32 max()        { return qNaN; } // 9999999E+90;
    static Dec32 min_normal() { return qNaN; } // 1E-101;
    static Dec32 im()         { return Zero; }
    const  Dec32 re()         { return this; }

    static int dig()        { return 7; }
    static int mant_dig()   { return 24; }
    static int max_10_exp() { return MAX_EXPO; }
    static int max_exp()    { return -1; }
    static int min_10_exp() { return MIN_EXPO; }
    static int min_exp()    { return -1; }


//--------------------------------
//  classification properties
//--------------------------------

    const bool isExplicit() {
        return testIm != 0b11;
    }

    /**
     * Returns true if this number's representation is canonical.
     */
    const bool isCanonical() {
        return true;
    }

    /**
     * Returns true if this number is +\- zero.
     */
    const bool isZero() {
        return uValue == 0;
    }

    /**
     * Returns true if this number is a quiet or signaling NaN.
     */
    const bool isNaN() {
        return isQuiet || isSignaling;
    }

    /**
     * Returns true if this number is a signaling NaN.
     */
    const bool isSignaling() {
        return spclSv == SV_SNAN;
    }

    /**
     * Returns true if this number is a quiet NaN.
     */
    const bool isQuiet() {
        return spclSv == SV_QNAN;
    }

    /**
     * Returns true if this number is +\- infinity.
     */
    const bool isInfinite() {
        return spclSv == SV_INF;
    }

    /**
     * Returns true if this number is neither infinite nor a NaN.
     */
    const bool isFinite() {
        return !isNaN && !isInfinite;
    }

    /**
     * Returns true if this number is a NaN or infinity.
     */
    const bool isSpecial() {
        return isInfinite || isNaN;
    }

    /**
     * Returns true if this number is negative. (Includes -0)
     */
    const bool isSigned() {
        return signed;
    }

    const bool isNegative() {
        return signed;
    }

    /**
     * Returns true if this number is subnormal.
     */
    const bool isSubnormal() {
        if (isSpecial) return false;
        return adjustedExponent < MIN_EXPO;
    }

    /**
     * Returns true if this number is normal.
     */
    const bool isNormal() {
        if (isSpecial) return false;
        return adjustedExponent >= MIN_EXPO;
    }

    // TODO: this is where the "digits" come into play.
    /**
     * Returns the value of the adjusted exponent.
     */
     const int adjustedExponent() {
        return exponent + 6;
     }
//--------------------------------
//  constructors
//--------------------------------

    // TODO: canonicalize
    /**
     * Creates a Dec32 from an unsigned integer.
     */
    public this(const uint u) {
        value = u;
    }

    /**
     * Creates a Dec32 from a long integer.
     */
    public this(const long n) {
        signed = n < 0;
        expoEx = 0;
        mantEx = cast(uint) std.math.abs(n);
    }

    /**
     * Creates a Dec32 from a Decimal
     */
    public this(Decimal num) {
        // check for special values
        if (num.isInfinite) {
            value = inf_val;
            signed = num.sign;
            return;
        }
        if (num.isQuiet) {
            value = qnan_val;
            signed = num.sign;
            return;
        }
        if (num.isSignaling) {
            value = snan_val;
            signed = num.sign;
            return;
        }
        if (num.isZero) {
            value = 0;
            signed = num.sign;
            return;
        }

        // number is finite
        writefln("num.mant = %d", num.mant);
        writeln("num.expo = ", num.expo);
        if (num.mant > MAX_IMPL || num.expo > MAX_EXPO || num.expo < MIN_EXPO) {
            throw new Exception("Can't fit in this struct!");
        }

        uint mant = cast(uint)num.mant.toInt;
        if (mant > MAX_XPLC) {
            // set the test bits
            testIm = 0b11;
            signed = num.sign;
            expoIm = num.expo;
            // TODO: this can be done with a mask.
            mantIm = mant % MAX_XPLC;
        }
        else {
            signed = num.sign;
            expoEx = num.expo;
            mantEx = mant;
        }
    }

    unittest {
        write("this(Decimal)...");
        writeln("test missing");
    }

//--------------------------------
//  conversions
//--------------------------------

    /**
     * Converts a Dec32 to a Decimal
     */
    public Decimal toDecimal() {
        uint mant;
        int  expo;
        bool sign;

        if (isExplicit) {
            mant = mantEx;
            sign = signed;
            expo = expoEx - BIAS;
        }
        else {
            // check for special values
            if (signed) {
                sign = true;
                mant = value & 0x7FFFFFFF;
            }
            else {
                sign = false;
                mant = value;
            }
            if (uValue == inf_val) {
                return Decimal(sign, "Inf", 0);
            }
            if (uValue == qnan_val) {
                return Decimal(sign, "qNaN", 0);
            }
            if (uValue == snan_val) {
                return Decimal(sign, "sNan", 0);
            }
            // number is finite, set msbs
            mant = mantIm | (0b100 << implicitBits);
            expo = expoIm - BIAS;
            sign = signed;
        }
        return Decimal(sign, BigInt(mant), expo);
    }

    unittest {
        write("toDecimal...");
        writeln("test missing");
    }

    /**
     * Converts a Dec32 to a hexadecimal string
     */
    const public string toHexString() {
         return format("0x%08X", value);
    }

    unittest {
        write("toHexString...");
        writeln("test missing");
    }

    /**
     * Converts a Dec32 to a string
     */
    const public string toString() {
         return toSciString(this);
    }

    unittest {
        write("toString...");
        writeln("test missing");
    }

}

/**
 * Detect whether T is a decimal type.
 */
template isDecimal(T) {
    enum bool isDecimal = is(T: Dec32);
}

unittest {
    write("isDecimal(T)...");
    writeln("test missing");
}

/*    staticIndexOf!(Unqual!(T),
        Dec32) >= 0;*/

/*unittest
{
    static assert(isIntegral!(byte));
    static assert(isIntegral!(const(byte)));
    static assert(isIntegral!(immutable(byte)));
    static assert(isIntegral!(shared(byte)));
    static assert(isIntegral!(shared(const(byte))));
}*/


// UNREADY: toSciString. Description. Unit Tests.
/**
 * Converts a Decimal number to a string representation.
 */
public string toSciString(const Dec32 num) {
    return decimal.conv.toSciString!Dec32(num);
}

unittest {
    write("toSciString...");
    writeln("tests missing");
}

// UNREADY: toEngString. Description. Unit Tests.
/**
 * Converts a Decimal number to a string representation.
 */
public string toEngString(const Dec32 num) {
    return decimal.conv.toEngString!Dec32(num);
}

unittest {
    write("toEngString...");
    writeln("tests missing");
}

unittest {
//    writefln("num.mant = 0x%08X", num.mant);
    writefln("MAX_IMPL = 0x%08X", Dec32.MAX_IMPL);
    writefln("MAX_XPLC = 0x%08X", Dec32.MAX_XPLC);
    writeln("MAX_EXPO = ", Dec32.MAX_EXPO);
    writeln("MIN_EXPO = ", Dec32.MIN_EXPO);

    writefln("qnan_val = 0x%08X", Dec32.qnan_val);
    writeln("Dec32.qNaN = ", Dec32.qNaN);

    Dec32 dec = Dec32();
    writeln("dec = ", dec);
    writeln("dec.mantEx = ", dec.mantEx);

    Decimal num = Decimal(0);
    dec = Dec32(num);
    writeln("num = ", num);
    writeln("dec = ", dec);

    num = Decimal(1);
    dec = Dec32(num);
    writeln("num = ", num);
    writeln("dec = ", dec);

    num = Decimal(-1);
    dec = Dec32(num);
    writeln("num = ", num);
    writeln("dec = ", dec);

    num = Decimal(-16000);
    dec = Dec32(num);
    writeln("num = ", num);
    writeln("dec = ", dec);

    num = Decimal(uint.max);
    dec = Dec32(num);
    writeln("num = ", num);
    writeln("dec = ", dec);
}

