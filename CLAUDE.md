# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

C64 hi-res bitmap graphics library written in **KickAssembler** (6502 assembly) for the Commodore 64. Provides macros for pixel plotting and Bresenham line drawing on the C64's 320×200 bitmap mode.

## Build

The project uses Gradle with the [c64lib Retro Assembler](https://github.com/c64lib/gradle-retro-assembler-plugin) plugin. There is no `build.gradle` in the repo root — it is generated/managed by the tooling.

```
./gradlew build          # assemble all .asm files → .prg output
./gradlew licenseAsm     # prepend MIT license headers
```

The assembler is **KickAssembler 5.25** (stored in `.ra/asms/ka/`). Dependencies (`c64lib/common`, `c64lib/chipset`) are resolved into `.ra/deps/` — this directory is gitignored.

Output files (`.prg`, `.sym`, `.dbg`) are gitignored.

## Architecture

- **`hires.asm`** — the library. Exposes `createHires(bitmapPtr, screenMemoryPtr)` macro that emits a jump-table-based object with methods: `init`, `clear`, `resetColours`, `setColours`, `plot`, `moveTo`, `lineTo`. Convenience macros (`plot()`, `setColours()`, `moveTo()`, `lineTo()`) wrap the JSR calls with register loading.
- **`demo.asm`** — example program that sets up VIC-II registers, instantiates the hires object, and draws pixels/lines.

### Key conventions

- The `createHires` macro produces a pseudo-object: a jump table at the start, followed by method bodies and lookup tables. Callers reference it as `hires.init`, `hires.plot`, etc.
- Bitmap and screen memory base addresses are macro parameters — the library is position-independent w.r.t. VIC-II bank layout.
- X coordinates are 16-bit (0–319): lo byte in A, hi byte in X. Y coordinates are 8-bit (0–199) in Y register.
- Lookup tables (`__bmYOffLo/Hi`, `__scrYOffLo/Hi`) are pre-computed at assembly time with `.fill` directives to avoid runtime multiplication.
- Self-modifying code is used for bitmap read/write addresses in `_plot`.

### C64 colour constants

Colour names like `BLACK`, `RED`, `LIGHT_GREY` etc. come from the `c64lib/chipset` dependency (VIC-II definitions). They are not defined in this repo.
