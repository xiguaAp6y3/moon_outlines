///|
/// 字符类原子解析：`/class-body/` 中的 class-body 部分。
///
/// 语法：可选前导 `^`（取反）；项为单字符或 `lo-hi` 区间；
/// 转义：`\\ \" \/ \- \n \t \r \uXXXX`，其余 `\x` 恒等。
/// `-` 在末尾或紧随区间后视为字面量。
pub fn parse_class_body(
  s : String,
) -> Result[(Array[(Int, Int)], Bool), String] {
  let units = to_units(s)
  let n = units.length()
  let mut i = 0
  let mut negated = false
  if i < n && units[i].to_int() == 94 {
    negated = true
    i = i + 1
  }
  let ranges : Array[(Int, Int)] = []
  if i < n && units[i].to_int() == 93 {
    // 首个 ']' 视为字面量成员
    ranges.push((93, 93))
    i = i + 1
  }
  while i < n {
    let lo = match class_char(units, i) {
      Err(e) => return Err(e)
      Ok(v) =>
        match v {
          ClassChar(ch, next) => {
            i = next
            ch
          }
        }
    }
    // 区间：'-' 后还有字符（且不是收尾的 ']'）才成立
    if i + 1 < n && units[i].to_int() == 45 && units[i + 1].to_int() != 93 {
      i = i + 1
      let hi = match class_char(units, i) {
        Err(e) => return Err(e)
        Ok(v) =>
          match v {
            ClassChar(ch, next) => {
              i = next
              ch
            }
          }
      }
      if hi < lo {
        return Err("invalid class range at offset " + i.to_string())
      }
      ranges.push((lo, hi))
    } else {
      ranges.push((lo, lo))
    }
  }
  if ranges.length() == 0 {
    return Err("empty character class")
  }
  Ok((ranges, negated))
}

///|
/// 类内单个字符（含转义）的解析结果：码点 + 消费长度
priv enum ClassChar {
  ClassChar(Int, Int)
}

///|
/// 读取 s[i] 处的一个类成员字符
fn class_char(units : Array[UInt16], i : Int) -> Result[ClassChar, String] {
  let n = units.length()
  let c = units[i].to_int()
  if c != 92 {
    return Ok(ClassChar(c, i + 1))
  }
  if i + 1 >= n {
    return Err("dangling escape in class")
  }
  let e = units[i + 1].to_int()
  if e == 117 {
    // \uXXXX
    if i + 5 >= n {
      return Err("incomplete \\u escape in class")
    }
    let mut v = 0
    for k = 0; k < 4; k = k + 1 {
      let h = units[i + 2 + k].to_int()
      let d = if h >= 48 && h <= 57 {
        h - 48
      } else if h >= 97 && h <= 102 {
        h - 87
      } else if h >= 65 && h <= 70 {
        h - 55
      } else {
        return Err("invalid hex digit in class escape")
      }
      v = v * 16 + d
    }
    // 已消费 \uXXXX，直接返回
    return Ok(ClassChar(v, i + 6))
  }
  let code = match e {
    110 => 10 // \n
    116 => 9 // \t
    114 => 13 // \r
    _ => e // \\ \" \/ \- 等恒等转义
  }
  Ok(ClassChar(code, i + 2))
}
