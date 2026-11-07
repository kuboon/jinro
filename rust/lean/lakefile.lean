import Lake
open Lake DSL

-- Keep this commit in sync with the Aeneas release used in CI
-- (nightly-2026.11.07-c5eb4a2) and with `lean-toolchain`.
require aeneas from git
  "https://github.com/AeneasVerif/aeneas.git" @ "c5eb4a28cef65e0aa27743105308243e535a2a2b" / "backends/lean"

package jinro where

/-- `Jinro/Core.lean` is generated from `jinro-core` by Charon + Aeneas
    (see `.github/workflows/rust-aeneas.yml`); proofs live next to it. -/
@[default_target] lean_lib Jinro
