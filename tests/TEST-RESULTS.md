# Test results

- Oracle: finite policy semantics in Python 3.13.17, evaluated by a direct rule walk, behind a reference parser written from SPEC.md
- Lean: Lean (version 4.35.0, x86_64-unknown-linux-gnu, commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc, Release)
- Seed: 20261027
- Inputs: 22670
- Exhaustive: 2184 lines: 8 requests against empty policies, every single rule, and all ordered pairs of 16 rules
- Generated policy lists: 5000, scopes biased toward the request's values, with one shuffled copy each and duplicate-rule checks for nonempty lists; 3714 of 5000 have at least one matching policy
- Malformed requests: 28, among them Unicode whitespace inside tokens and lines that are not UTF-8
- Byte-level mutations of generated lines: 6000, of which 5594 are malformed by the reference parser
- Line endings: LF, CR LF, and a final request without LF
- Failures: 0

This run checks the executable against the independent Python rule interpreter.
It does not establish AWS Cedar compatibility. Run the comparator separately to check proofs.
