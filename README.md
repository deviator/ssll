#  Simple shared library load

Want use shared library in D code, but don't have binding?
You can easily write it yourself with `ssll`!

Example:

```d
module mysharedlib;

import ssll;

mixin SSLL_INIT; // define function pointers and loadApiSymbols function

// define possible names of lib
enum libNames = [ "mysharedlib.so", "mysharedlib.so.0", "mysharedlib.so.0.1", ];

// pointer to library
private LibHandler lib;

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

    if (lib is null) assert(0, "failed to load mysharedlib");
    
    // ssll call: load symbols from shared library to functions pointers
    // assert if can't load symbol
    loadApiSymbols(LoadApiSymbolsVerbose.assertion);

    mysharedlib_init(); // some init function from mysharedlib
}

void cleanupMySharedLib()
{
    mysharedlib_cleanup(); // some cleanup from mysharedlib
    unloadLibrary(lib); // ssll call: close lib and set pointer null
}

/+
  place to define or import types
 +/

/+ define all needed functions
   
    "lib" is name of library pointer
    Linkage.c is linkage of pointer for loading functions addresses
 +/
@api("lib", Linkage.c)
{
    // name of functions must match exactly with function in library
    void mysharedlib_init() { mixin(SSLL_CALL); }
    void mysharedlib_cleanup() { mixin(SSLL_CALL); }

    // you must specify names of function parameters because they used in SSLL_CALL
    float mysharedlib_somefunc(int a, float b) { mixin(SSLL_CALL); }
    ...
}
```

## SSLL is compatible with `-betterC`

See [example](./example)

## Real examples:

* [sdutil](https://github.com/deviator/sdutil)
* [mosquittod](https://github.com/deviator/mosquittod)
* [libssh](https://github.com/deviator/libssh)

## Alternatives

* [bindbc](https://github.com/BindBC/bindbc-loader) -- from Derelict creators (betterC compatible)
* [dynamic](https://github.com/s-ludwig/dynamic) -- suitable for existing bindings