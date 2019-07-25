// you can bind many libs in one file
module manylibs;

import ssll;

mixin SSLL_INIT;

LibHandler mosquittoLibHandler;
LibHandler libsshLibHandler;

version (Posix)
{
    private enum mosquittoLibNames = ["libmosquitto.so", "libmosquitto.so.1"];
    private enum libsshLibNames = ["libssh.so"];
}
version (Windows)
{
    private enum mosquittoLibNames = ["mosquitto.dll"];
    private enum libsshLibNames = ["libssh.dll"];
}

void loadManyLibs()
{
    import core.stdc.stdio;
    import core.stdc.string : memcpy;

    char[256] buf;

    static char* stringz(string n, char[] buf)
    {
        memcpy(buf.ptr, n.ptr, n.length);
        buf[n.length] = 0;
        return buf.ptr;
    }

    foreach (name; mosquittoLibNames)
    {
        printf("try load '%s'... ", stringz(name, buf));
        mosquittoLibHandler = loadLibrary(name);
        if (mosquittoLibHandler is null) printf("fail\n");
        else { printf("success\n"); break; }
    }
    if (mosquittoLibHandler is null) printf("can't load mosquitto library");

    foreach (name; libsshLibNames)
    {
        printf("try load '%s'... ", stringz(name, buf));
        libsshLibHandler = loadLibrary(name);
        if (libsshLibHandler is null) printf("fail\n");
        else { printf("success\n"); break; }
    }
    if (libsshLibHandler is null) printf("can't load libssh library");

    loadApiSymbols(LoadApiSymbolsVerbose.message);
}

void unloadManyLibs()
{
    unloadLibrary(mosquittoLibHandler);
    unloadLibrary(libsshLibHandler);
}

@api("mosquittoLibHandler")
{
    void mosquitto_lib_init() { mixin(SSLL_CALL); }
    int mosquitto_lib_version(int* major, int* minor, int* revision) { mixin(SSLL_CALL); }
}

@api("libsshLibHandler")
{
    void* ssh_new() { mixin(SSLL_CALL); }
    void ssh_free(void* session) { mixin(SSLL_CALL); }
    int ssh_get_version(void* session) { mixin(SSLL_CALL); }
}