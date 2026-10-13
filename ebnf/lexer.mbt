///|
/// EBNF 词法器：把 Lark 风格子集源码切成记号流。
///
/// 记号：NAME / STRING / : | * + ? ( ) [ ] ; / 换行（连续折叠为一个）。
/// `//` 注释跳到行尾；空格与制表符跳过；换行作为规则终止符保留。
priv enum Tok {
  NameTok(String)
  StrTok(String)
  ColonT
  PipeT
  StarT
  PlusT
  QmarkT
  LParenT
  RParenT
  LBracketT
  RBracketT
  SemiT
  NewlineT
  EofT
} derive(Eq)

///|
/// 字符串转 UTF-16 码元数组（与 regex 包同款处理，包内自持一份）
fn to_units(s : String) -> Array[UInt16] {
  let units : Array[UInt16] = []
  for u in s.code_units() {
    units.push(u)
  }
  units
}

///|
/// 词法分析；失败返回带位置的错误信息。
fn lex(src : String) -> Result[Array[(Tok, Int)], String] {
  let units = to_units(src)
  let n = units.length()
  let out : Array[(Tok, Int)] = []
  let mut i = 0
  while i < n {
    let c = units[i].to_int()
    if c == 32 || c == 9 || c == 13 {
      i = i + 1
      continue
    }
    if c == 10 {
      out.push((NewlineT, i))
      while i < n && units[i].to_int() == 10 {
        i = i + 1
      }
      continue
    }
    if c == 47 && i + 1 < n && units[i + 1].to_int() == 47 {
      // `//` 注释：跳到行尾，换行留给下一轮作为规则终止符
      while i < n && units[i].to_int() != 10 {
        i = i + 1
      }
      continue
    }
    if c == 34 || c == 39 {
      // 字符串字面量，支持 \n \t \r \\ \" \' 转义
      let quote = c
      let start = i
      i = i + 1
      let sb = StringBuilder()
      let mut closed = false
      let mut bad : String? = None
      while i < n {
        let u = units[i].to_int()
        if u == quote {
          closed = true
          i = i + 1
          break
        }
        if u == 92 {
          if i + 1 >= n {
            bad = Some("dangling escape")
            break
          }
          let e = units[i + 1].to_int()
          let code = match e {
            110 => 10 // \n
            116 => 9 // \t
            114 => 13 // \r
            92 => 92 // \\
            34 => 34 // \"
            39 => 39 // \'
            _ => -1
          }
          if code < 0 {
            bad = Some("unknown escape\\" + char_to_str(e))
            break
          }
          sb.write_char(code.unsafe_to_char())
          i = i + 2
          continue
        }
        sb.write_char(u.unsafe_to_char())
        i = i + 1
      }
      match bad {
        Some(m) => return Err(m + " in string at position " + start.to_string())
        None => ()
      }
      if !closed {
        return Err("unterminated string at position " + start.to_string())
      }
      out.push((StrTok(sb.to_string()), start))
      continue
    }
    if c == 95 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
      // NAME：[A-Za-z_][A-Za-z0-9_]*
      let start = i
      let sb = StringBuilder()
      while i < n {
        let u = units[i].to_int()
        if u == 95 ||
          (u >= 65 && u <= 90) ||
          (u >= 97 && u <= 122) ||
          (u >= 48 && u <= 57) {
          sb.write_char(u.unsafe_to_char())
          i = i + 1
        } else {
          break
        }
      }
      out.push((NameTok(sb.to_string()), start))
      continue
    }
    let t : Tok = match c {
      58 => ColonT
      124 => PipeT
      42 => StarT
      43 => PlusT
      63 => QmarkT
      40 => LParenT
      41 => RParenT
      91 => LBracketT
      93 => RBracketT
      59 => SemiT
      _ =>
        return Err(
          "unexpected character '" +
          char_to_str(c) +
          "' at position " +
          i.to_string(),
        )
    }
    out.push((t, i))
    i = i + 1
  }
  out.push((EofT, n))
  Ok(out)
}

///|
/// 单码元转字符串（错误信息展示用）
fn char_to_str(code : Int) -> String {
  let sb = StringBuilder()
  sb.write_char(code.unsafe_to_char())
  sb.to_string()
}
