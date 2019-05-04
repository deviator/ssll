///
module ssll;

import core.sys.posix.dlfcn;

import std.string : toStringz;
import std.exception : enforce;

struct ApiUDA { string libname; }
auto api(string lname="lib") { return ApiUDA(lname); }

string apiFunctionPointerName(string f) { return "__"~f~"_dlg"; }

///
void* loadLibrary(string name)
{
    return dlopen(name.toStringz, RTLD_LAZY);
}

///
void unloadLibrary(ref void* lib)
{
    dlclose(&lib);
    lib = null;
}

private enum __initDeclare = q{
    import std.meta;
    import std.typecons;
    import std.traits;
    import std.string;
    import core.sys.posix.dlfcn : dlsym;

    enum __dimmy;
    alias __this = AliasSeq!(__traits(parent, __dimmy))[0];
    enum __name = __traits(identifier, __this);
};

private enum __callDeclare = q{
    enum __pit = [ParameterIdentifierTuple!__this];
    static if (!__pit.length) enum __params = "";
    else enum __params = "%-(%s, %)".format(__pit);
    enum __call = "__fnc(%s);".format(__params);
    static if (is(ReturnType!__this == void))
        enum __result = __call;
    else
        enum __result = "return " ~ __call;
    mixin(__result);
};

string rtLib()
{
    return __initDeclare ~ q{
    mixin("auto __fnc = %s;".format(apiFunctionPointerName(__name)));
    } ~ __callDeclare;
}

mixin template apiSymbols()
{
    import std.meta;
    import std.typecons;
    import std.traits;

    enum __dimmy;

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

    alias apiFuncs = funcsByUDA!(__traits(parent, __dimmy), ApiUDA);

    void loadApiSymbols()
    {
        import std.string;
        import core.sys.posix.dlfcn;
        foreach (f; apiFuncs)
        {
            enum libname = getUDAs!(f, ApiUDA)[$-1].libname;
            enum fname = __traits(identifier, f);
            enum pname = apiFunctionPointerName(fname);
            mixin(format(`%2$s = cast(typeof(%2$s))dlsym(%3$s, "%1$s".toStringz);`, fname, pname, libname));
        }
    }

    mixin funcPointers!apiFuncs;
}

mixin template funcPointers(funcs...)
{
    import std.string;
    static if (funcs.length == 0) {}
    else static if (funcs.length == 1)
    {
        alias __this = funcs[0];
        mixin(`private extern(C) @nogc nothrow ReturnType!__this function(Parameters!__this) %s;`
                .format(apiFunctionPointerName(__traits(identifier, __this))));
    }
    else
    {
        mixin funcPointers!(funcs[0..$/2]);
        mixin funcPointers!(funcs[$/2..$]);
    }
}