// 黑盒测试：只通过 pub API（compile / accepts）验证行为。

///|
fn ok(pattern : String) -> @regex.Machine {
  match @regex.compile(pattern) {
    Ok(m) => m
    Err(msg) => abort("compile failed: " + msg)
  }
}

///|
/// yes 里的都必须接受，no 里的都必须拒绝
fn check(pattern : String, yes : Array[String], no : Array[String]) -> Bool {
  let m = ok(pattern)
  let mut good = true
  for i = 0; i < yes.length(); i = i + 1 {
    if !m.accepts(yes[i]) {
      good = false
    }
  }
  for i = 0; i < no.length(); i = i + 1 {
    if m.accepts(no[i]) {
      good = false
    }
  }
  good
}

///|
test "empty pattern matches only empty string" {
  inspect(check("", [""], ["a", " "]), content="true")
}

///|
test "literals and concatenation" {
  inspect(
    check("abc", ["abc"], ["", "ab", "abcd", "ABC", "abc "]),
    content="true",
  )
}

///|
test "full match semantics rejects substrings" {
  inspect(check("ab", ["ab"], ["a", "b", "abc", "xab", "abx"]), content="true")
}

///|
test "alternation" {
  inspect(check("yes|no", ["yes", "no"], ["maybe", "", "y"]), content="true")
}

///|
test "groups with alternation" {
  inspect(
    check("a(b|c)d", ["abd", "acd"], ["ad", "abcd", "ab", "aed"]),
    content="true",
  )
}

///|
test "nested groups" {
  inspect(
    check("(a|b)(c|d)", ["ac", "ad", "bc", "bd"], ["ab", "cd", "a"]),
    content="true",
  )
}

///|
test "star" {
  inspect(check("ab*", ["a", "ab", "abbbb"], ["", "b", "abba"]), content="true")
}

///|
test "plus" {
  inspect(check("ab+", ["ab", "abbbb"], ["a", "", "b"]), content="true")
}

///|
test "optional" {
  inspect(
    check("colou?r", ["color", "colour"], ["colouur", "colr"]),
    content="true",
  )
}

///|
test "repeat exact" {
  inspect(check("ab{3}", ["abbb"], ["ab", "abb", "abbbb"]), content="true")
}

///|
test "repeat open range" {
  inspect(check("ab{2,}", ["abb", "abbbbb"], ["ab", "b"]), content="true")
}

///|
test "repeat closed range" {
  inspect(
    check("ab{1,3}", ["ab", "abb", "abbb"], ["a", "abbbb", ""]),
    content="true",
  )
}

///|
test "repeat on group" {
  inspect(
    check("(ab){2,3}", ["abab", "ababab"], ["ab", "abababab"]),
    content="true",
  )
}

///|
test "dot matches any single char" {
  inspect(
    check("a.c", ["abc", "a c", "a@c"], ["ac", "abbc", "abc\n"]),
    content="true",
  )
}

///|
test "character class ranges" {
  inspect(
    check("[a-c][0-9]", ["a0", "b5", "c9"], ["d0", "aa", "a", "a00"]),
    content="true",
  )
}

///|
test "character class negation" {
  inspect(
    check("[^a-c]x", ["dx", "ex"], ["ax", "bx", "cx", "x"]),
    content="true",
  )
}

///|
test "digit escape" {
  inspect(
    check("\\d{3}-\\d{4}", ["555-1234"], ["5551-234", "555-123", "abc-1234"]),
    content="true",
  )
}

///|
test "word and space escapes" {
  inspect(check("\\w+", ["abc_123", "a"], ["a b", "", " "]), content="true")
  inspect(check("\\s", [" ", "\t", "\n"], ["a", ""]), content="true")
}

///|
test "negated escapes" {
  inspect(check("\\D", ["a", "-"], ["5", ""]), content="true")
}

///|
test "literal escapes" {
  inspect(check("a\\.b", ["a.b"], ["aab", "a\nb"]), content="true")
}

///|
test "star of group" {
  inspect(
    check("(ab)*", ["", "ab", "ababab"], ["aba", "ba", "aab"]),
    content="true",
  )
}

///|
test "string literal shape for json bool" {
  // 结构化输出场景的雏形：布尔值的 JSON 文法
  inspect(
    check("true|false", ["true", "false"], ["True", "tru", "1"]),
    content="true",
  )
}

///|
test "json number shape" {
  inspect(
    check("-?\\d+(\\.\\d+)?", ["0", "42", "-7", "3.14", "-0.5"], [
      "", "-", ".5", "1.", "+1",
    ]),
    content="true",
  )
}

///|
test "compile errors" {
  inspect(@regex.compile("(") is Err(_), content="true")
  inspect(@regex.compile(")") is Err(_), content="true")
  inspect(@regex.compile("[a") is Err(_), content="true")
  inspect(@regex.compile("a{3,1}") is Err(_), content="true")
  inspect(@regex.compile("*a") is Err(_), content="true")
  inspect(@regex.compile("a{") is Err(_), content="true")
  inspect(@regex.compile("a{,3}") is Err(_), content="true")
  inspect(@regex.compile("a)") is Err(_), content="true")
}

///|
test "error message carries position" {
  match @regex.compile("ab(") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(msg) => inspect(msg.contains("position"), content="true")
  }
}

///|
test "machine exposes pattern and state count" {
  let m = ok("a|b")
  inspect(m.pattern(), content="a|b")
  inspect(m.state_count() > 0, content="true")
}
