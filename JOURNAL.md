nano JOURNAL.md# PHANTOM-16 Design Journal

A running log of design decisions, bugs, and lessons learned during
the development of the PHANTOM-16 processor.

---

## 2026-05-04 — Phase 0: Environment Setup

### What I worked on
- Read through PRD; locked in 8-week schedule (Phases 0–6) and confirmed
  Tang Nano 9K as the target board.
- Ordered Tang Nano 9K from Amazon.ca; arriving in ~1 week.
- Installed core toolchain on macOS:
  - Homebrew (Apple Silicon — needed manual `eval` to add to PATH after install)
  - Icarus Verilog 13.0 (simulator)
  - Surfer 0.7.0 (waveform viewer; replaced GTKWave — see bug below)


  - Python 3.13.7 (already present, will use for the assembler in Phase 6)
- Created public GitHub repo `PHANTOM-16` and cloned locally.
- Built out the project folder structure per PRD §6.1
  (rtl/{top,core,memory,io}, tb/{unit,integration}, assembler, programs,
  docs, sim, synth).
- Wrote a custom `.gitignore` for sim artifacts, GoWin build files,
  Python caches, and macOS metadata.
- Wrote `rtl/top/blinky.v` — a 25-bit counter driving an LED — as a
  toolchain sanity check.
- Wrote `tb/unit/tb_blinky.v` driving a 27 MHz clock and synchronous
  reset, dumping VCD to `sim/blinky.vcd`.
- Confirmed full simulation loop works: iverilog compiles, vvp runs,
  Surfer displays the counter incrementing on every rising clock edge.
- Wrote `Makefile` with `sim` / `wave` / `clean` targets so I never
  have to type the iverilog/vvp/gtkwave commands by hand again.

### Bugs / friction points

**Bug:** GTKWave from Homebrew failed with `Can't locate Switch.pm in @INC`.
**Root cause:** Homebrew's `gtkwave` is a Perl wrapper script that calls
`Switch.pm`, a Perl module Apple stopped shipping with macOS years ago.
Tried calling the .app bundle's binary directly — it segfaulted on
missing GdkPixbuf resources because the binary has hardcoded paths to
`/Users/OSXUser/...` (the build machine's home dir). Tried the bundle's
launcher scripts — both have buggy relative-path handling.
**Fix:** Abandoned GTKWave. Installed Surfer (modern Rust-based viewer)
via `brew install surfer`. Created a shim at `~/bin/gtkwave` that just
`exec surfer "$@"` so the Makefile keeps working without changes.
Added `~/bin` to PATH in `~/.zshrc`.
**Lesson:** Don't fight broken packaging. When the toolchain is the
problem, switch tools — Surfer is actually a better viewer anyway, and
the time saved goes into the actual project.

**Bug:** Surfer panicked with "failed to open input file!".
**Root cause:** I ran `gtkwave sim/blinky.vcd` from `~` instead of from
the project root. Surfer treats the path as relative to CWD and crashes
hard rather than printing a clean error.
**Fix:** `cd ~/PHANTOM-16` first.
**Lesson:** Always check `pwd` before running a tool that takes file
paths. Could file an issue with Surfer asking for a friendlier error.

### Phase 0 status
- [x] Toolchain installed (iverilog, surfer, python)
- [x] GitHub repo created with PRD folder structure
- [x] `.gitignore` and Makefile in place
- [x] Blinky simulating cleanly with VCD output
- [x] Surfer renders the waveform correctly
- [ ] GoWin EDA Suite + openFPGALoader (deferred until board arrives)
- [ ] Blinky flashed to Tang Nano 9K, LED toggling on real silicon
**Bug:** First version of Makefile had warnings about overriding the
`sim` target and dropped a "circular sim <- sim dependency" — the
recipe never ran.
**Root cause:** Two targets named `sim` — the simulation target
`sim:` and the directory target `$(SIM_DIR):` which expands to `sim:`
since SIM_DIR=sim. Same name, two recipes, plus `sim` listed itself
as a dependency.
**Fix:** Removed the separate directory target. Inlined `mkdir -p
$(SIM_DIR)` into the `sim:` recipe instead.
**Lesson:** When a Makefile variable shares a name with a target,
check for collisions. Order-only prerequisites (`sim: | $(SIM_DIR)`)
are the more idiomatic fix when you do want a separate dir target,
but inlining is simpler when the dir creation is trivial.
---

## 2026-05-20 — Phase 1: ISA Freeze

### Decision: ISA encoding frozen as of this date
Reviewed the full instruction set before implementation. No encoding
changes. Any future change must be logged here as an explicit decision.

Clarifications recorded during review:
- **6-bit immediate range:** I-Type imm6 is signed → range −32 to +31.
  ADDI/LW/SW offsets are ±31; branches reach ±31 instructions
  (imm6 << 1 = ±62 bytes). Forced by 16-bit width − 4-bit opcode −
  two 3-bit register fields. Larger constants use LUI+ADDI (the LI
  pseudo-instruction).
- **rs2 field reuse:** For SW and the branch instructions, bits [8:6]
  (labeled "rd" in the I-Type format) actually carry rs2. The control
  unit suppresses register-file write-enable for these opcodes, so no
  spurious write occurs.
- **HALT = 0x0000:** Special-cased in decode (checked as a full 16-bit
  pattern before normal opcode decode). Bonus: FPGA BRAM powers up to
  zero, so running the PC off the end of valid code halts cleanly
  instead of executing garbage.
- **NOP = 0xFFFF:** Uses opcode 1111, which is unallocated, so no
  conflict with real instructions.
- **Branch-in-ID critical path:** Branch comparator runs in parallel
  with register read in the ID stage. This is the likely critical path
  at 50 MHz. Fallback if timing fails in Phase 5: move branch
  resolution to EX (2-cycle penalty).

### ALU op encoding decision
The PRD defines the ALU interface (alu_op[3:0]) but not the encoding.
Chose the low 8 alu_op values to mirror the R-type funct field exactly:

| alu_op | Operation |
|--------|-----------|
| 0000   | ADD       |
| 0001   | SUB       |
| 0010   | AND       |
| 0011   | OR        |
| 0100   | XOR       |
| 0101   | SLL       |
| 0110   | SRL       |
| 0111   | SRA       |
| 1000   | LUI (b << 10) |

Benefit: the control unit can form alu_op = {1'b0, funct} for R-type
ops with no extra logic. LUI lives at 1000 so the ALU doesn't need to
change in Phase 2 when I-type immediates get wired in.
---

## 2026-05-20 — Phase 1: ALU built and verified

### What I worked on
- Wrote `rtl/core/alu.v` — pure combinational 16-bit ALU with one
  `always @(*)` case block, default branch for latch avoidance, zero
  flag wired off the result.
- Implemented all 9 operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA,
  LUI. SRA uses `$signed(a) >>> b[2:0]` to preserve sign bit on
  negative inputs.
- Wrote `tb/unit/tb_alu.v` with all 10 cases from PRD §7.1. Used a
  `check` task with pass/fail counter and a summary at the end.
- All 10 tests passed first try, including the two edge cases:
  ADD 0xFFFF + 1 wraps cleanly to 0x0000 with zero=1, and
  SRA of 0x8000 by 1 gives 0xC000 (sign bit preserved).

### Notes
- The Makefile globs `rtl/**/*.v` so every testbench currently pulls
  in `blinky.v` too. Harmless for now (unused module just elaborates
  and sits there) but will need to switch to per-testbench source
  lists once the core fills out in Phase 2.
- Used `===` instead of `==` in the test comparator so any x/z values
  fail the test loudly instead of being treated as "unknown match".

### Phase 1 status
- [x] ISA encoding frozen and documented
- [x] ALU implemented and verified (10/10 tests pass)
- [ ] Register file in `id_stage.v`
- [ ] Register file testbench `tb_register_file.v`
