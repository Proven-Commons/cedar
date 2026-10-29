#!/usr/bin/env python3
"""Test the CLI against the finite policy semantics, including policy permutations.

Every expected answer comes from `reference`, a parser written from the
command-line protocol in SPEC.md, and `model`, a direct walk of the
decision rule. Input is sent as bytes, so lines that are not UTF-8 reach
the executable unchanged.
"""
import itertools
import platform
import random
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = 20261027

# Unicode's White_Space property, as SPEC.md lists it.
WHITE_SPACE = set(range(0x09, 0x0E)) | {0x20, 0x85, 0xA0, 0x1680} | \
    set(range(0x2000, 0x200B)) | {0x2028, 0x2029, 0x202F, 0x205F, 0x3000}


def model(request, policies):
    # Interpret each rule directly; do not mirror the engine's two any calls.
    permitted = False
    for effect, *scopes in policies:
        if all(scope == '*' or scope == value for scope, value in zip(scopes, request)):
            if effect == 'forbid':
                return 'deny'
            permitted = True
    return 'allow' if permitted else 'deny'


def is_token(t):
    return t != '' and ';' not in t and not any(ord(c) in WHITE_SPACE for c in t)


def reference(line):
    """The answer SPEC.md gives for one line, as bytes without its line end."""
    try:
        text = line.decode('utf-8', 'strict')
    except UnicodeDecodeError:
        return 'error'
    head, *tail = text.split(';')
    request = head.split(' ')
    if len(request) != 3 or not all(map(is_token, request)):
        return 'error'
    policies = []
    for seg in tail:
        fields = seg.split(' ')
        if len(fields) != 4 or not all(map(is_token, fields)) or \
                fields[0] not in ('permit', 'forbid'):
            return 'error'
        policies.append(tuple(fields))
    return model(tuple(request), policies)


def wire(request, policies):
    return ';'.join([' '.join(request)] + [' '.join(p) for p in policies]).encode('utf-8')


# Byte strings a mutation may insert or put in place of a byte. None is LF,
# which would end the line.
INSERTS = [b' ', b';', b'*', b'\t', b'\r', b'\x0b', b'\x0c', b'\xc2\xa0', b'\xc2\x85',
           b'\xe2\x80\xa8', b'\xe3\x80\x80', b'\xff', b'\xc3', b'\xc0\xaf', b'\xed\xa0\x80',
           b'P', b'F', b'a', b'\x00']


def mutate(rng, line):
    bs = bytearray(line)
    for _ in range(rng.randrange(1, 4)):
        kind = rng.randrange(5)
        i = rng.randrange(len(bs) + 1)
        if kind == 0 and bs:  # delete a byte
            del bs[min(i, len(bs) - 1)]
        elif kind == 1:  # insert
            bs[i:i] = rng.choice(INSERTS)
        elif kind == 2 and bs:  # replace a byte
            j = min(i, len(bs) - 1)
            bs[j:j + 1] = rng.choice(INSERTS)
        elif kind == 3:  # change the case of the line's letters
            bs = bytearray(bytes(bs).swapcase()) if rng.random() < 0.5 else \
                bytearray(bytes(bs).replace(b'permit', b'Permit').replace(b'forbid', b'FORBID'))
        else:  # double or drop a space
            spaces = [k for k, b in enumerate(bs) if b == 0x20]
            if spaces:
                k = rng.choice(spaces)
                bs[k:k + 1] = b'  ' if rng.random() < 0.5 else b''
    return bytes(bs)


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
    exhaustive = len(cases)
    rng = random.Random(SEED)
    names = ['a', 'b', 'alice', 'read', 'document', 'ü', '資料', '*', '*a', 'a*', '**', '�']
    generated = []
    matched = 0
    for _ in range(5000):
        request = tuple(rng.choice(names) for _ in range(3))

        def scope(value):
            # Biased toward the request's own value, so that most lists match.
            x = rng.random()
            return '*' if x < 0.3 else value if x < 0.7 else rng.choice(names)
        policies = [tuple([rng.choice(['permit', 'forbid'])] + [scope(v) for v in request])
                    for _ in range(rng.randrange(9))]
        want = model(request, policies)
        matched += any(all(sc == '*' or sc == v for sc, v in zip(p[1:], request)) for p in policies)
        cases.append((wire(request, policies), want))
        generated.append(wire(request, policies))
        rng.shuffle(policies)
        cases.append((wire(request, policies), want))
        # Duplicating a satisfied or unsatisfied rule cannot change the result.
        if policies:
            cases.append((wire(request, policies + [policies[0]]), want))
    malformed = [s.encode('utf-8') for s in [
        '', 'a b', 'a b c d', 'a  b c', 'a b c;', 'a b c;allow * * *', 'a b c;permit * *',
        'a b c;permit * * * ', 'a\tb c d', 'a b c;permit * * *;', ' a b c;permit * * *',
        'a b c;PERMIT * * *', 'a b c;Forbid * * *', 'a\x0bb c;permit * * *',
        'alice\x0c read document;permit * * *', 'a b c d;permit * * *',
        'a b c\u0085;permit * * *', 'a b c;permit   * *', 'a b　 c;permit * * *']]
    # Lines that are not UTF-8: a lone 0xFF or 0xFE, a truncated sequence, an
    # overlong form, an encoded surrogate.
    malformed += [b'\xff read doc;permit \xfe read doc',
                  b'\xed\xa0\x80 read doc;permit \xc0\xaf read doc',
                  b'\xef\xbf\xbd read doc;permit \xff read doc',
                  b'\xff read doc;permit * read doc;forbid \xfe read doc',
                  b'a b c;permit \xc3 * *', b'a b \xc3;permit * * *', b'\xff b c',
                  b'a b c;permit * * \xc0\xaf', b'a b c;permit \xed\xa0\x80 * *']
    for s in malformed:
        assert reference(s) == 'error', s
    cases += [(s, 'error') for s in malformed]
    # A real U+FFFD is UTF-8, and matches only itself.
    cases.append(('� b c;permit � b c'.encode('utf-8'), 'allow'))
    def ending(i):
        return b'\r\n' if i % 7 == 0 else b'\n'
    mutations = 0
    for _ in range(6000):
        line = mutate(rng, rng.choice(generated))
        # The executable drops one CR before the LF that ends a line.
        seen = (line + ending(len(cases)))[:-1]
        cases.append((line, reference(seen[:-1] if seen.endswith(b'\r') else seen)))
        mutations += 1
    mutated_errors = sum(1 for s, want in cases[-mutations:] if want == 'error')
    data = b''.join(s + ending(i) for i, (s, _) in enumerate(cases))
    run = subprocess.run([str(ROOT / '.lake/build/bin/cedar-style')], input=data,
                         capture_output=True, timeout=120)
    actual = run.stdout.decode('utf-8').splitlines()
    failures = [(s, want, got) for (s, want), got in zip(cases, actual) if want != got]
    assert run.returncode == 0 and len(actual) == len(cases), (run.returncode, run.stderr, len(actual))
    assert not failures, failures[:10]
    eof = subprocess.run([str(ROOT / '.lake/build/bin/cedar-style')], input=b'a b c;permit * * *',
                         capture_output=True, timeout=10)
    assert eof.returncode == 0 and eof.stdout == b'allow\n', eof
    lean = subprocess.check_output(['lean', '--version'], text=True).strip()
    report = f'''# Test results

- Oracle: finite policy semantics in Python {platform.python_version()}, evaluated by a direct rule walk, behind a reference parser written from SPEC.md
- Lean: {lean}
- Seed: {SEED}
- Inputs: {len(cases) + 1}
- Exhaustive: {exhaustive} lines: 8 requests against empty policies, every single rule, and all ordered pairs of 16 rules
- Generated policy lists: 5000, scopes biased toward the request's values, with one shuffled copy each and duplicate-rule checks for nonempty lists; {matched} of 5000 have at least one matching policy
- Malformed requests: {len(malformed)}, among them Unicode whitespace inside tokens and lines that are not UTF-8
- Byte-level mutations of generated lines: {mutations}, of which {mutated_errors} are malformed by the reference parser
- Line endings: LF, CR LF, and a final request without LF
- Failures: 0

This run checks the executable against the independent Python rule interpreter.
It does not establish AWS Cedar compatibility. Run the comparator separately to check proofs.
'''
    (ROOT / 'tests/TEST-RESULTS.md').write_text(report)
    print(f'{len(cases) + 1} inputs, 0 failures')


if __name__ == '__main__':
    main()
