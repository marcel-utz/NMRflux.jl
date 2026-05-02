# Rename Checklist: `NMRlab.jl` → `NMRflux.jl`

A working checklist of all changes needed to rename the package consistently.
Tick each item as we complete it.

## 1. Top-level rename

- [x] Rename directory `Dropbox/Source/NMRlab.jl` → `Dropbox/Source/NMRflux.jl`

## 2. Main module file

- [x] Rename `src/NMRlab.jl` → `src/NMRflux.jl`
- [x] Edit line 1: `module NMRlab` → `module NMRflux`

## 3. `Project.toml`

- [x] Line 1: `name = "NMRlab"` → `name = "NMRflux"`
- [x] ~~Line 2: generate a new UUID~~ — **decision: keep the existing UUID**
      `d25eb878-a83b-4e0c-a1bb-544741aeade2` (NMRflux is intended to fully replace NMRlab)

## 4. `Manifest.toml`

- [x] Updated `[[deps.NMRlab]]` block header → `[[deps.NMRflux]]` (UUID unchanged)
- [ ] Note: `project_hash` at top of `Manifest.toml` is now stale (because
      `Project.toml` `name` changed). Pkg will detect this on next operation
      and either warn or refresh it automatically. If it complains, run
      `Pkg.resolve()` or delete `Manifest.toml` and regenerate.

## 5. `src/SpinSim.jl`

- [x] Line 12: `using NMRlab` → `using NMRflux`
- [x] Line 391: `NMRlab.SpectData` → `NMRflux.SpectData`

## 6. `src/GISSMO.jl`

- [x] Line 15: `using NMRlab.SpinSim` → `using NMRflux.SpinSim`

## 7. `src/NMRProcessor.jl`

- [x] Line 185 (docstring): `NMRlab.conv()` → `NMRflux.conv()`

## 8. `test/runtests.jl`

- [x] Line 1: `using NMRlab` → `using NMRflux`
- [x] Lines 8, 11, 18, 19, 27, 28: `NMRlab.` → `NMRflux.`
- [x] Lines 15, 25 (testset names): `"NMRlab.jl ..."` → `"NMRflux.jl ..."`

## 9. `docs/make.jl`

- [x] Line 2: `using Documenter, NMRlab` → `using Documenter, NMRflux`
- [x] Line 4: `sitename="NMRlab.jl"` → `sitename="NMRflux.jl"`
- [x] Replaced fragile `push!(LOAD_PATH, "../src/")` with
      `Pkg.activate(joinpath(@__DIR__, ".."))` so the main package
      `Project.toml` (with all required deps) is used. Run with
      `julia docs/make.jl` from any directory.
- [x] Removed obsolete `docs/Project.toml` and `docs/Manifest.toml`
      (no longer used by the new `make.jl`).

## 10. `docs/deploy.jl`

- [x] Line 10: GitHub URL `marcel-utz/NMRlab.jl` → `marcel-utz/NMRflux.jl`

## 11. `docs/src/Reference.md`

- [x] Line 5: `Modules = [NMRlab, NMRlab.FileIO]` → `Modules = [NMRflux, NMRflux.FileIO]`

## 12. `docs/src/index.md`

- [x] Line 9: `` `NMRlab.jl` `` → `` `NMRflux.jl` ``
- [x] Line 14: `NMR.jl` → `NMRflux.jl`
- [x] Line 18: `` `NMR.jl` `` → `` `NMRflux.jl` ``
- [x] Line 32: `` `NMR.jl` `` → `` `NMRflux.jl` ``
- [x] Line 35: `` `NMRlab.jl` `` → `` `NMRflux.jl` ``
- [x] Line 36: `NMR.jl` → `NMRflux.jl`

## 13. `README.md`

- [x] Line 1: `# NMRlab` → `# NMRflux`
- [x] Line 3: badge URLs `marcel.utz/NMRlab.jl` → `marcel-utz/NMRflux.jl`
      (also fixes the dot/dash typo in the username)

## 14. Demo notebooks

Update code only; Marcel will re-run the notebooks at the end so cell outputs
become consistent.

- [x] `demo/demo.ipynb` — 15 occurrences replaced
- [x] `demo/bmatrix.ipynb` — 4 occurrences replaced
- [x] `demo/gissmodemo.ipynb` — 6 occurrences replaced
- [ ] **Marcel: re-run all three notebooks to refresh cell outputs**

## 15. Outside this repository (manual)

- [x] Rename the GitHub repository `NMRlab.jl` → `NMRflux.jl`
- [x] Update local Git remote:
      `git remote set-url origin git@github.com:marcel-utz/NMRflux.jl.git`
- [ ] Update any of your own projects in `Dropbox/Projects/...` that have
      `NMRlab` in `Project.toml` `[deps]` or `using NMRlab` in their code
- [ ] (Optional) If/when registering in the Julia General registry,
      register `NMRflux` as a new package with the new UUID

## Items NOT to change

- `examples/` Bruker data folders — no references
- `.github/workflows/CI.yml`, `CompatHelper.yml`, `TagBot.yml` — no hard-coded package name
- `LICENSE`, `.gitignore`, `spin_simulation.xml*` — no references

## 16. Coworker's documentation pull (post-rename merge)

After merging Manaz's docs branch, ten doc files contain `NMRlab` references
again (147 in total). These supersede the earlier edits to `docs/src/index.md`
and `docs/src/Reference.md`, and add eight new files. Plain
`NMRlab` → `NMRflux` substitution is correct everywhere.

- [x] `docs/src/DataLoading.md` — 24 occurrences replaced
- [x] `docs/src/DataProcessing.md` — 13 occurrences replaced
- [x] `docs/src/Manual.md` — 44 occurrences replaced
- [x] `docs/src/NMRflux-1.0.md` — 7 occurrences replaced
      (heading on line 1 now reads "Roadmap to NMRflux.jl 1.0")
- [x] `docs/src/QuickStart.md` — 26 occurrences replaced
- [x] `docs/src/RINSE.md` — 4 occurrences replaced
- [x] `docs/src/Reference.md` — 12 occurrences replaced (overwrites earlier rename)
- [x] `docs/src/SpectData.md` — 5 occurrences replaced
- [x] `docs/src/SpinDynamics.md` — 4 occurrences replaced
- [x] `docs/src/index.md` — 8 occurrences replaced (overwrites earlier rename)

### Other things to check after the pull

- [x] `docs/make.jl` — re-applied the `Pkg.activate(joinpath(@__DIR__, ".."))`
      fix. The fragile `push!(LOAD_PATH, "../src/")` is gone; the script now
      activates the main `Project.toml` (which has all NMRflux deps +
      Documenter), so `julia docs/make.jl` works from any directory.
- [x] `docs/src/NMRflux-1.0.md` — removed the SpecCleaner paragraph
      (the dangling link to `SpecCleaner.md` plus its surrounding
      bullet, since the file doesn't exist). Re-add later when
      `SpecCleaner.md` is written.
- [ ] After all the above, `pages = [...]` in `docs/make.jl` lists only
      `index.md`, `QuickStart.md`, `DataLoading.md`, `SpectData.md`,
      `DataProcessing.md`, `SpinDynamics.md`, `RINSE.md`, `NMRflux-1.0.md`,
      `Reference.md`. The file `Manual.md` is in `docs/src/` but is not
      referenced in `pages` — confirm whether it should be added or removed.

## Verification (after the changes)

- [x] `grep -ri "NMRlab" .` (excluding `.git/`, `examples/`, and `docs/build/`)
      returns no matches in source files
- [ ] `julia --project -e 'using Pkg; Pkg.resolve(); Pkg.test()'` passes
- [x] `julia docs/make.jl` builds without errors
