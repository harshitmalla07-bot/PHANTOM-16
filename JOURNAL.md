# PHANTOM-16 Design Journal

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
