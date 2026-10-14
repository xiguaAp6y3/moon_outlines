///|
/// 内置 JSON 文法（RFC 8259，LL(1) 形式）。
///
/// 用途：M3 的端到端验收载体——PDA 对任意输入串的接受判定与
/// moonbitlang/core 的 @json.parse 做差分对照；
/// M4 的 token 掩码引擎与 GBNF 导出以此为首个真实目标文法。
pub const JSON_GRAMMAR : String = "text: ws value ws\nws: / \t\n\r/*\nvalue: object | array | string | number | \"true\" | \"false\" | \"null\"\nobject: \"{\" ws objtail\nobjtail: \"}\" | members \"}\"\nmembers: member ws (\",\" ws member ws)*\nmember: string ws \":\" ws value\narray: \"[\" ws arrtail\narrtail: \"]\" | values \"]\"\nvalues: value ws (\",\" ws value ws)*\nstring: \"\\\"\" schars* \"\\\"\"\nschars: escape | /^\"\\\\/\nescape: \"\\\\\" escseq\nescseq: /\"\\/bfnrt/ | \"u\" hex hex hex hex\nhex: /0-9a-fA-F/\nnumber: int frac? exp?\nint: \"-\"? (\"0\" | /1-9/ /0-9/*)\nfrac: \".\" /0-9/+\nexp: /eE/ /+\\-/? /0-9/+"

///|
/// 解析内置 JSON 文法。
pub fn json_grammar() -> Result[Grammar, String] {
  parse_grammar(JSON_GRAMMAR)
}

///|
/// 构造 JSON 下推自动机（每次调用返回全新机器）。
pub fn json_pda() -> Result[Pda, String] {
  match json_grammar() {
    Err(e) => Err(e)
    Ok(g) => Pda::start(g)
  }
}
