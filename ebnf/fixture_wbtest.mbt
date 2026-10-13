// 白盒测试：样例文法的结构契约（后续下推自动机测试的夹具基础）。

///|
test "bool grammar sample shape" {
  let g = bool_grammar()
  inspect(g.rules.length(), content="1")
  inspect(g.start, content="start")
  match g.rules[0].expr {
    Alternation(alts) => inspect(alts.length(), content="2")
    _ => abort("expected alternation")
  }
}

///|
test "number grammar sample shape" {
  let g = number_grammar()
  inspect(g.rules.length(), content="2")
  match g.rules[0].expr {
    Sequence(items) => inspect(items.length(), content="2")
    _ => abort("expected sequence")
  }
}

///|
test "list grammar sample uses repetition and recursion" {
  let g = list_grammar()
  match g.rules[0].expr {
    Sequence(items) => {
      inspect(items.length(), content="3")
      match items[1] {
        Repetition(inner) =>
          match inner {
            Alternation(_) => inspect("ok", content="ok")
            _ => abort("expected alternation under repetition")
          }
        _ => abort("expected repetition")
      }
    }
    _ => abort("expected sequence")
  }
}
