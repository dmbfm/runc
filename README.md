# runc

A small tool written in Zig that I use to run C code directly in the command line. 

## Installation

```
git clone --recurse-submodules https://github.com/dmbfm/runc.git
cd runc
zig build -Drelease-safe
./zig-out/bin/runc "int main(){ printf(\"runc!\"); return 0;}"
```

