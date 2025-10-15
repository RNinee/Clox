# Clox — Crafting Interpreters (up to Superclasses)

A minimal Lox bytecode VM implemented in C, following the Crafting Interpreters book, completed through the “Superclasses” chapter.

Upstream chapter: https://craftinginterpreters.com/superclasses.html

## Features
- Bytecode VM with stacks, call frames, closures, and upvalues.
- Objects: strings, functions, classes, instances, bound methods.
- Single inheritance and super calls:
  - OP_INHERIT, OP_GET_SUPER, OP_SUPER_INVOKE.
- Instance fields, method lookup/binding, initializers (init).
- Hash table for globals/strings/methods, and a mark-sweep GC.
- Built-in native: clock().

## Layout
- VM/runtime: vm.c, vm.h
- Compiler and scanner: compiler.c/.h, scanner.c/.h
- Bytecode chunk: chunk.c/.h
- Values/objects: value.c/.h, object.c/.h
- Tables/GC: table.c/.h, memory.c/.h
- Disassembler: debug.c/.h
- Entry point and build: main.c, Makefile

## Build (Windows)
- With Make (MSYS2/MinGW): 
  - make
- Or directly with gcc (example):
  - gcc -std=c99 -O2 -Wall -o clox main.c chunk.c compiler.c debug.c memory.c object.c scanner.c table.c value.c vm.c

## Run
- REPL: .\clox
- Script: .\clox path\to\script.lox

Example:
```lox
class Base { method() { print "Base.method()"; } }
class Derived < Base {
  method() {
    print "Derived.method()";
    super.method();
  }
}
Derived().method();
```

## License (website)
This project is based on material from the Crafting Interpreters website, whose text/content is licensed under:
- Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND 4.0)
- Details: https://creativecommons.org/licenses/by-nc-nd/4.0/
- Website: https://craftinginterpreters.com/

Not affiliated with the author; for educational use only.