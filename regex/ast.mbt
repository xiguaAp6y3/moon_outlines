///|
/// 正则子集的抽象语法树。
///
/// 设计目标是配合自动机使用：`+`、`?`、`{m,n}` 保留为独立节点，
/// 由 Thompson 构造在自动机层组合（NFA 是图，天然支持片段复用），
/// 避免在 AST 层复制子树。
pub enum Regex {
  /// 空正则 ε，仅匹配空串
  Empty
  /// 字符区间集合；取补集标志（空集合取补 = 任意字符）
  Class(Array[(Int, Int)], Bool)
  /// 拼接：依次匹配 rs[0]、rs[1]、……
  Concat(Array[Regex])
  /// 分支：匹配任意一个分支
  Alternation(Array[Regex])
  /// 星号：重复零次或多次
  Star(Regex)
  /// 加号：重复一次或多次
  Plus(Regex)
  /// 问号：出现零次或一次
  Opt(Regex)
  /// 区间量词：最少 min 次；max 为 None 表示不设上限
  Repeat(Regex, Int, Int?)
}

///|
/// 判断码点是否落在区间集合内（或其补集内）。
fn class_contains(
  ranges : Array[(Int, Int)],
  negated : Bool,
  code : Int,
) -> Bool {
  let mut hit = false
  for i = 0; i < ranges.length(); i = i + 1 {
    let (lo, hi) = ranges[i]
    if code >= lo && code <= hi {
      hit = true
      break
    }
  }
  if negated {
    !hit
  } else {
    hit
  }
}

///|
/// 由单个字符构造字面量节点。
fn lit(c : Char) -> Regex {
  let ranges : Array[(Int, Int)] = []
  ranges.push((Char::to_int(c), Char::to_int(c)))
  Class(ranges, false)
}

///|
/// 数字区间 [0-9]。
fn digit_ranges() -> Array[(Int, Int)] {
  let v : Array[(Int, Int)] = []
  v.push((48, 57))
  v
}

///|
/// 单词字符区间 [0-9A-Za-z_]。
fn word_ranges() -> Array[(Int, Int)] {
  let v : Array[(Int, Int)] = []
  v.push((48, 57))
  v.push((65, 90))
  v.push((95, 95))
  v.push((97, 122))
  v
}

///|
/// 空白字符区间 [\t-\r ]。
fn space_ranges() -> Array[(Int, Int)] {
  let v : Array[(Int, Int)] = []
  v.push((9, 13))
  v.push((32, 32))
  v
}
