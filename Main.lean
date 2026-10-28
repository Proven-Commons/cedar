/- One request per line: principal action resource, then zero or more
   policies separated by semicolons. Each policy is effect principal
   action resource. Tokens contain no whitespace or semicolon; `*` in a
   policy is a wildcard. The CLI is tested, not covered by the proofs. -/
import Cedar

open Cedar

def token (s : String) : Bool :=
  !s.isEmpty && s.toList.all (fun c => !c.isWhitespace && c != ';')

def scope (s : String) : Option String := if s = "*" then none else some s

def parsePolicy (s : String) : Option Policy := do
  let [effect, principal, action, resource] := s.splitOn " " | none
  if !([effect, principal, action, resource].all token) then none else
  let effect ← match effect with
    | "permit" => some Effect.permit
    | "forbid" => some Effect.forbid
    | _ => none
  pure ⟨effect, scope principal, scope action, scope resource⟩

def request (s : String) : Option Bool := do
  let head :: tail := s.splitOn ";" | none
  let [principal, action, resource] := head.splitOn " " | none
  if !([principal, action, resource].all token) then none else
  let policies ← tail.mapM parsePolicy
  pure (authorize policies ⟨principal, action, resource⟩)

def chomp (s : String) : String :=
  let cs := s.toList
  if cs.getLast? = some '\n' then
    let cs := cs.dropLast
    String.ofList (if cs.getLast? = some '\r' then cs.dropLast else cs)
  else s

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    stdout.putStrLn (match request (chomp line) with
      | some true => "allow"
      | some false => "deny"
      | none => "error")
    stdout.flush
