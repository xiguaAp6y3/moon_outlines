///|
/// 规范化渲染：把 Grammar 打回规范化 EBNF 文本。
///
/// 用途：调试输出、解析往返测试的对照基准（渲染对 AST 是单射的，
/// 两个 AST 相等当且仅当规范化文本相等）、后续 CLI 展示。
///
/// 规范形式：每行 `name: expr`；规则体顶层分支不加括号，
/// 其余复合操作数一律加括号，量词紧贴其原子。
pub fn render_grammar(g : Grammar) -> String {
  let sb = StringBuilder()
  for i = 0; i < g.rules.length(); i = i + 1 {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(g.rules[i].name)
    sb.write_string(": ")
    sb.write_string(expr_top(g.rules[i].expr))
  }
  sb.to_string()
}

///|
/// 规则体位置：顶层分支不加括号
fn expr_top(e : Expr) -> String {
  match e {
    Alternation(items) => join_map(items, " | ", alt_str)
    _ => alt_str(e)
  }
}

///|
/// 分支项位置：序列不加括号（序列优先级高于分支）
fn alt_str(e : Expr) -> String {
  match e {
    Sequence(items) => join_map(items, " ", op_str)
    _ => op_str(e)
  }
}

///|
/// 带量词的操作数
fn op_str(e : Expr) -> String {
  match e {
    Repetition(inner) => atom_str(inner) + "*"
    Plus(inner) => atom_str(inner) + "+"
    Optional(inner) => atom_str(inner) + "?"
    _ => atom_str(e)
  }
}

///|
/// 原子位置：复合结构一律加括号
fn atom_str(e : Expr) -> String {
  match e {
    Terminal(s) => quote_terminal(s)
    Nonterminal(n) => n
    Chars(ranges, neg) => render_class(ranges, neg)
    Sequence(items) => "(" + join_map(items, " ", op_str) + ")"
    Alternation(items) => "(" + join_map(items, " | ", op_str) + ")"
    Repetition(inner) => "(" + op_str(inner) + ")*"
    Plus(inner) => "(" + op_str(inner) + ")+"
    Optional(inner) => "(" + op_str(inner) + ")?"
  }
}

///|
/// 终结符字面量：双引号包裹，转义反斜杠、双引号与不可见字符
fn quote_terminal(s : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  let units = to_units(s)
  for i = 0; i < units.length(); i = i + 1 {
    let c = units[i].to_int()
    if c == 92 {
      sb.write_string("\\\\")
    } else if c == 34 {
      sb.write_string("\\\"")
    } else if c == 10 {
      sb.write_string("\\n")
    } else if c == 9 {
      sb.write_string("\\t")
    } else if c == 13 {
      sb.write_string("\\r")
    } else {
      sb.write_char(c.unsafe_to_char())
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// 以 sep 连接 map 后的字符串
fn join_map(items : Array[Expr], sep : String, f : (Expr) -> String) -> String {
  let sb = StringBuilder()
  for i = 0; i < items.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(f(items[i]))
  }
  sb.to_string()
}

///|
/// 字符类原子的规范化渲染：/…/，成员转义，区间 lo-hi
// 类成员转义的两字符字面量（用常量规避 MoonBit 字符串转义歧义）
const BS_SLASH : String = "\\/"

///|
const BS_N : String = "\\n"

///|
const BS_T : String = "\\t"

///|
const BS_R : String = "\\r"

///|
const BS_MINUS : String = "\\-"

///|
fn render_class(ranges : Array[(Int, Int)], negated : Bool) -> String {
  let sb = StringBuilder()
  sb.write_char('/')
  if negated {
    sb.write_char('^')
  }
  for i = 0; i < ranges.length(); i = i + 1 {
    let (lo, hi) = ranges[i]
    class_emit(sb, lo)
    if hi != lo {
      sb.write_char('-')
      class_emit(sb, hi)
    }
  }
  sb.write_char('/')
  sb.to_string()
}

///|
/// 类成员转义输出
fn class_emit(sb : StringBuilder, code : Int) -> Unit {
  if code == 92 {
    sb.write_string("\\\\")
  } else if code == 47 {
    sb.write_string(BS_SLASH)
  } else if code == 34 {
    sb.write_string("\\\"")
  } else if code == 10 {
    sb.write_string(BS_N)
  } else if code == 9 {
    sb.write_string(BS_T)
  } else if code == 13 {
    sb.write_string(BS_R)
  } else if code == 45 {
    sb.write_string(BS_MINUS)
  } else {
    sb.write_char(code.unsafe_to_char())
  }
}
