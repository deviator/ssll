module onelib;

import ssll;

mixin SSLL_INIT;

private LibHandler lib;

version (Posix)   private enum libNames = ["libgtk-3.so", "libgtk-3.so.0"];
version (Windows) private enum libNames = ["gtk-3.dll"];

bool loadOneLib()
{
    import core.stdc.stdio;
    import core.stdc.string : memcpy;

    char[256] buf;

    foreach (name; libNames)
    {
        memcpy(buf.ptr, name.ptr, name.length);
        buf[name.length] = 0;
        printf("try load '%s'... ", buf.ptr);

        lib = loadLibrary(name);
        if (lib is null) printf("fail\n");
        else { printf("success\n"); break; }
    }

    loadApiSymbols(LoadApiSymbolsVerbose.message);

    return lib !is null;
}

void unloadOneLib() { unloadLibrary(lib); }

@api(Linkage.c) // "lib" is default parameter
{
    int gtk_get_major_version() { mixin(SSLL_CALL); }
    int gtk_get_minor_version() { mixin(SSLL_CALL); }
    int gtk_get_micro_version() { mixin(SSLL_CALL); }
}