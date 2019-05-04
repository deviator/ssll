#  Simple shared library load

Want use shared library in D code, but don't have binding?
You can easily write it yourself with `ssll`!

Example:

```d
module mysharedlib;

import ssll;

import std.exception : enforce;

// define possible names of lib
enum libNames = [ "mysharedlib.so", "mysharedlib.so.0", "mysharedlib.so.0.1", ];

// pointer to library
private __gshared void* lib;

void initMySharedLib()
{
    // mysharedlib is already inited;
    if (lib !is null) return;

    // try load every possible library name
    foreach (name; libNames)
    {
        lib = loadLibrary(name); // ssll call
        if (lib !is null) break;
    }

    enforce(lib, "failed to load mysharedlib");
    
    // ssll call: load symbols from shared library to functions pointers
    loadApiSymbols();

    mysharedlib_init(); // some init function from mysharedlib
}

void cleanupMySharedLib()
{
    mysharedlib_cleanup(); // some cleanup from mysharedlib
    unloadLibrary(lib); // ssll call: close lib and set pointer null
}

mixin apiSymbols; // ssll call: define function pointers

/+
  place to define or import types
 +/

// define all needed functions
@api("lib") // "lib" is name of __gshared pointer to library
{
    // name of functions must match exactly with function in library
    void mysharedlib_init() { mixin(rtlib); /* ssll mixin */ }
    void mysharedlib_cleanup() { mixin(rtlib); }

    float mysharedlib_somefunc(int a, float b) { mixin(rtlib); }
    ...
}
```