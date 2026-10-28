#!/usr/bin/env python3
"""Test the CLI against the finite policy semantics, including policy permutations."""
import itertools
import platform
import random
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = 20261027


def model(request, policies):
    # Interpret each rule directly; do not mirror the engine's two any calls.
    permitted = False
    for effect, *scopes in policies:
        if all(scope == '*' or scope == value for scope, value in zip(scopes, request)):
            if effect == 'forbid':
                return 'deny'
            permitted = True
    return 'allow' if permitted else 'deny'


def wire(request, policies):
    return ';'.join([' '.join(request)] + [' '.join(p) for p in policies])


def main():
    subprocess.run(['lake', 'build'], cwd=ROOT, check=True)
    cases = []
    rules = list(itertools.product(['permit', 'forbid'], ['*', 'a'], ['*', 'a'], ['*', 'a']))
    requests = list(itertools.product(['a', 'b'], repeat=3))
    for request in requests:
        cases.append((wire(request, []), 'deny'))
        for n in [1, 2]:
            for policies in itertools.product(rules, repeat=n):
                cases.append((wire(request, policies), model(request, policies)))
    rng = random.Random(SEED)
    names = ['a', 'b', 'alice', 'read', 'document', 'ü', '資料', '*']
    permutations = 0
    for _ in range(5000):
        request = tuple(rng.choice(names) for _ in range(3))
        policies = [tuple([rng.choice(['permit', 'forbid'])] +
                          [rng.choice(names) for _ in range(3)]) for _ in range(rng.randrange(9))]
        want = model(request, policies)
        cases.append((wire(request, policies), want))
        rng.shuffle(policies)
        cases.append((wire(request, policies), want))
        # Duplicating a satisfied or unsatisfied rule cannot change the result.
        if policies:
            cases.append((wire(request, policies + [policies[0]]), want))
        permutations += 1
    malformed = ['', 'a b', 'a b c d', 'a  b c', 'a b c;',
                 'a b c;allow * * *', 'a b c;permit * *', 'a b c;permit * * * ',
                 'a\tb c d', 'a b c;permit * * *;']
    cases += [(s, 'error') for s in malformed]
    data = ''.join(s + ('\r\n' if i % 7 == 0 else '\n') for i, (s, _) in enumerate(cases))
    run = subprocess.run([str(ROOT / '.lake/build/bin/cedar-style')], input=data,
                         text=True, capture_output=True, timeout=60)
    actual = run.stdout.splitlines()
    failures = [(s, want, got) for (s, want), got in zip(cases, actual) if want != got]
    assert run.returncode == 0 and len(actual) == len(cases), (run.returncode, run.stderr, len(actual))
    assert not failures, failures[:10]
    eof = subprocess.run([str(ROOT / '.lake/build/bin/cedar-style')], input='a b c;permit * * *',
                         text=True, capture_output=True, timeout=10)
    assert eof.returncode == 0 and eof.stdout == 'allow\n', eof
    lean = subprocess.check_output(['lean', '--version'], text=True).strip()
    report = f'''# Test results

- Oracle: finite policy semantics in Python {platform.python_version()}, evaluated by a direct rule walk
- Lean: {lean}
- Seed: {SEED}
- Inputs: {len(cases) + 1}
- Exhaustive: 8 requests against empty policies, every single rule, and all ordered pairs of 16 rules
- Generated policy lists: 5000, with one shuffled copy each and duplicate-rule checks for nonempty lists
- Malformed requests: {len(malformed)}
- Line endings: LF, CR LF, and a final request without LF
- Failures: 0

This run checks the executable against the independent Python rule interpreter.
It does not establish AWS Cedar compatibility. Run the comparator separately to check proofs.
'''
    (ROOT / 'tests/TEST-RESULTS.md').write_text(report)
    print(f'{len(cases) + 1} inputs, 0 failures')


if __name__ == '__main__':
    main()
