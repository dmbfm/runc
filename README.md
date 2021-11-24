# runc

A small tool written in Zig that I use to run C code directly in the command line. 

## Requirements

You need to have [Zig](https://ziglang.org/) installed to build this tool and clang installed for running it.

## Installation

After you have Zig [installed](https://ziglang.org/download/) and up and running, just type in:
```
git clone --recurse-submodules https://github.com/dmbfm/runc.git
cd runc
zig build -Drelease-safe
./zig-out/bin/runc "int main(){ printf(\"runc!\"); return 0;}"
```

## Usage
``` 
Usage: runc [-q] [-{d|f|i}m] [-k] "source code"

Options:
  -q                     Quick mode: the source code is placed directly inside a builtin main funcion.
  -dm                    Math mode (double): evaluates the expression and prints the result.
  -fm                    Math mode (float)
  -im                    Math mode (int)
  -k                     Keep the generated source file. (the filename is "runc_[somenumber].c"
```

Just pass your C code inside single or double quotes as the last argument to `runc`:
``` 
runc 'int main(){ printf("I\'m running C code!"); return 0; }'

```

The `-q` flag enabled the quick mode, where the code is placed directly inside a builtin main function:
``` 
runc -q 'printf("Hello!\n");'
```

Using the `-{d|f|i}m` math modes you can output the result of a mathematical expression:
``` 
runc -dm '2 * sin(1.23 * cos(0.21))'

1.866228
```

## C Headers

Currently `runc` inserts the following C headers before the user-provided source-code:
```
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
```

Of course it is pretty straightforward to add other headers to your code:
``` 
runc '#include <math.h>
int main() {
  double x = sin(1.324);
  printf("x = %f\n", x);
  return 0;
}
'
```

## Todo
- [ ] Add option to configure which compiler to use
- [ ] Pass compiler and linker flags
- [ ] User configuration file
- [ ] Accept piped input

