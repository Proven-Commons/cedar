import Cedar

namespace Cedar.Spec

theorem policyMatches_iff (p : Policy) (r : Request) : policyMatches p r = true ↔ Matches p r := by
  simp [policyMatches, scopeMatches, Matches, and_assoc]

theorem satisfied_iff (e : Effect) (p : Policy) (r : Request) :
    satisfied e r p = true ↔ p.effect = e ∧ Matches p r := by
  simp [satisfied, policyMatches_iff]

theorem any_iff (e : Effect) (ps : List Policy) (r : Request) :
    ps.any (satisfied e r) = true ↔ ∃ p ∈ ps, p.effect = e ∧ Matches p r := by
  simp only [List.any_eq_true, satisfied_iff]

theorem authorize_iff (ps : List Policy) (r : Request) :
    authorize ps r = true ↔ Allowed ps r := by
  simp only [authorize, Bool.and_eq_true, Bool.not_eq_true']
  rw [← Bool.not_eq_true, any_iff, any_iff]
  unfold Allowed
  exact and_comm

theorem forbid_denies (ps : List Policy) (r : Request) (p : Policy)
    (hp : p ∈ ps) (he : p.effect = .forbid) (hm : Matches p r) :
    authorize ps r = false := by
  have hf : ps.any (satisfied .forbid r) = true := (any_iff _ _ _).mpr ⟨p, hp, he, hm⟩
  simp [authorize, hf]

theorem default_denies (ps : List Policy) (r : Request)
    (h : ¬ ∃ p ∈ ps, p.effect = .permit ∧ Matches p r) :
    authorize ps r = false := by
  have hp : ps.any (satisfied .permit r) = false := by
    cases hx : ps.any (satisfied .permit r)
    · rfl
    · exact False.elim (h ((any_iff _ _ _).mp hx))
  simp [authorize, hp]

theorem order_invariant (ps qs : List Policy) (r : Request) (h : ps.Perm qs) :
    authorize ps r = authorize qs r := by
  simp only [authorize, h.any_eq]

theorem members_invariant (ps qs : List Policy) (r : Request)
    (h : ∀ p, p ∈ ps ↔ p ∈ qs) :
    authorize ps r = authorize qs r := by
  have key : ∀ e, ps.any (satisfied e r) = qs.any (satisfied e r) := by
    intro e
    apply Bool.eq_iff_iff.mpr
    simp only [List.any_eq_true]
    exact ⟨fun ⟨p, hp, hs⟩ => ⟨p, (h p).mp hp, hs⟩, fun ⟨p, hp, hs⟩ => ⟨p, (h p).mpr hp, hs⟩⟩
  simp only [authorize, key]

end Cedar.Spec
