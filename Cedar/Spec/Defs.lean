import Std

namespace Cedar

inductive Effect where
  | permit | forbid
  deriving DecidableEq, Repr

structure Request where
  principal : String
  action : String
  resource : String
  deriving DecidableEq, Repr

/-- `none` matches every value; `some s` matches exactly `s`. -/
structure Policy where
  effect : Effect
  principal : Option String
  action : Option String
  resource : Option String
  deriving DecidableEq, Repr

namespace Spec

/-- The independent relational meaning of a policy scope. -/
def Matches (p : Policy) (r : Request) : Prop :=
  (p.principal = none ∨ p.principal = some r.principal) ∧
  (p.action = none ∨ p.action = some r.action) ∧
  (p.resource = none ∨ p.resource = some r.resource)

/-- A request is allowed exactly when a permit matches and no forbid matches. -/
def Allowed (ps : List Policy) (r : Request) : Prop :=
  (∃ p ∈ ps, p.effect = .permit ∧ Matches p r) ∧
  ¬ (∃ p ∈ ps, p.effect = .forbid ∧ Matches p r)

end Spec
end Cedar
