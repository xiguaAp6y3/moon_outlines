///|
/// 解析 Lark 风格 EBNF 子集为 Grammar。
///
/// 计划文法（占位说明，实现提交时补全）：
///   grammar := rule+
///   rule    := NAME ':' alternatives (_NEWLINE | ';')
///   alternatives := item ('|' item)*
///   item    := atom ('*' | '+' | '?')*
///   atom    := STRING | NAME | '(' alternatives ')' | '[' alternatives ']'
///
/// 当前为 M3 占位桩：类型已冻结、管线未实现；调用会得到稳定的错误信息，
/// 后续提交将按"解析器 -> 语法图 -> 下推自动机 -> JSON 内置文法"四步填充。
pub fn parse_grammar(src : String) -> Result[Grammar, String] {
  ignore(src)
  Err("ebnf: parser not implemented yet (M3 placeholder)")
}
