///|
/// EBNF 文法的抽象语法树（Lark 风格子集）。
///
/// M3 完整管线：EBNF 源码 -> Grammar -> 下推自动机（生成语义：
/// 按推导状态给出合法"词组"集合），JSON 值文法（RFC 8259）作为内置文法。
/// 本文件先固定类型设计，解析与构造随后提交。
///
/// 设计约定：
/// - Terminal 承载字面终结符（如 "\"" "[" "0"）；字符区间复用正则包的
///   字符类表示，不再单独建模；
/// - Nonterminal 按名字引用规则，构造下推自动机时做可达性检查与左递归检测；
/// - Sequence/Alternation 为 N 元节点，量词（Repetition/Plus/Optional）
///   保留为独立节点，与 regex 包的 AST 风格一致。
pub struct Grammar {
  rules : Array[Rule]
  start : String
}

///|
/// 单条规则：非终结符 name 的产生式。
pub struct Rule {
  name : String
  expr : Expr
}

///|
/// 产生式表达式。
pub enum Expr {
  /// 字面终结符，如 "\"" 或 "true"
  Terminal(String)
  /// 非终结符引用，按名字解析到 Grammar.rules
  Nonterminal(String)
  /// 序列：依次匹配
  Sequence(Array[Expr])
  /// 分支：匹配任意一个
  Alternation(Array[Expr])
  /// 星号重复（零次及以上）
  Repetition(Expr)
  /// 加号重复（一次及以上）
  Plus(Expr)
  /// 可选
  Optional(Expr)
}
