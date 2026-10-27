# cedar

A Lean policy engine in the style of AWS Cedar. This is a Proven Commons project: it rebuilds a widely used rule in Lean and proves the new code follows its written specification. It is not AWS Cedar. It is a new engine that follows the same shape.

Status: not verified. No code has landed yet. Plan issue 1 holds the first slice, and it is unclaimed. The specification has not been approved by a reviewer, so do not call this verified.

## Wave 1

This is one of the three Wave 1 projects in the founding brief, months 4 to 9, one squad each. The other two are the SQLite file reader and the Redis protocol parser. Redis already has a repo.

## Claims to prove

- A satisfied forbid gives a deny.
- No satisfied permit gives a deny.
- Policy order does not change the decision.

## What is not in this project

- A full AWS Cedar implementation. This is a Cedar style engine, not a copy of AWS Cedar.
- Any claim about a deployed authorization service.

## Layout, when the first slice lands

The layout follows the Proven Commons template in the mission repo, under bar/template. Spec.lean holds the statements a reviewer approves. Proofs.lean holds the proofs under the same names. Main.lean holds the command line tool used by the tests. The bar check runs in CI on every change.
