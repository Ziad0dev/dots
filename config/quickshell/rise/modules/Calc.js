.pragma library

// Launcher calculator: a small recursive-descent parser, never JS eval, so
// typing in the launcher can't run code. Grammar:
//   expr   := term (('+' | '-') term)*
//   term   := unary (('*' | '/' | '%' | implicit) unary)*
//   unary  := ('-' | '+') unary | power    (so -3^2 = -(3^2))
//   power  := call ('^' unary)?            (right-associative; 2^-1 works)
//   call   := name '(' expr ')' | atom
//   atom   := number | 'pi' | 'e' | '(' expr ')'
// evaluate(text) → number, or null when the text isn't an expression.

const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, ln: Math.log, log: Math.log10, exp: Math.exp
};
const CONSTS = { pi: Math.PI, e: Math.E };

function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const c = s[i];
        if (c === " ") { i++; continue; }
        if (/[0-9.]/.test(c)) {
            // digits (with _ separators), optional fraction, optional exponent: 1e3, 2.5E-4
            const m = /^[0-9_]*\.?[0-9_]+(?:[eE][+-]?[0-9]+)?/.exec(s.slice(i));
            const n = m ? parseFloat(m[0].replace(/_/g, "")) : NaN;
            if (isNaN(n)) return null;
            out.push({ t: "num", v: n }); i += m[0].length; continue;
        }
        if (/[a-z]/i.test(c)) {
            let j = i;
            while (j < s.length && /[a-z]/i.test(s[j])) j++;
            out.push({ t: "id", v: s.slice(i, j).toLowerCase() }); i = j; continue;
        }
        if ("+-*/%^()×÷".indexOf(c) >= 0) {
            out.push({ t: "op", v: c === "×" ? "*" : c === "÷" ? "/" : c }); i++; continue;
        }
        return null;                               // anything else: not maths
    }
    return out;
}

function evaluate(text) {
    const src = String(text || "").trim().replace(/^=\s*/, "");
    if (src === "" || !/[0-9]/.test(src)) return null;
    const toks = tokenize(src);
    if (!toks || toks.length === 0) return null;
    // a lone plain number is a search, not a sum (1e3 or =42 still evaluate)
    if (toks.length === 1 && toks[0].t === "num" && /^[0-9.]+$/.test(String(text).trim())) return null;
    let p = 0;
    const peek = function () { return toks[p]; };
    const take = function (v) {
        const k = toks[p];
        if (k && k.t === "op" && k.v === v) { p++; return true; }
        return false;
    };
    function expr() {
        let v = term();
        for (;;) {
            if (take("+")) v += term();
            else if (take("-")) v -= term();
            else return v;
        }
    }
    function term() {
        let v = unary();
        for (;;) {
            if (take("*")) v *= unary();
            else if (take("/")) v /= unary();
            else if (take("%")) v %= unary();
            else {
                const k = peek();          // implicit multiplication: 2pi, 3(4+1)
                if (k && (k.t === "num" || k.t === "id" || (k.t === "op" && k.v === "("))) v *= unary();
                else return v;
            }
        }
    }
    function unary() {
        if (take("-")) return -unary();
        if (take("+")) return unary();
        return power();
    }
    function power() {
        const b = call();
        return take("^") ? Math.pow(b, unary()) : b;
    }
    function call() {
        const k = peek();
        if (k && k.t === "id") {
            p++;
            if (FUNCS[k.v]) {
                if (!take("(")) throw "(";
                const v = expr();
                if (!take(")")) throw ")";
                return FUNCS[k.v](v);
            }
            if (CONSTS[k.v] !== undefined) return CONSTS[k.v];
            throw "id";
        }
        return atom();
    }
    function atom() {
        const k = peek();
        if (!k) throw "end";
        if (k.t === "num") { p++; return k.v; }
        if (take("(")) {
            const v = expr();
            if (!take(")")) throw ")";
            return v;
        }
        throw "atom";
    }
    try {
        const v = expr();
        if (p !== toks.length || !isFinite(v)) return null;
        return v;
    } catch (e) {
        return null;
    }
}

// compact, trailing-zero-free display (12 significant digits)
function format(v) {
    if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0)) return v.toExponential(6).replace(/\.?0+e/, "e");
    return String(parseFloat(v.toPrecision(12)));
}
