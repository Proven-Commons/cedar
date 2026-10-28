# Test results

- Oracle: finite policy semantics in Python 3.14.6, evaluated by a direct rule walk
- Lean: Lean (version 4.35.0, arm64-apple-darwin24.6.0, commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc, Release)
- Seed: 20261027
- Inputs: 16654
- Exhaustive: 8 requests against empty policies, every single rule, and all ordered pairs of 16 rules
- Generated policy lists: 5000, with one shuffled copy each and duplicate-rule checks for nonempty lists
- Malformed requests: 10
- Line endings: LF, CR LF, and a final request without LF
- Failures: 0

This run checks the executable against the independent Python rule interpreter.
It does not establish AWS Cedar compatibility. Run the comparator separately to check proofs.
