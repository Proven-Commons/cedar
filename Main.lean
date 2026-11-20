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

/-- Answer each line as its LF arrives.

    `Stream.read` is C `fread`, which returns only after it has every
    requested byte or it reaches EOF. A 64 KiB read therefore waits for
    a full buffer before the first line can be answered, and a caller
    that sends one request and keeps the pipe open hangs. One byte is
    enough: stdio still fills its own buffer underneath, and the line is
    answered at the LF. A final line with no line ending is answered at
    EOF, as SPEC.md requires. -/
def serve (stdin stdout : IO.FS.Stream) : IO Unit := do
  let mut pending := ByteArray.empty
  repeat
    let chunk ← stdin.read 1
    if chunk.isEmpty then
      if !pending.isEmpty then
        stdout.putStrLn (answer pending false)
        stdout.flush
      break
    else
      -- `read 1` yields one byte. Consume the whole chunk so a larger
      -- read cannot drop bytes that arrived together.
      let mut i := 0
      while i < chunk.size do
        let b := chunk[i]!
        i := i + 1
        if b == 10 then
          stdout.putStrLn (answer pending true)
          stdout.flush
          pending := ByteArray.empty
        else
          pending := pending.push b

def main : IO Unit := do
  serve (← IO.getStdin) (← IO.getStdout)
