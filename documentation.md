# Clox: A Bytecode VM for Lox

This repository contains a complete implementation of a tree-walk compiler and bytecode virtual machine for the Lox programming language from Crafting Interpreters (C version). It includes a hand-written scanner, a Pratt parser/bytecode compiler, a stack-based VM with call frames and closures, a hash table for globals/strings, interned strings, and a mark-sweep garbage collector.

Use this document as a guided tour of the code and a practical reference when hacking on the VM.

---

## Quick start

- Build (Windows PowerShell):
  - Prerequisite: GCC/Clang in PATH (e.g., via MinGW or MSYS2). The Makefile targets `gcc` by default.
  - Build the executable:
    - `make`
  - Clean artifacts:
    - `make clean`

- Run REPL:
  - `.\\app`

- Run a script:
  - `.\\app path\\to\\script.lox`

If `make` is not available, compile directly with GCC:
- `gcc -Wall -Wextra -std=gnu99 -o app main.c chunk.c memory.c debug.c value.c vm.c scanner.c compiler.c object.c table.c`

---

## Project layout

- `common.h` — Common includes and global flags (debugging, constants)
- `chunk.[ch]` — Bytecode chunk structure, opcodes, and constant pool
- `compiler.[ch]` — Pratt parser and bytecode emitter that compiles Lox to chunks
- `debug.[ch]` — Disassembler and bytecode pretty printer
- `memory.[ch]` — Memory management and mark-sweep GC
- `object.[ch]` — Heap-allocated runtime objects (strings, functions, closures, classes, instances, bound methods)
- `scanner.[ch]` — Hand-written scanner (lexer) producing tokens
- `table.[ch]` — Open addressing hash table for strings→values and interning
- `value.[ch]` — Tagged union Value, ValueArray helpers, and printing
- `vm.[ch]` — Virtual machine, interpreter loop, call frames, closures, methods, and natives
- `main.c` — CLI: REPL and script runner
- `Makefile` — Build configuration

---

## Execution pipeline

1. Source code → tokens: `scanner.c`
2. Tokens → bytecode: `compiler.c`
   - Pratt parser with precedence table
   - Emits instructions into a `Chunk`
   - Manages locals, scopes, upvalues for closures
3. Bytecode → execution: `vm.c`
   - Stack-based VM with `CallFrame`s, instruction pointer (ip), and operand stack
   - Supports functions, closures, classes, instances, fields, methods, and super calls
   - Natives (e.g., `clock`) registered in `initVM`

---

## Core data structures

### Value and ValueArray (`value.h`)
- `Value` is a tagged union with types: BOOL, NIL, NUMBER, OBJ
- Access macros: `IS_*/AS_*` convert between tagged and C types
- `ValueArray` is a growable array used primarily by chunks for constants

### Objects (`object.h`)
All heap objects share header `Obj { type, isMarked, next }`:
- `ObjString` — interned strings with FNV-1a hash
- `ObjFunction` — function arity, upvalue count, bytecode `Chunk`, and optional name
- `ObjClosure` — wraps a function with array of `ObjUpvalue*`
- `ObjUpvalue` — captures and later closes over stack slots
- `ObjClass` — name and methods table
- `ObjInstance` — reference to class and fields table
- `ObjBoundMethod` — receiver + method closure for property access
- `ObjNative` — wraps a C function `NativeFn(int argCount, Value* args)`

### Chunk and OpCode (`chunk.h`)
A `Chunk` contains:
- `uint8_t* code` — bytecode stream
- `int* lines` — parallel array mapping each instruction byte to a source line
- `ValueArray constants` — constant pool used by `OP_CONSTANT` and name refs

Key opcodes (all opcodes are listed in `chunk.h`):
- Stack and literals: `OP_NIL`, `OP_TRUE`, `OP_FALSE`, `OP_CONSTANT`, `OP_POP`
- Arithmetic and logic: `OP_ADD`, `OP_SUBTRACT`, `OP_MULTIPLY`, `OP_DIVIDE`, `OP_NEGATE`, `OP_NOT`, comparisons `OP_EQUAL`, `OP_GREATER`, `OP_LESS`
- Locals/upvalues/globals: `OP_GET_LOCAL`, `OP_SET_LOCAL`, `OP_GET_UPVALUE`, `OP_SET_UPVALUE`, `OP_GET_GLOBAL`, `OP_DEFINE_GLOBAL`, `OP_SET_GLOBAL`
- Control flow: `OP_JUMP`, `OP_JUMP_IF_FALSE` (both use 2-byte big-endian offsets), `OP_LOOP`
- Calls: `OP_CALL` (1-byte arg count)
- Properties/methods: `OP_GET_PROPERTY`, `OP_SET_PROPERTY`, `OP_INVOKE` (name const idx + arg count), `OP_GET_SUPER`, `OP_SUPER_INVOKE`, `OP_METHOD`
- Classes/inheritance: `OP_CLASS`, `OP_INHERIT`
- Closures/upvalues: `OP_CLOSURE`, `OP_CLOSE_UPVALUE`
- Control: `OP_RETURN`, `OP_PRINT`

`debug.c` provides `disassembleChunk` and `disassembleInstruction` to print human-readable bytecode.

---

## The compiler (`compiler.c`)

- Pratt parser driven by `ParseRule rules[]` mapping tokens to prefix/infix parse functions and precedences.
- Scopes: `beginScope`/`endScope` with `Local locals[UINT8_COUNT]` and `scopeDepth`.
- Variables resolve to:
  - Local (`OP_GET_LOCAL`/`OP_SET_LOCAL`) via `resolveLocal`
  - Upvalue (`OP_GET_UPVALUE`/`OP_SET_UPVALUE`) via `resolveUpvalue`
  - Global (identifier constant → `OP_GET_GLOBAL`, etc.)
- Functions and closures:
  - `function()` compiles a function literal; emits `OP_CLOSURE` followed by upvalue descriptors
  - `ObjFunction.upvalueCount` limits closure captures
- Classes and inheritance:
  - `classDeclaration()` compiles `class`, optional `< Super`, methods, and emits `OP_INHERIT`
  - `super` and `this` are validated contextually and lowered to appropriate opcodes
- Control flow:
  - If/else, while, for are compiled to jumps/loops with patching via `emitJump` and `patchJump`

Error handling uses panic mode to resynchronize at statement boundaries.

---

## The VM (`vm.c`)

- State:
  - Operand stack `Value stack[STACK_MAX]` and `Value* stackTOP`
  - Call frames `CallFrame frames[FRAMES_MAX]` with `closure`, `ip`, and `slots`
  - Global variables table `vm.globals`
  - String intern table `vm.strings` and cached `init` string
  - Open upvalues list `vm.openUpValues`
  - GC bookkeeping: `bytesAllocated`, `nextGC`, `objects`, gray stack

- Calls:
  - `call(ObjClosure*, int)` pushes a new frame
  - `callValue(Value callee, int)` dispatches to closure, class constructor (instance + optional `init`), native, or errors
  - `invoke`/`invokeFromClass` handle methods with receiver lookups and late binding; `bindMethod` produces `ObjBoundMethod`

- Interpreter loop `run()`:
  - Fetch-decode-execute using macros `READ_BYTE`, `READ_CONSTANT`, `READ_STRING`, `READ_SHORT`
  - Binary op macro guards numeric types and pushes results
  - Returns `INTERPRET_OK` when top-level frame finishes; handles returns, upvalue closing, and tail result propagation

- Natives:
  - `clock` returns seconds since process start: `NUMBER_VAL((double)clock() / CLOCKS_PER_SEC)`
  - Register more with `defineNative(name, fn)` in `initVM()`

- Error reporting:
  - `runtimeError` prints a stack trace using chunk line info and function names

---

## Strings and interning (`object.c`, `table.c`)

- Strings are hashed (FNV-1a) and interned in `vm.strings`; equality is pointer equality.
- `copyString` duplicates into heap and interns; `takeString` takes ownership of an existing char buffer and interns.
- `table.c` uses open addressing with linear probing and tombstones. Load factor threshold `TABLE_MAX_LOAD = 0.75` triggers resize via `adjustCapacity`.

---

## Garbage collection (`memory.c`)

- Strategy: non-moving, mark-sweep collector.
- Allocation funnel: `reallocate` bumps `vm.bytesAllocated` and triggers GC when growing past `vm.nextGC` (or always in `DEBUG_STRESS_GC`).
- Roots:
  - VM operand stack
  - Call frames (closures)
  - Open upvalues
  - Globals table and interned strings table
  - Compiler roots (functions being built)
  - Cached `vm.initString`
- Marking uses an explicit gray stack to avoid recursion. `blackenObject` traverses references per object type.
- Sweeping walks the `vm.objects` linked list, freeing unmarked objects and clearing marks on survivors. `tableRemoveWhite` removes unmarked interned strings.
- Next GC target: `vm.nextGC = vm.bytesAllocated * 2`.

---

## Debugging tools (`debug.c` and flags)

- Define `DEBUG_PRINT_CODE` to print chunks after compilation.
- Define `DEBUG_TRACE_EXECUTION` to trace VM execution showing the stack and current instruction.
- Define `DEBUG_LOG_GC` to trace GC mark/blacken/free events.
- Define `DEBUG_STRESS_GC` to collect on every allocation to surface GC edge cases.

---

## Extending the VM

- Add a native function:
  1. Implement `static Value myNative(int argCount, Value* args)` in `vm.c` (or a new module).
  2. Register it in `initVM()` with `defineNative("myNative", myNative)`.
  3. Call it from Lox: `print myNative(1, 2, 3);`

- Add an opcode:
  1. Add enum entry in `OpCode` (`chunk.h`).
  2. Emit it in the compiler where appropriate.
  3. Handle it in the `switch` inside `run()` (`vm.c`).
  4. Update `debug.c` for disassembly support.

- Add a new object type:
  1. Extend `ObjType` and create struct in `object.h`.
  2. Implement constructor and printing in `object.c`.
  3. Update GC `blackenObject` and `freeObject` cases in `memory.c`.

---

## Known limitations and notes

- Numeric type is `double`; there is no integer type.
- Equality on non-numbers/non-bools/non-nil defers to pointer equality (e.g., strings are interned so content equality implies pointer equality).
- The interpreter assumes little-endian host but encodes jump operands explicitly; bytecode format is not stable across versions.
- Error recovery is limited to statement synchronization in the compiler.

---

## License

This codebase is for educational purposes following the Crafting Interpreters book. Check the repository license if present. If you publish derivatives, attribute appropriately.
