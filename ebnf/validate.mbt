///|
/// 文法静态校验：重复规则名与未定义的非终结符引用。
/// 左递归检测留给下推自动机构造阶段（该阶段需要语义动作）。
pub fn validate(rules : Array[Rule]) -> Result[Unit, String] {
  // 重复规则名
  for i = 0; i < rules.length(); i = i + 1 {
    for j = i + 1; j < rules.length(); j = j + 1 {
      if rules[i].name == rules[j].name {
        return Err("duplicate rule: " + rules[i].name)
      }
    }
  }
  // 已定义名字集合
  let defined : Array[String] = []
  for i = 0; i < rules.length(); i = i + 1 {
    defined.push(rules[i].name)
  }
  for i = 0; i < rules.length(); i = i + 1 {
    match check_expr(rules[i].expr, defined) {
      Err(e) => return Err("in rule '" + rules[i].name + "': " + e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn check_expr(e : Expr, defined : Array[String]) -> Result[Unit, String] {
  match e {
    Terminal(_) => Ok(())
    Chars(_, _) => Ok(())
    Nonterminal(n) =>
      if contains_str(defined, n) {
        Ok(())
      } else {
        Err("undefined nonterminal: " + n)
      }
    Sequence(items) => check_all(items, defined)
    Alternation(items) => check_all(items, defined)
    Repetition(inner) => check_expr(inner, defined)
    Plus(inner) => check_expr(inner, defined)
    Optional(inner) => check_expr(inner, defined)
  }
}

///|
fn check_all(
  items : Array[Expr],
  defined : Array[String],
) -> Result[Unit, String] {
  for i = 0; i < items.length(); i = i + 1 {
    match check_expr(items[i], defined) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
fn contains_str(arr : Array[String], s : String) -> Bool {
  for i = 0; i < arr.length(); i = i + 1 {
    if arr[i] == s {
      return true
    }
  }
  false
}
