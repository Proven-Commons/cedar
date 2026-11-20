import Cedar.Spec.Defs

namespace Cedar

def scopeMatches (scope : Option String) (value : String) : Bool :=
  scope == none || scope == some value

def policyMatches (p : Policy) (r : Request) : Bool :=
  scopeMatches p.principal r.principal && scopeMatches p.action r.action &&
    scopeMatches p.resource r.resource

def satisfied (effect : Effect) (r : Request) (p : Policy) : Bool :=
  p.effect == effect && policyMatches p r

/-- Forbid overrides permit; without a matching permit the result is false. -/
def authorize (ps : List Policy) (r : Request) : Bool :=
  !(ps.any (satisfied .forbid r)) && ps.any (satisfied .permit r)

end Cedar
