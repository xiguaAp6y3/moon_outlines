// ebnf 包黑盒测试：解析往返（源码 -> AST -> 规范化渲染）与错误契约。
// 渲染对 AST 是单射的，"parse(src) 的渲染 == 样例文法的渲染" 即结构等价。

///|
test "parse bool grammar round-trips to sample" {
  let src = "start: \"true\" | \"false\""
  match @ebnf.parse_grammar(src) {
    Ok(g) =>
      inspect(
        @ebnf.render_grammar(g) == @ebnf.render_grammar(@ebnf.bool_grammar()),
        content="true",
      )
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "parse number grammar round-trips to sample" {
  let src = "value: \"-\"? digit+\ndigit: \"0\" | \"1\" | \"2\""
  match @ebnf.parse_grammar(src) {
    Ok(g) =>
      inspect(
        @ebnf.render_grammar(g) == @ebnf.render_grammar(@ebnf.number_grammar()),
        content="true",
      )
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "parse list grammar round-trips to sample" {
  let src = "list: \"[\" (\"a\" | list)* \"]\""
  match @ebnf.parse_grammar(src) {
    Ok(g) =>
      inspect(
        @ebnf.render_grammar(g) == @ebnf.render_grammar(@ebnf.list_grammar()),
        content="true",
      )
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "first rule is the start rule" {
  match @ebnf.parse_grammar("a: \"x\"\nb: \"y\"") {
    Ok(g) => inspect(g.start, content="a")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "bracket is sugar for optional" {
  match @ebnf.parse_grammar("x: [ \"a\" ]") {
    Ok(g) => inspect(@ebnf.render_grammar(g), content="x: \"a\"?")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "semicolon terminates a rule" {
  match @ebnf.parse_grammar("a: \"x\"; b: \"y\";") {
    Ok(g) => inspect(@ebnf.render_grammar(g), content="a: \"x\"\nb: \"y\"")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "newline followed by pipe continues the rule" {
  let src = "start: \"a\"\n  | \"b\"\n  | \"c\""
  match @ebnf.parse_grammar(src) {
    Ok(g) =>
      inspect(@ebnf.render_grammar(g), content="start: \"a\" | \"b\" | \"c\"")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "comments are skipped" {
  let src = "// leading comment\nstart: \"a\" // trailing\n// done"
  match @ebnf.parse_grammar(src) {
    Ok(g) => inspect(@ebnf.render_grammar(g), content="start: \"a\"")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "quantifier stacking parses left-associatively" {
  match @ebnf.parse_grammar("x: \"a\"*+") {
    Ok(g) => inspect(@ebnf.render_grammar(g), content="x: (\"a\")*+")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "string escapes survive parsing" {
  match @ebnf.parse_grammar("x: \"a\\n\\t\\\"b\"") {
    Ok(g) => inspect(@ebnf.render_grammar(g), content="x: \"a\\n\\t\\\"b\"")
    Err(m) => inspect(m, content="should have parsed")
  }
}

///|
test "empty source is an error" {
  match @ebnf.parse_grammar("") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("empty grammar"), content="true")
  }
}

///|
test "missing colon is an error" {
  match @ebnf.parse_grammar("start \"a\"") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("':'"), content="true")
  }
}

///|
test "unterminated string is an error" {
  match @ebnf.parse_grammar("start: \"a") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("unterminated string"), content="true")
  }
}

///|
test "unknown escape is an error" {
  match @ebnf.parse_grammar("start: \"\\q\"") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("unknown escape"), content="true")
  }
}

///|
test "duplicate rule name is an error" {
  match @ebnf.parse_grammar("a: \"x\"\na: \"y\"") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("duplicate rule"), content="true")
  }
}

///|
test "undefined nonterminal is an error" {
  match @ebnf.parse_grammar("a: b") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("undefined nonterminal: b"), content="true")
  }
}

///|
test "unexpected character is an error with position" {
  match @ebnf.parse_grammar("start: $") {
    Ok(_) => inspect("unexpected ok", content="should have failed")
    Err(m) => inspect(m.contains("position 7"), content="true")
  }
}
