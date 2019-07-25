///
module ssll;

import core.stdc.stdlib : free, malloc;
import core.stdc.string : memcpy;

public import std.meta : AliasSeq;
public import std.traits : hasUDA, getUDAs,
    ReturnType, Parameters, ParameterIdentifierTuple;

version (Posix)
{
    import core.sys.posix.dlfcn : dlopen, dlclose, RTLD_LAZY;

    alias LibHandler = void*; ///
}
else version (Windows)
{
    import core.sys.windows.winbase : LoadLibraryA, FreeLibrary;
    import core.sys.windows.windef : HINSTANCE;

    alias LibHandler = HINSTANCE; ///
}
else static assert(0, "unknown platform");

@nogc nothrow extern(C):

struct ApiUDA { string libname; }

///
auto api(string lname="lib") @property { return ApiUDA(lname); }

///
LibHandler loadLibrary(string name)
{
    const ln = name.length;

    if (ln == 0) return null;

    auto buf = cast(char*)malloc(ln+1);
    if (buf is null) return null;
    scope (exit) free(buf);

    memcpy(buf, name.ptr, ln);
    buf[ln] = '\0';

    version (Posix)   return dlopen(buf, RTLD_LAZY);
    version (Windows) return LoadLibraryA(buf);
}

///
void unloadLibrary(ref LibHandler lib)
{
    version (Posix)   dlclose(&lib);
    version (Windows) FreeLibrary(lib);

    lib = null;
}

/// used in rtLib mixin
template commaSeparated(string[] arr)
{
    template r(string[] a)
    {
        static if (a.length == 0) enum r = "";
        else static if (a.length == 1) enum r = a[0];
        else enum r = r!(a[0..$/2]) ~ ", " ~ r!(a[$/2..$]);
    }

    enum commaSeparated = r!arr;
}

///
enum SSLL_CALL = q{
    enum __dimmy_symbol__;
    alias __self_function__ = AliasSeq!(__traits(parent, __dimmy_symbol__))[0];
    mixin((is(ReturnType!__self_function__ == void) ? "" : "return ") ~
            apiFunctionPointerName!(__traits(identifier, __self_function__)) ~
        "(" ~ commaSeparated!([ParameterIdentifierTuple!__self_function__]) ~ ");");
};

enum LoadApiSymbolsVerbose
{
    none,
    message,
    assertion
}

mixin template SSLL_INIT()
{
    alias apiFuncs = funcsByUDA!(__traits(parent, loadApiSymbols), ApiUDA);

    void loadApiSymbols(LoadApiSymbolsVerbose verbose=LoadApiSymbolsVerbose.none)
    {
        version (Posix)
        {
            import core.sys.posix.dlfcn : dlsym;
            alias getSymbol = dlsym;
        }
        version (Windows)
        {
            import core.sys.windows.windows : GetProcAddress;
            alias getSymbol = GetProcAddress;
        }

        foreach (f; apiFuncs)
        {
            enum libname = getUDAs!(f, ApiUDA)[$-1].libname;
            enum fname = __traits(identifier, f) ~ '\0';
            enum pname = apiFunctionPointerName!(fname[0..$-1]);
            mixin(pname ~ " = cast(typeof(" ~ pname ~ "))getSymbol("
                                ~ libname ~ ", fname.ptr);");
            if (mixin(pname ~ " is null"))
            {
                with (LoadApiSymbolsVerbose) final switch (verbose) 
                {
                    case none: break;
                    case message:
                        import core.stdc.stdio : printf;
                        printf("can't find '%s' function\n", fname.ptr);
                        break;
                    case assertion: assert(0, fname[0..$-1]);
                }
            }
        }
    }

    mixin funcPointers!apiFuncs;
}

template apiFunctionPointerName(string f)
{ enum apiFunctionPointerName = "__" ~ f ~"_fnc_ptr"; }

template funcsByUDA(alias symbol, uda)
{
    template impl(lst...)
    {
        static if (lst.length == 1)
        {
            static if (is(typeof(__traits(getMember, symbol, lst[0])) == function))
            {
                alias ff = AliasSeq!(__traits(getMember, symbol, lst[0]))[0];
                static if (hasUDA!(ff, uda)) alias impl = AliasSeq!(ff);
                else alias impl = AliasSeq!();
            }
            else alias impl = AliasSeq!();
        }
        else alias impl = AliasSeq!(impl!(lst[0..$/2]), impl!(lst[$/2..$]));
    }

    alias funcsByUDA = impl!(__traits(allMembers, symbol));
}

mixin template funcPointers(funcs...)
{
    static if (funcs.length == 0) {}
    else static if (funcs.length == 1)
    {
        alias __this = funcs[0];
        mixin(`private __gshared extern(C) @nogc nothrow ReturnType!__this function(Parameters!__this) ` ~
                apiFunctionPointerName!(__traits(identifier, __this)) ~ `;`);
    }
    else
    {
        mixin funcPointers!(funcs[0..$/2]);
        mixin funcPointers!(funcs[$/2..$]);
    }
}