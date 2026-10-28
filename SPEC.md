# Specification: Cedar-style policy decisions

This slice evaluates policies over a request's principal, action, and resource strings. It is an independent Cedar-style engine, not AWS Cedar. It implements no Cedar parser, entities, schema, expression language, type checker, or production authorization service.

A policy has an effect, permit or forbid, and three scopes. Each scope is either a wildcard (`none`) or an exact string (`some s`). A policy matches a request exactly when each scope is a wildcard or equals the corresponding request field. String comparison is case sensitive, with no Unicode normalization.

The result is allow exactly when at least one matching permit exists and no matching forbid exists. Otherwise it is deny. An empty policy list denies. Duplicate policies and policy order do not change this rule.

`Cedar/Spec/Defs.lean` defines the request and policy types, the relational matching predicate `Cedar.Spec.Matches`, and the allowed predicate `Cedar.Spec.Allowed`. The executable implementation uses Boolean scope comparisons and two list searches. The relational specification uses quantified membership conditions.

## Properties

The challenge statements are in `Cedar/Spec.lean`; proofs of those same statements are in `Cedar/Proofs.lean`.

| Property | Theorem |
| --- | --- |
| The Boolean decision is exactly the relational rule above | `Cedar.Spec.authorize_iff` |
| Any matching forbid denies, including alongside matching permits | `Cedar.Spec.forbid_denies` |
| No matching permit means deny | `Cedar.Spec.default_denies` |
| A permutation of the policy list preserves the decision | `Cedar.Spec.order_invariant` |

The proofs quantify over every finite list and every request, including empty strings and all strings representable by Lean. The CLI below intentionally supports a smaller token syntax. Its parsing, line handling, and printing are tested, not proved.

## Command-line protocol

The executable reads one request per line and prints `allow`, `deny`, or `error`. The first segment contains three tokens: principal, action, resource. Subsequent segments, separated by semicolons, each contain four tokens: effect, principal scope, action scope, resource scope. Exactly one ASCII space separates tokens; tokens are nonempty and contain no whitespace or semicolon. Effects are `permit` and `forbid`.

A policy scope token `*` is a wildcard. Every other scope token is an exact string. The CLI cannot express a literal `*` scope, or empty or whitespace-containing fields, though the library can. A request's `*` token is a literal request string.

Examples:

```
alice read document;permit alice read *
alice read document;permit * * *;forbid alice read document
alice read document
```

These produce `allow`, `deny`, and `deny`. Malformed requests, including empty lines, print `error`. Lines may end in LF or CR LF; a final line needs no line ending. There is no persistent state between lines.

## Existing work

The AWS Cedar project already proves forbid precedence, default deny, and order independence in its [Lean authorization model](https://github.com/cedar-policy/cedar-spec/blob/main/cedar-lean/Cedar/Thm/Authorization.lean). Its [verification paper](https://arxiv.org/abs/2407.01688) describes the larger system. This slice repeats those elementary decision properties in a small independent model. It claims no new result and no compatibility with the AWS implementation. Its purpose is a bounded executable foundation for this repository's plan.
