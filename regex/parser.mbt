///|
/// 把字符串转为 UTF-16 码元数组（MoonBit 字符串的底层模型）。
/// 正则引擎在码元层面工作；ASCII 语法与 BMP 字符路径正确，
/// 代理对按两个码元处理（限制见 README）。
fn to_code_units(s : String) -> Array[UInt16] {
  let units : Array[UInt16] = []
  for u in s.code_units() {
    units.push(u)
  }
  units
}

///|
/// 递归下降解析器。
///
/// 文法（EBNF 描述）：
///   alternation := concat ('|' concat)*
///   concat      := repeat*
///   repeat      := atom ('*' | '+' | '?' | '{m}' | '{m,}' | '{m,n}')*
///   atom        := '(' alternation ')' | class | '.' | escape | literal
///   class       := '[' '^'? item+ ']'
///
/// 解析失败通过 Parser.error 携带消息，各函数以 Option 逐层返回 None。
priv struct Parser {
  units : Array[UInt16]
  mut pos : Int
  mut error : String?
}

///|
/// 字符类内单个条目的解析结果
priv enum ClassItem {
  Single(Int)
  Set(Array[(Int, Int)])
}

///|
/// 解析正则子集；失败返回错误信息。
fn parse(pattern : String) -> Result[Regex, String] {
  let p = Parser::{ units: to_code_units(pattern), pos: 0, error: None, }
  match p.parse_alternation() {
    None => Err(p.error.unwrap_or("parse error"))
    Some(r) =>
      if p.pos < p.units.length() {
        Err("unexpected trailing characters at position " + p.pos.to_string())
      } else {
        Ok(r)
      }
  }
}

///|
fn Parser::peek(self : Parser) -> Char? {
  if self.pos < self.units.length() {
    Some(self.units[self.pos].to_int().unsafe_to_char())
  } else {
    None
  }
}

///|
fn Parser::peek2(self : Parser) -> Char? {
  if self.pos + 1 < self.units.length() {
    Some(self.units[self.pos + 1].to_int().unsafe_to_char())
  } else {
    None
  }
}

///|
fn Parser::advance(self : Parser) -> Char? {
  if self.pos < self.units.length() {
    let c = self.units[self.pos].to_int().unsafe_to_char()
    self.pos = self.pos + 1
    Some(c)
  } else {
    self.fail("unexpected end of pattern")
    None
  }
}

///|
/// 记录首个错误（后续错误不覆盖）
fn Parser::fail(self : Parser, msg : String) -> Unit {
  if self.error is None {
    self.error = Some(msg + " at position " + self.pos.to_string())
  }
}

///|
/// 若当前字符是指定字符则消费它
fn Parser::eat(self : Parser, expected : Char) -> Bool {
  match self.peek() {
    Some(c) =>
      if c == expected {
        self.pos = self.pos + 1
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn Parser::parse_alternation(self : Parser) -> Regex? {
  let alts : Array[Regex] = []
  match self.parse_concat() {
    None => None
    Some(first) => {
      alts.push(first)
      while self.eat('|') {
        match self.parse_concat() {
          None => return None
          Some(next) => alts.push(next)
        }
      }
      if alts.length() == 1 {
        Some(first)
      } else {
        Some(Alternation(alts))
      }
    }
  }
}

///|
fn Parser::parse_concat(self : Parser) -> Regex? {
  let items : Array[Regex] = []
  let mut stop = false
  while !stop {
    match self.peek() {
      None => stop = true
      Some('|') => stop = true
      Some(')') => stop = true
      Some(_) =>
        match self.parse_repeat() {
          None => return None
          Some(r) => items.push(r)
        }
    }
  }
  if items.length() == 0 {
    Some(Empty)
  } else if items.length() == 1 {
    Some(items[0])
  } else {
    Some(Concat(items))
  }
}

///|
fn Parser::parse_repeat(self : Parser) -> Regex? {
  let mut r : Regex = match self.parse_atom() {
    None => return None
    Some(a) => a
  }
  let mut stop = false
  while !stop {
    match self.peek() {
      Some('*') => {
        self.pos = self.pos + 1
        r = Star(r)
      }
      Some('+') => {
        self.pos = self.pos + 1
        r = Plus(r)
      }
      Some('?') => {
        self.pos = self.pos + 1
        r = Opt(r)
      }
      Some('{') =>
        match self.parse_repeat_spec() {
          None => return None
          Some((mn, mx)) => r = Repeat(r, mn, mx)
        }
      _ => stop = true
    }
  }
  Some(r)
}

///|
/// 解析 '{m}' / '{m,}' / '{m,n}'（调用时当前字符必须是 '{'）
fn Parser::parse_repeat_spec(self : Parser) -> (Int, Int?)? {
  self.pos = self.pos + 1 // 消费 '{'
  let mn = match self.parse_int() {
    None => return None
    Some(v) => v
  }
  if self.eat('}') {
    Some((mn, Some(mn)))
  } else if self.eat(',') {
    if self.eat('}') {
      Some((mn, None))
    } else {
      match self.parse_int() {
        None => None
        Some(mx) =>
          if self.eat('}') {
            if mx < mn {
              self.fail("invalid repeat range")
              None
            } else {
              Some((mn, Some(mx)))
            }
          } else {
            self.fail("expected '}'")
            None
          }
      }
    }
  } else {
    self.fail("expected '}' or ','")
    None
  }
}

///|
fn Parser::parse_int(self : Parser) -> Int? {
  let start = self.pos
  while self.pos < self.units.length() {
    let code = self.units[self.pos].to_int()
    if code >= 48 && code <= 57 {
      self.pos = self.pos + 1
    } else {
      break
    }
  }
  if self.pos == start {
    self.fail("expected a number")
    None
  } else {
    Some(parse_digits(self.units, start, self.pos))
  }
}

///|
fn parse_digits(units : Array[UInt16], from : Int, until : Int) -> Int {
  let mut v = 0
  for i = from; i < until; i = i + 1 {
    v = v * 10 + (units[i].to_int() - 48)
  }
  v
}

///|
fn Parser::parse_atom(self : Parser) -> Regex? {
  match self.advance() {
    None => None
    Some('(') => {
      let inner = match self.parse_alternation() {
        None => return None
        Some(x) => x
      }
      if self.eat(')') {
        Some(inner)
      } else {
        self.fail("expected ')'")
        None
      }
    }
    Some('[') => self.parse_class()
    Some('.') => {
      let v : Array[(Int, Int)] = []
      Some(Class(v, true))
    }
    Some('\\') => self.parse_escape()
    Some(')') => {
      self.fail("unbalanced ')'")
      None
    }
    Some('|') => {
      self.fail("unbalanced '|'")
      None
    }
    Some('*') => {
      self.fail("nothing to repeat")
      None
    }
    Some('+') => {
      self.fail("nothing to repeat")
      None
    }
    Some('?') => {
      self.fail("nothing to repeat")
      None
    }
    Some(c) => Some(lit(c))
  }
}

///|
/// 解析类外转义：\d \D \w \W \s \S \n \t \r 及字面转义（调用时 '\' 已消费）
fn Parser::parse_escape(self : Parser) -> Regex? {
  match self.advance() {
    None => None
    Some('d') => Some(Class(digit_ranges(), false))
    Some('D') => Some(Class(digit_ranges(), true))
    Some('w') => Some(Class(word_ranges(), false))
    Some('W') => Some(Class(word_ranges(), true))
    Some('s') => Some(Class(space_ranges(), false))
    Some('S') => Some(Class(space_ranges(), true))
    Some('n') => Some(lit('\n'))
    Some('t') => Some(lit('\t'))
    Some('r') => Some(lit('\r'))
    Some(c) => Some(lit(c))
  }
}

///|
/// 解析字符类（调用时 '[' 已消费）
fn Parser::parse_class(self : Parser) -> Regex? {
  let negated = self.eat('^')
  let ranges : Array[(Int, Int)] = []
  let mut stop = false
  while !stop {
    match self.peek() {
      None => {
        self.fail("unterminated character class")
        return None
      }
      Some(']') => {
        self.pos = self.pos + 1
        stop = true
      }
      Some(_) => ()
    }
    if stop {
      break
    }
    match self.class_item() {
      None => return None
      Some(Single(lo)) => {
        // a-b 范围语法：'-' 后面不是 ']' 或结尾才视为范围
        let is_range = match (self.peek(), self.peek2()) {
          (Some('-'), Some(']')) => false
          (Some('-'), Some(_)) => true
          _ => false
        }
        if is_range {
          self.pos = self.pos + 1 // 消费 '-'
          match self.advance() {
            None => return None
            Some(hi_c) => {
              let hi = Char::to_int(hi_c)
              if hi < lo {
                self.fail("invalid character range")
                return None
              }
              ranges.push((lo, hi))
            }
          }
        } else {
          ranges.push((lo, lo))
        }
      }
      Some(Set(rs)) =>
        for i = 0; i < rs.length(); i = i + 1 {
          ranges.push(rs[i])
        }
    }
  }
  Some(Class(ranges, negated))
}

///|
/// 字符类内条目（调用前 '['、'^' 已处理）
fn Parser::class_item(self : Parser) -> ClassItem? {
  match self.advance() {
    None => None
    Some('\\') =>
      match self.advance() {
        None => None
        Some('d') => Some(Set(digit_ranges()))
        Some('w') => Some(Set(word_ranges()))
        Some('s') => Some(Set(space_ranges()))
        Some('n') => Some(Single(10))
        Some('t') => Some(Single(9))
        Some('r') => Some(Single(13))
        Some(c) => Some(Single(Char::to_int(c)))
      }
    Some(c) => Some(Single(Char::to_int(c)))
  }
}
