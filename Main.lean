/- One request per line: principal action resource, then zero or more
   policies separated by semicolons. Each policy is effect principal
   action resource. Tokens contain no whitespace or semicolon; `*` in a
   policy is a wildcard. Input is read as bytes: a line that is not
   UTF-8 is malformed and prints `error`, so different byte strings
   never become the same token. The CLI is tested, not covered by the
   proofs. -/
import Cedar

open Cedar

/-- Unicode's White_Space property (PropList.txt): the characters that
    cannot appear in a token. -/
def whiteSpace (c : Char) : Bool :=
  let n := c.toNat
  (0x09 ≤ n && n ≤ 0x0D) || n == 0x20 || n == 0x85 || n == 0xA0 || n == 0x1680 ||
    (0x2000 ≤ n && n ≤ 0x200A) || n == 0x2028 || n == 0x2029 || n == 0x202F ||
    n == 0x205F || n == 0x3000

def token (s : String) : Bool :=
  !s.isEmpty && s.toList.all (fun c => !whiteSpace c && c != ';')

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

/-- The answer to one line, given without its LF. A line that ended in
    LF loses one CR before it, so CR LF ends a line too. -/
def answer (line : ByteArray) (endedByLF : Bool) : String :=
  let line :=
    if endedByLF && line.size > 0 && line[line.size - 1]! == 13 then
      line.extract 0 (line.size - 1)
    else line
  match String.fromUTF8? line >>= request with
  | some true => "allow"
  | some false => "deny"
  | none => "error"

/-- Answers each complete line in `buf` from `start`, scanning from `i`.
    Gives where the unfinished last line starts. -/
partial def answerLines (stdout : IO.FS.Stream) (buf : ByteArray) (start i : Nat) :
    IO Nat := do
  if i ≥ buf.size then return start
  if buf[i]! == 10 then
    stdout.putStrLn (answer (buf.extract start i) true)
    stdout.flush
    answerLines stdout buf (i + 1) (i + 1)
  else
    answerLines stdout buf start (i + 1)

partial def serve (stdin stdout : IO.FS.Stream) (pending : ByteArray) : IO Unit := do
  let chunk ← stdin.read 65536
  if chunk.isEmpty then
    -- A final line needs no line ending.
    if !pending.isEmpty then
      stdout.putStrLn (answer pending false)
      stdout.flush
    return
  let buf := pending ++ chunk
  let start ← answerLines stdout buf 0 0
  serve stdin stdout (buf.extract start buf.size)

def main : IO Unit := do
  serve (← IO.getStdin) (← IO.getStdout) ByteArray.empty
