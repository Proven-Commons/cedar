# Cedar-style policy decisions

A small Lean library decides whether a request is allowed by a list of permit and forbid policies. Scopes match an exact principal, action, or resource string, or every string. A matching forbid denies; without a matching permit the result also denies.

This is a Cedar-style engine, not AWS Cedar.

Status: in progress. The specification has not received independent approval, so this project is not verified.

## Run it

Needs Lean 4.35.0, pinned in `lean-toolchain`.

```sh
lake build
printf 'alice read document;permit alice read *\n' | .lake/build/bin/cedar-style
printf 'alice read document;permit * * *;forbid alice read document\n' | .lake/build/bin/cedar-style
```

The answers are `allow` and `deny`. The tool reads one request per line. Semicolons separate policies, a single space separates tokens, and `*` in a policy scope means wildcard. See [SPEC.md](SPEC.md) for the complete protocol and library semantics.

## What is proved

The challenge statements in `Cedar/Spec.lean` are proved in `Cedar/Proofs.lean`:

- `Cedar.Spec.authorize_iff`: the decision allows exactly when some permit matches and no forbid matches.
- `Cedar.Spec.forbid_denies`: a satisfied forbid denies.
- `Cedar.Spec.default_denies`: without a satisfied permit the decision denies.
- `Cedar.Spec.order_invariant`: permuting the policy list preserves the decision.
- `Cedar.Spec.members_invariant`: two policy lists with the same members give the same decision, so duplicates change nothing.

The independent relational predicates and shared types live in `Cedar/Spec/Defs.lean`. `lake comparator --paranoid` compares each proof with its challenge statement and checks its axioms and kernels. The intentional challenge placeholders are not production proofs.

## What is not proved

The command-line parser, line endings, and output are tested rather than proved. The CLI reads UTF-8 and answers `error` for a line that is not UTF-8. It supports nonempty tokens without Unicode whitespace or semicolons and cannot express literal `*` scopes; the library has no such string restriction.

There is no AWS Cedar parser or compatibility guarantee, entity hierarchy, expression language, schema, condition evaluation, policy validation, authentication, or integration with a deployed service. This library makes a decision from supplied strings and policies; it does not establish who supplied them.

AWS Cedar already proves all of these properties in [cedar-spec](https://github.com/cedar-policy/cedar-spec/blob/5a5f00b/cedar-lean/Cedar/Thm/Authorization.lean): `forbid_trumps_permit`, `default_deny`, `allowed_iff_explicitly_permitted_and_not_denied` and `order_and_dup_independent`. This independent educational slice claims no novel authorization result. [SPEC.md](SPEC.md) records the prior work and exact scope.

## What you must trust

The Lean kernel, compiler, runtime, standard library, and hardware must behave correctly. The Python model and its test generator can contain mistakes; differential tests supplement the proofs and do not prove the protocol correct. No external dependencies or foreign functions are used by the library.

## Re-check

```sh
lake build
lake comparator --paranoid
python3 tests/run_tests.py
```

The comparator's sandbox needs Linux namespaces and bubblewrap. On macOS, local review used `--inadvisably-no-sandbox`; that checks the same exported statements and kernels without process isolation. CI runs the sandboxed command. [Test results](tests/TEST-RESULTS.md) record exhaustive small policy lists, generated lists, permutations, duplicates, malformed requests, and seeded byte-level mutations checked against a reference parser written from SPEC.md.

Licensed under Apache 2.0; see [LICENSE](LICENSE).
