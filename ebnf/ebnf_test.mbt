// ebnf 包黑盒测试（占位阶段：桩行为的契约测试）。

///|
test "placeholder parser reports stable error" {
  match @ebnf.parse_grammar("start: \"a\"") {
    Ok(_) => abort("placeholder parser should not succeed")
    Err(msg) => inspect(msg.contains("not implemented"), content="true")
  }
}
