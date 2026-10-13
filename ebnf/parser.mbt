///|
/// Lark 风格 EBNF 子集的递归下降解析器。
///
/// 文法（记号层）：
///   grammar      := (NEWLINE* rule)* NEWLINE* EOF     （至少一条规则）
///   rule         := NAME ':' alternatives (';' | NEWLINE | EOF)
///   alternatives := sequence ('|' sequence)*  —— 换行后紧跟 '|' 视为续行
///   sequence     := item*                     —— 项并置构成序列
///   item         := atom ('*' | '+' | '?')*
///   atom         := STRING | NAME | '(' alternatives ')' | '[' alternatives ']'
///                 | '/class-body/'   —— 字符类原子，匹配单个码元
///
/// 约定：第一条规则是入口规则（Grammar.start）。
priv struct Parser {
  toks : Array[(Tok, Int)]
  mut pos : Int
  mut error : String?
}

///|
/// 解析 EBNF 源码为 Grammar；词法/语法/校验错误统一返回 Err。
pub fn parse_grammar(src : String) -> Result[Grammar, String] {
  let toks = match lex(src) {
    Err(e) => return Err(e)
    Ok(t) => t
  }
  let p = Parser::{ toks, pos: 0, error: None, }
  p.grammar()
}

///|
/// 记录首个错误（后续错误不覆盖），位置取当前记号起点
fn Parser::fail(self : Parser, msg : String) -> Unit {
  if self.error is None {
    let pos = if self.pos < self.toks.length() {
      self.toks[self.pos].1
    } else {
      0
    }
    self.error = Some(msg + " at position " + pos.to_string())
  }
}

///|
/// 当前记号是否为指定种类
fn Parser::at(self : Parser, k : Tok) -> Bool {
  self.pos < self.toks.length() && self.toks[self.pos].0 == k
}

///|
/// 若当前记号匹配则消费
fn Parser::eat(self : Parser, k : Tok) -> Bool {
  if self.at(k) {
    self.pos = self.pos + 1
    true
  } else {
    false
  }
}

///|
/// 消费指定记号，否则记录错误
fn Parser::expect(self : Parser, k : Tok, what : String) -> Bool {
  if self.eat(k) {
    true
  } else {
    self.fail("expected " + what)
    false
  }
}

///|
fn Parser::grammar(self : Parser) -> Result[Grammar, String] {
  let rules : Array[Rule] = []
  while true {
    while self.eat(NewlineT) {

    }
    if self.at(EofT) {
      break
    }
    match self.rule() {
      None => return Err(self.error.unwrap_or("parse error"))
      Some(r) => rules.push(r)
    }
  }
  if rules.length() == 0 {
    return Err("empty grammar: expected at least one rule")
  }
  match validate(rules) {
    Err(e) => Err(e)
    Ok(_) => Ok(Grammar::{ rules, start: rules[0].name, })
  }
}

///|
fn Parser::rule(self : Parser) -> Rule? {
  if self.pos >= self.toks.length() {
    self.fail("expected rule name")
    return None
  }
  let name = match self.toks[self.pos].0 {
    NameTok(n) => {
      self.pos = self.pos + 1
      n
    }
    _ => {
      self.fail("expected rule name")
      return None
    }
  }
  if !self.expect(ColonT, "':' after rule name") {
    return None
  }
  let expr = match self.alternatives() {
    None => return None
    Some(e) => e
  }
  // 规则结束：';' / 换行 / EOF（多行续行已在 alternatives 内消化）
  if self.eat(SemiT) {
    ()
  } else if self.eat(NewlineT) {
    ()
  } else if !self.at(EofT) {
    self.fail("expected end of rule (';' or newline)")
    return None
  }
  Some(Rule::{ name, expr, })
}

///|
fn Parser::alternatives(self : Parser) -> Expr? {
  let items : Array[Expr] = []
  match self.sequence() {
    None => return None
    Some(x) => items.push(x)
  }
  while true {
    if self.eat(PipeT) {
      match self.sequence() {
        None => return None
        Some(x) => items.push(x)
      }
      continue
    }
    if self.at(NewlineT) {
      // 前瞻：跳过换行后若紧跟 '|'，则为当前规则的续行
      let save = self.pos
      while self.at(NewlineT) {
        self.pos = self.pos + 1
      }
      if self.at(PipeT) {
        continue
      }
      self.pos = save
      break
    }
    break
  }
  if items.length() == 1 {
    Some(items[0])
  } else {
    Some(Alternation(items))
  }
}

///|
/// 序列：项并置（juxtaposition），在分支、换行、分号、括号边界处停止
fn Parser::sequence(self : Parser) -> Expr? {
  let items : Array[Expr] = []
  while true {
    if self.at(PipeT) ||
      self.at(NewlineT) ||
      self.at(SemiT) ||
      self.at(EofT) ||
      self.at(RParenT) ||
      self.at(RBracketT) {
      break
    }
    match self.item() {
      None => return None
      Some(x) => items.push(x)
    }
  }
  if items.length() == 0 {
    self.fail("expected item")
    return None
  }
  if items.length() == 1 {
    Some(items[0])
  } else {
    Some(Sequence(items))
  }
}

///|
fn Parser::item(self : Parser) -> Expr? {
  let mut e = match self.atom() {
    None => return None
    Some(a) => a
  }
  while true {
    if self.eat(StarT) {
      e = Repetition(e)
    } else if self.eat(PlusT) {
      e = Plus(e)
    } else if self.eat(QmarkT) {
      e = Optional(e)
    } else {
      break
    }
  }
  Some(e)
}

///|
fn Parser::atom(self : Parser) -> Expr? {
  if self.pos >= self.toks.length() {
    self.fail("expected item")
    return None
  }
  let t = self.toks[self.pos].0
  match t {
    StrTok(s) => {
      self.pos = self.pos + 1
      Some(Terminal(s))
    }
    ClassPatTok(body) => {
      self.pos = self.pos + 1
      match parse_class_body(body) {
        Err(m) => {
          self.fail(m)
          None
        }
        Ok((ranges, neg)) => Some(Chars(ranges, neg))
      }
    }
    NameTok(n) => {
      self.pos = self.pos + 1
      Some(Nonterminal(n))
    }
    LParenT => {
      self.pos = self.pos + 1
      match self.alternatives() {
        None => None
        Some(e) => if self.expect(RParenT, "')'") { Some(e) } else { None }
      }
    }
    LBracketT => {
      self.pos = self.pos + 1
      match self.alternatives() {
        None => None
        Some(e) =>
          if self.expect(RBracketT, "']'") {
            Some(Optional(e))
          } else {
            None
          }
      }
    }
    _ => {
      self.fail("expected item (string, name, '(' or '[')")
      None
    }
  }
}
