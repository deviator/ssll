///
module ssll;

import std.string : toStringz;
import std.exception : enforce;

version (Posix)
{
    import core.sys.posix.dlfcn;
}
else version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.windef : HINSTANCE;
}
else static assert(0, "unknown platform");

struct ApiUDA { string libname; }
auto api(string lname="lib") { return ApiUDA(lname); }

string apiFunctionPointerName(string f) { return "__"~f~"_dlg"; }

version (Posix) alias LibHandler = void*;
version (Windows) alias LibHandler = HINSTANCE;

///
LibHandler loadLibrary(string name)
{
    if (name.length == 0) return null;

    version (Posix)
        return dlopen(name.toStringz, RTLD_LAZY);
    version (Windows)
    {
        import core.stdc.stdlib : free, malloc;

        import core.sys.windows.winnls : CP_UTF8, MultiByteToWideChar;
        import core.sys.windows.winnt : WCHAR;

        auto len = MultiByteToWideChar(CP_UTF8, 0, name.ptr,
                                cast(int)name.length, null, 0);

        if (len == 0) return null;

        auto buf = cast(WCHAR*)malloc((len+1) * WCHAR.sizeof);
        if (buf is null) return null;
        scope (exit) free(buf);

        len = MultiByteToWideChar(CP_UTF8, 0, name.ptr,
                                cast(int)name.length, buf, len);
        if (len == 0) return null;

        buf[len] = '\0';
        return LoadLibraryW(buf);
    }
}

///
void unloadLibrary(ref LibHandler lib)
{
    version (Posix)
    {
        dlclose(&lib);
        lib = null;
    }
    version (Windows)
    {
        FreeLibrary(lib);
        lib = null;
    }
}

auto getSymbol(LibHandler lib, string name)
{
    version (Posix)
        return dlsym(lib, name.toStringz);
    version (Windows)
        return GetProcAddress(lib, name.toStringz);
}

private enum __initDeclare = q{
    import std.meta;
    import std.typecons;
    import std.traits;
    import std.string;
    //import core.sys.posix.dlfcn : dlsym;

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

enum LoadApiSymbolsVerbose
{
    none,
    message,
    assertion
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

    void loadApiSymbols(LoadApiSymbolsVerbose verbose=LoadApiSymbolsVerbose.none)
    {
        import std.format : format;
        import std.stdio : stderr;

        foreach (f; apiFuncs)
        {
            enum libname = getUDAs!(f, ApiUDA)[$-1].libname;
            enum fname = __traits(identifier, f);
            enum pname = apiFunctionPointerName(fname);
            mixin(format!`%2$s = cast(typeof(%2$s))getSymbol(%3$s, "%1$s");`(fname, pname, libname));
            if (mixin(pname ~ " is null"))
            {
                auto errmsg = format!`can't find '%s' function`(fname);
                with (LoadApiSymbolsVerbose) final switch (verbose) 
                {
                    case none: break;
                    case message: stderr.writeln(errmsg); break;
                    case assertion: assert(0, errmsg);
                }
            }
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
        mixin(`private __gshared extern(C) @nogc nothrow ReturnType!__this function(Parameters!__this) %s;`
                .format(apiFunctionPointerName(__traits(identifier, __this))));
    }
    else
    {
        mixin funcPointers!(funcs[0..$/2]);
        mixin funcPointers!(funcs[$/2..$]);
    }
}