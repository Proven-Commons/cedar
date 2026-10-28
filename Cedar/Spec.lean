import Cedar

namespace Cedar.Spec

/-- The decision is exactly the relational permit/forbid rule. -/
theorem authorize_iff (ps : List Policy) (r : Request) :
    authorize ps r = true ↔ Allowed ps r := sorry

/-- Any satisfied forbid denies, even with satisfied permits. -/
theorem forbid_denies (ps : List Policy) (r : Request) (p : Policy)
    (hp : p ∈ ps) (he : p.effect = .forbid) (hm : Matches p r) :
    authorize ps r = false := sorry

/-- Without a satisfied permit the default is deny. -/
theorem default_denies (ps : List Policy) (r : Request)
    (h : ¬ ∃ p ∈ ps, p.effect = .permit ∧ Matches p r) :
    authorize ps r = false := sorry

/-- Reordering policies changes no decision. -/
theorem order_invariant (ps qs : List Policy) (r : Request) (h : ps.Perm qs) :
    authorize ps r = authorize qs r := sorry

end Cedar.Spec
