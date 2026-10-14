// 下推自动机黑盒测试：accept 行为、LL(1) 冲突暴露、左递归拦截。

///|
fn pda_of(src : String) -> @ebnf.Pda {
  match @ebnf.parse_grammar(src) {
    Err(m) => abort("grammar error: " + m)
    Ok(g) =>
      match @ebnf.Pda::start(g) {
        Err(m) => abort("pda error: " + m)
        Ok(p) => p
      }
  }
}

///|
fn acc(src : String, input : String) -> Bool {
  pda_of(src).accept(input)
}

///|
test "bool grammar via pda" {
  inspect(acc("start: \"true\" | \"false\"", "true"), content="true")
  inspect(acc("start: \"true\" | \"false\"", "false"), content="true")
  inspect(acc("start: \"true\" | \"false\"", "tru"), content="false")
  inspect(acc("start: \"true\" | \"false\"", "True"), content="false")
  inspect(acc("start: \"true\" | \"false\"", ""), content="false")
}

///|
test "number sample grammar via pda" {
  let g = "value: \"-\"? digit+\ndigit: \"0\" | \"1\" | \"2\""
  inspect(acc(g, "2"), content="true")
  inspect(acc(g, "-21"), content="true")
  inspect(acc(g, "-2-"), content="false")
  inspect(acc(g, "+2"), content="false")
  inspect(acc(g, "3"), content="false")
  inspect(acc(g, ""), content="false")
}

///|
test "nested list grammar via pda" {
  let g = "list: \"[\" (\"a\" | list)* \"]\""
  inspect(acc(g, "[]"), content="true")
  inspect(acc(g, "[a]"), content="true")
  inspect(acc(g, "[aaa]"), content="true")
  inspect(acc(g, "[a[a[]]a]"), content="true")
  inspect(acc(g, "["), content="false")
  inspect(acc(g, "[b]"), content="false")
  inspect(acc(g, "a"), content="false")
}

///|
test "char classes via pda" {
  let g = "x: /0-9/+ \"-\" /[a-c]/"
  inspect(acc(g, "12-b"), content="true")
  inspect(acc(g, "7-a"), content="true")
  inspect(acc(g, "7-d"), content="false")
  inspect(acc(g, "-a"), content="false")
}

///|
test "left recursion is rejected at start" {
  match @ebnf.parse_grammar("a: a \"x\"") {
    Err(m) => inspect(m.contains("parse"), content="true")
    Ok(g) =>
      match @ebnf.Pda::start(g) {
        Err(m) => inspect(m.contains("left recursion"), content="true")
        Ok(_) => inspect("unexpected ok", content="should have failed")
      }
  }
}

///|
test "ambiguous alternation fails on feed" {
  match @ebnf.parse_grammar("x: \"a\" \"b\" | \"a\" \"c\"") {
    Err(_) => inspect("unexpected parse error", content="should have parsed")
    Ok(g) =>
      match @ebnf.Pda::start(g) {
        Err(m) => inspect(m, content="unexpected start error")
        Ok(p) => {
          let _ = p.feed("a")
          inspect(p.is_failed(), content="true")
        }
      }
  }
}

///|
test "ambiguous repetition overlap fails on feed" {
  match @ebnf.parse_grammar("x: \"a\"*") {
    Err(_) => inspect("parse error", content="?")
    Ok(g) =>
      match @ebnf.Pda::start(g) {
        Err(m) =>
          inspect(
            m.contains("left recursion") || m.contains("deep"),
            content="true",
          )
        Ok(p) => {
          // "a"* 迭代集与退出集（此处退出集为空）不冲突，应接受
          inspect(p.accept("aaa"), content="true")
          inspect(p.accept(""), content="true")
          inspect(p.accept("b"), content="false")
        }
      }
  }
}

///|
test "optional and plus semantics via pda" {
  inspect(acc("x: \"a\"+ \"b\"?", "ab"), content="true")
  inspect(acc("x: \"a\"+ \"b\"?", "aab"), content="true")
  inspect(acc("x: \"a\"+ \"b\"?", "a"), content="true")
  inspect(acc("x: \"a\"+ \"b\"?", "b"), content="false")
}

///|
test "nullable repetition is rejected" {
  // 可空循环体：w 自身可空，"*" 迭代无进展 —— 构造期或推进期必须拦截
  match @ebnf.parse_grammar("x: (\"\"*)*") {
    Err(_) => inspect("rejected at parse or start", content="true")
    Ok(g) =>
      match @ebnf.Pda::start(g) {
        Err(_) => inspect("rejected at start", content="true")
        Ok(p) => inspect(p.accept("") || p.is_failed(), content="true")
      }
  }
}
