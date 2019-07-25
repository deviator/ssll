import core.stdc.stdio;

import manylibs;
import onelib;

extern (C) int main()
{
    {
        loadManyLibs(); 
        scope (exit) unloadManyLibs();

        if (mosquittoLibHandler !is null)
        {
            int a, b, c;
            mosquitto_lib_version(&a, &b, &c);
            printf("mosquitto: %d.%d.%d\n", a, b, c);
        }
        else printf("mosquitto not loaded\n");


        if (libsshLibHandler !is null)
        {
            auto s = ssh_new();
            scope (exit) ssh_free(s);
            auto v = ssh_get_version(s);
            printf("ssh version: %d\n", v);
        }
        else printf("libssh not loaded\n");
    }

    if (loadOneLib())
    {
        scope (exit) unloadOneLib();

        printf("gtk-3: %d.%d.%d\n",
            gtk_get_major_version(),
            gtk_get_minor_version(),
            gtk_get_micro_version(),
        );
    }
    else printf("gtk-3 not loaded\n");

    return 0;
}
