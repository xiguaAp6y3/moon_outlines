///|
/// 样例文法：start -> "true" | "false"。
/// 用途：文档示例 + 下推自动机（M3）与 JSON 内置文法（M3 后续）的测试夹具。
pub fn bool_grammar() -> Grammar {
  let alts : Array[Expr] = [Terminal("true"), Terminal("false")]
  Grammar::{
    rules: [Rule::{ name: "start", expr: Alternation(alts), }],
    start: "start",
  }
}

///|
/// 样例文法：value -> "-"? digit+，digit -> "0"|"1"|"2"。
/// 覆盖 Sequence / Optional / Plus / Nonterminal / Alternation 全部形态。
pub fn number_grammar() -> Grammar {
  let digits : Array[Expr] = [Terminal("0"), Terminal("1"), Terminal("2")]
  Grammar::{
    rules: [
      Rule::{
        name: "value",
        expr: Sequence([Optional(Terminal("-")), Plus(Nonterminal("digit"))]),
      },
      Rule::{ name: "digit", expr: Alternation(digits), },
    ],
    start: "value",
  }
}

///|
/// 样例文法：list -> "[" item* "]"，item -> "a" | list。
/// 覆盖 Repetition 与递归非终结符（嵌套列表原型）。
pub fn list_grammar() -> Grammar {
  let items : Array[Expr] = [Terminal("a"), Nonterminal("list")]
  Grammar::{
    rules: [
      Rule::{
        name: "list",
        expr: Sequence([
          Terminal("["),
          Repetition(Alternation(items)),
          Terminal("]"),
        ]),
      },
    ],
    start: "list",
  }
}
