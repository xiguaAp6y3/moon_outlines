///|
/// 下推自动机：EBNF 文法的 LL(1) 生成语义机。
///
/// 设计：
/// - 状态 = 帧栈。帧有三种：序列推进（FSeq）、分支待决（FChoice）、
///   重复循环（FRep，min/max 计数）；非终结符在推进时内联展开为新的序列帧，
///   量词统一归一化为 FRep（Repetition 0..∞ / Plus 1..∞ / Optional 0..1）。
/// - nexts()：纯函数（在帧栈副本上计算），返回当前位置可接受的终结约束——
///   字面量（SLit）或字符集（SChars）。这是 M4 token 掩码的输入接口。
/// - feed(s)：消费一个终结（完整字面量或单字符），在真实栈上推进；
///   LL(1) 冲突（分支/迭代的 FIRST 交集非空）在此确定性暴露。
/// - 左递归与不可终止文法（可空重复）由深度护栏拦截。
pub struct Spec {
  lit : String
  charset : (Array[(Int, Int)], Bool)
  is_lit : Bool
}

///|
pub struct SeqF {
  items : Array[Expr]
  mut idx : Int
}

///|
pub struct RepF {
  inner : Expr
  min_times : Int
  max_times : Int?
  mut done : Int
}

///|
pub struct ChoiceF {
  options : Array[Expr]
  mut decided : Bool
}

///|
pub enum Frame {
  FSeq(SeqF)
  FRep(RepF)
  FChoice(ChoiceF)
}

///|
pub struct Pda {
  rules : Array[Rule]
  start_rule : String
  stack : Array[Frame]
  mut failed : String?
}

///|
/// FIRST 分析结果：终结约束集合 + 可空性
priv struct Anal {
  specs : Array[Spec]
  nul : Bool
}

///|
/// 名字 -> 规则体（线性查找；文法规模小，校验已保证名字唯一）
fn rule_expr(rules : Array[Rule], name : String) -> Expr? {
  for i = 0; i < rules.length(); i = i + 1 {
    if rules[i].name == name {
      return Some(rules[i].expr)
    }
  }
  None
}

///|
/// FIRST + Nullable 联合分析；深度超限（左递归/文法过深）返回 None
fn analyze(e : Expr, rules : Array[Rule], depth : Int) -> Anal? {
  if depth > 64 {
    return None
  }
  match e {
    Terminal(s) => {
      let specs : Array[Spec] = [
        Spec::{ lit: s, charset: ([], false), is_lit: true, },
      ]
      Some(Anal::{ specs, nul: false, })
    }
    Chars(ranges, neg) => {
      let specs : Array[Spec] = [
        Spec::{ lit: "", charset: (ranges, neg), is_lit: false, },
      ]
      Some(Anal::{ specs, nul: false, })
    }
    Nonterminal(n) =>
      match rule_expr(rules, n) {
        None =>
          // 校验已拦截未定义引用；防御性视为不可匹配
          Some(Anal::{ specs: [], nul: false, })
        Some(x) => analyze(x, rules, depth + 1)
      }
    Sequence(items) => {
      let specs : Array[Spec] = []
      let mut all_nul = true
      for i = 0; i < items.length(); i = i + 1 {
        match analyze(items[i], rules, depth + 1) {
          None => return None
          Some(a) => {
            append_specs(specs, a.specs)
            if !a.nul {
              all_nul = false
              break
            }
          }
        }
      }
      Some(Anal::{ specs, nul: all_nul, })
    }
    Alternation(items) => {
      let specs : Array[Spec] = []
      let mut any_nul = false
      for i = 0; i < items.length(); i = i + 1 {
        match analyze(items[i], rules, depth + 1) {
          None => return None
          Some(a) => {
            append_specs(specs, a.specs)
            if a.nul {
              any_nul = true
            }
          }
        }
      }
      Some(Anal::{ specs, nul: any_nul, })
    }
    Repetition(inner) =>
      match analyze(inner, rules, depth + 1) {
        None => None
        Some(a) => Some(Anal::{ specs: a.specs, nul: true, })
      }
    Optional(inner) =>
      match analyze(inner, rules, depth + 1) {
        None => None
        Some(a) => Some(Anal::{ specs: a.specs, nul: true, })
      }
    Plus(inner) => analyze(inner, rules, depth + 1)
  }
}

///|
/// 追加约束并去重
fn append_specs(dst : Array[Spec], src : Array[Spec]) -> Unit {
  for i = 0; i < src.length(); i = i + 1 {
    if !spec_in_arr(dst, src[i]) {
      dst.push(src[i])
    }
  }
}

///|
fn spec_in_arr(arr : Array[Spec], s : Spec) -> Bool {
  for i = 0; i < arr.length(); i = i + 1 {
    if spec_eq(arr[i], s) {
      return true
    }
  }
  false
}

///|
fn spec_eq(a : Spec, b : Spec) -> Bool {
  if a.is_lit != b.is_lit {
    return false
  }
  if a.is_lit {
    return a.lit == b.lit
  }
  let (ra, na) = a.charset
  let (rb, nb) = b.charset
  if na != nb || ra.length() != rb.length() {
    return false
  }
  for i = 0; i < ra.length(); i = i + 1 {
    if ra[i] != rb[i] {
      return false
    }
  }
  true
}

///|
/// 字符串 s 是否满足某约束
fn spec_accepts(s : Spec, str : String) -> Bool {
  if s.is_lit {
    return s.lit == str
  }
  let (ranges, neg) = s.charset
  let units = to_units(str)
  if units.length() != 1 {
    return false
  }
  chars_contains(ranges, neg, units[0].to_int())
}

///|
/// 码点是否落在字符集内
fn chars_contains(
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
/// 由文法构造下推自动机。要求文法通过校验；入口规则为 g.start。
pub fn Pda::start(g : Grammar) -> Result[Pda, String] {
  match validate(g.rules) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let expr = match rule_expr(g.rules, g.start) {
    None => return Err("start rule not found: " + g.start)
    Some(x) => x
  }
  if analyze(expr, g.rules, 0) is None {
    return Err(
      "left recursion or grammar too deep at start rule '" + g.start + "'",
    )
  }
  let root : Array[Expr] = [expr]
  let stack : Array[Frame] = [FSeq(SeqF::{ items: root, idx: 0, })]
  Ok(Pda::{ rules: g.rules, start_rule: g.start, stack, failed: None, })
}

///|
/// 当前可接受的终结约束（纯函数：在帧栈副本上计算）。
/// 返回空集表示机器已完成（无后续输入可消费）。
pub fn Pda::nexts(self : Pda) -> Array[Spec] {
  if self.failed is Some(_) {
    return []
  }
  let st : Array[Frame] = []
  for i = 0; i < self.stack.length(); i = i + 1 {
    st.push(copy_frame(self.stack[i]))
  }
  self.walk_next(st, 0)
}

///|
/// 在栈副本上推进并收集当前位置的约束集
fn Pda::walk_next(self : Pda, st : Array[Frame], depth : Int) -> Array[Spec] {
  if depth > 256 {
    return []
  }
  let empty : Array[Spec] = []
  while st.length() > 0 {
    let top = st[st.length() - 1]
    match top {
      FSeq(f) =>
        if f.idx >= f.items.length() {
          let _ = st.pop()
          continue
        } else {
          let e = f.items[f.idx]
          match e {
            Terminal(s) => {
              let specs : Array[Spec] = [
                Spec::{ lit: s, charset: ([], false), is_lit: true, },
              ]
              return specs
            }
            Chars(ranges, neg) => {
              let specs : Array[Spec] = [
                Spec::{ lit: "", charset: (ranges, neg), is_lit: false, },
              ]
              return specs
            }
            Nonterminal(n) =>
              match rule_expr(self.rules, n) {
                None => return empty
                Some(x) => {
                  // 标记本槽位已展开，子帧完成后包装帧随之完成
                  f.idx = f.idx + 1
                  let wrapped : Array[Expr] = [x]
                  st.push(FSeq(SeqF::{ items: wrapped, idx: 0, }))
                  continue
                }
              }
            Sequence(inner_items) => {
              // 序列拼接：父帧越过该槽位，子序列帧在其上展开
              f.idx = f.idx + 1
              st.push(FSeq(SeqF::{ items: inner_items, idx: 0, }))
              continue
            }
            Alternation(items) => {
              f.idx = f.idx + 1
              st.push(FChoice(ChoiceF::{ options: items, decided: false, }))
              continue
            }
            Repetition(inner) => {
              f.idx = f.idx + 1
              st.push(
                FRep(RepF::{ inner, min_times: 0, max_times: None, done: 0, }),
              )
              continue
            }
            Plus(inner) => {
              f.idx = f.idx + 1
              st.push(
                FRep(RepF::{ inner, min_times: 1, max_times: None, done: 0, }),
              )
              continue
            }
            Optional(inner) => {
              f.idx = f.idx + 1
              st.push(
                FRep(RepF::{ inner, min_times: 0, max_times: Some(1), done: 0, }),
              )
              continue
            }
          }
        }
      FChoice(cf) => {
        // 已提交的分支：选项帧已在上方完成，穿透到后继
        if cf.decided {
          let _ = st.pop()
          continue
        }
        let specs : Array[Spec] = []
        for i = 0; i < cf.options.length(); i = i + 1 {
          match analyze(cf.options[i], self.rules, 0) {
            None => return empty
            Some(a) => append_specs(specs, a.specs)
          }
        }
        return specs
      }
      FRep(f) => {
        if f.max_times is Some(m) {
          if f.done >= m {
            let _ = st.pop()
            continue
          }
        }
        let iter_set : Array[Spec] = match analyze(f.inner, self.rules, 0) {
          None => return empty
          Some(a) => a.specs
        }
        let exit_possible = f.done >= f.min_times ||
          (match analyze(f.inner, self.rules, 0) {
            None => false
            Some(a) => a.nul
          })
        if !exit_possible {
          return iter_set
        }
        // 退出集 = 弹出本帧后其余栈可接受的约束
        let _ = st.pop()
        let exit_set = self.walk_next(st, depth + 1)
        // LL(1)：迭代集与退出集不得相交（相交即在 feed 阶段判歧义）
        let specs : Array[Spec] = []
        append_specs(specs, iter_set)
        append_specs(specs, exit_set)
        return specs
      }
    }
  }
  empty
}

///|
/// 消费一个终结：完整字面量或单字符。
/// 失败（不匹配 / LL(1) 歧义 / 已完成）返回 Err 并使机器进入失败态。
pub fn Pda::feed(self : Pda, s : String) -> Result[Unit, String] {
  if self.failed is Some(m) {
    return Err(m)
  }
  let mut guard_count = 0
  while self.stack.length() > 0 {
    guard_count = guard_count + 1
    if guard_count > 4096 {
      return self.fail("non-terminating feed (nullable repetition?)")
    }
    let top = self.stack[self.stack.length() - 1]
    match top {
      FSeq(f) =>
        if f.idx >= f.items.length() {
          let _ = self.stack.pop()
          continue
        } else {
          let e = f.items[f.idx]
          match e {
            Terminal(t) =>
              if t == s {
                f.idx = f.idx + 1
                self.settle()
                return Ok(())
              } else {
                return self.fail("expected " + t + ", got " + s)
              }
            Chars(ranges, neg) => {
              let units = to_units(s)
              if units.length() == 1 &&
                chars_contains(ranges, neg, units[0].to_int()) {
                f.idx = f.idx + 1
                self.settle()
                return Ok(())
              }
              return self.fail("character not in class, got " + s)
            }
            Nonterminal(n) =>
              match rule_expr(self.rules, n) {
                None => return self.fail("undefined nonterminal: " + n)
                Some(x) => {
                  // 标记本槽位已展开，子帧完成后包装帧随之完成
                  f.idx = f.idx + 1
                  let wrapped : Array[Expr] = [x]
                  self.stack.push(FSeq(SeqF::{ items: wrapped, idx: 0, }))
                  continue
                }
              }
            Sequence(inner_items) => {
              f.idx = f.idx + 1
              self.stack.push(FSeq(SeqF::{ items: inner_items, idx: 0, }))
              continue
            }
            Alternation(items) => {
              f.idx = f.idx + 1
              self.stack.push(
                FChoice(ChoiceF::{ options: items, decided: false, }),
              )
              continue
            }
            Repetition(inner) => {
              f.idx = f.idx + 1
              self.stack.push(
                FRep(RepF::{ inner, min_times: 0, max_times: None, done: 0, }),
              )
              continue
            }
            Plus(inner) => {
              f.idx = f.idx + 1
              self.stack.push(
                FRep(RepF::{ inner, min_times: 1, max_times: None, done: 0, }),
              )
              continue
            }
            Optional(inner) => {
              f.idx = f.idx + 1
              self.stack.push(
                FRep(RepF::{ inner, min_times: 0, max_times: Some(1), done: 0, }),
              )
              continue
            }
          }
        }
      FChoice(cf) => {
        if cf.decided {
          // 提交后选项帧在上，settle 会先弹本帧；防御性穿透
          let _ = self.stack.pop()
          continue
        }
        // LL(1) 提交：恰好一个选项的 FIRST 含 s
        let matches : Array[Expr] = []
        for i = 0; i < cf.options.length(); i = i + 1 {
          match analyze(cf.options[i], self.rules, 0) {
            None => return self.fail("left recursion in alternation")
            Some(a) =>
              for k = 0; k < a.specs.length(); k = k + 1 {
                if spec_accepts(a.specs[k], s) {
                  matches.push(cf.options[i])
                  break
                }
              }
          }
        }
        if matches.length() == 0 {
          return self.fail("no alternative accepts " + s)
        }
        if matches.length() > 1 {
          return self.fail(
            "ambiguous grammar: multiple alternatives accept " + s,
          )
        }
        // 原地标记已提交，压入选定项帧
        cf.decided = true
        let chosen : Array[Expr] = [matches[0]]
        self.stack.push(FSeq(SeqF::{ items: chosen, idx: 0, }))
        continue
      }
      FRep(f) => {
        // 注意：迭代完成计数由 settle 负责，此处只做迭代/退出决策
        let at_max = match f.max_times {
          Some(m) => f.done >= m
          None => false
        }
        if at_max {
          let _ = self.stack.pop()
          continue
        }
        let iter_set : Array[Spec] = match analyze(f.inner, self.rules, 0) {
          None => return self.fail("left recursion in repetition")
          Some(a) => a.specs
        }
        let inner_nul = match analyze(f.inner, self.rules, 0) {
          None => false
          Some(a) => a.nul
        }
        let can_exit = f.done >= f.min_times || inner_nul
        // 退出集 = 去掉本帧后的栈可开始的约束（walk 副本上递归计算）
        let mut in_exit = false
        if can_exit {
          let st2 : Array[Frame] = []
          for i = 0; i < self.stack.length() - 1; i = i + 1 {
            st2.push(copy_frame(self.stack[i]))
          }
          let exit_specs = self.walk_next(st2, 0)
          for k = 0; k < exit_specs.length(); k = k + 1 {
            if spec_accepts(exit_specs[k], s) {
              in_exit = true
              break
            }
          }
        }
        let mut in_iter = false
        for k = 0; k < iter_set.length(); k = k + 1 {
          if spec_accepts(iter_set[k], s) {
            in_iter = true
            break
          }
        }
        if in_iter && in_exit {
          return self.fail(
            "ambiguous grammar: repetition iteration/exit overlap",
          )
        }
        if in_iter {
          // 再入迭代：FRep 保留在栈上，子迭代帧压在其上
          let inner_seq : Array[Expr] = [f.inner]
          self.stack.push(FSeq(SeqF::{ items: inner_seq, idx: 0, }))
          continue
        }
        if in_exit {
          // 退出：弹出重复帧，继续用剩余栈消费 s
          let _ = self.stack.pop()
          continue
        }
        return self.fail("unexpected " + s + " in repetition")
      }
    }
  }
  self.fail("machine already accepted; no more input expected")
}

///|
/// 记录失败并返回 Err
fn Pda::fail(self : Pda, msg : String) -> Result[Unit, String] {
  if self.failed is None {
    self.failed = Some(msg)
  }
  match self.failed {
    Some(m) => Err(m)
    None => Err(msg)
  }
}

///|
/// 机器是否已完成：无失败，且剩余帧全部可在零输入下完成
/// （已推进到底的序列帧、已满/已达下限/内部可空的重复帧、其余全可空）。
pub fn Pda::accepted(self : Pda) -> Bool {
  if self.failed is Some(_) {
    return false
  }
  // 排空模拟在副本上进行，绝不改动真实栈
  let st : Array[Frame] = []
  for i = 0; i < self.stack.length(); i = i + 1 {
    st.push(copy_frame(self.stack[i]))
  }
  while st.length() > 0 {
    let top = st[st.length() - 1]
    match top {
      FSeq(f) =>
        if f.idx >= f.items.length() {
          let _ = st.pop()
          continue
        } else {
          if nullable_rest(f.items, f.idx, self.rules, 0) {
            let _ = st.pop()
            continue
          }
          return false
        }
      FChoice(cf) => {
        if cf.decided {
          let _ = st.pop()
          continue
        }
        // 未决：存在可空选项即可零输入完成
        let mut any_nullable = false
        for i = 0; i < cf.options.length(); i = i + 1 {
          match analyze(cf.options[i], self.rules, 0) {
            None => ()
            Some(a) =>
              if a.nul {
                any_nullable = true
                break
              }
          }
        }
        if any_nullable {
          let _ = st.pop()
          continue
        }
        return false
      }
      FRep(f) => {
        let maxed = match f.max_times {
          Some(m) => f.done >= m
          None => false
        }
        let can_exit = maxed ||
          f.done >= f.min_times ||
          (match analyze(f.inner, self.rules, 0) {
            None => false
            Some(a) => a.nul
          })
        if can_exit {
          let _ = st.pop()
          continue
        }
        return false
      }
    }
  }
  true
}

///|
/// 消费成功后的整理：弹出已完成的序列帧；重复帧计一次完成迭代，
/// 达上限则弹出，否则停留等待下一次迭代/退出决策。
fn Pda::settle(self : Pda) -> Unit {
  while self.stack.length() > 0 {
    let top = self.stack[self.stack.length() - 1]
    match top {
      FSeq(f) =>
        if f.idx >= f.items.length() {
          let _ = self.stack.pop()
          continue
        } else {
          return
        }
      FChoice(_) => {
        // 分支已在提交时越过父槽位；选定项完成后此处随之出栈
        let _ = self.stack.pop()
        continue
      }
      FRep(f) => {
        f.done = f.done + 1
        let maxed = match f.max_times {
          Some(m) => f.done >= m
          None => false
        }
        if maxed {
          let _ = self.stack.pop()
          continue
        }
        return
      }
    }
  }
}

///|
/// items[from..] 是否全部可空（零输入可完成）
fn nullable_rest(
  items : Array[Expr],
  from : Int,
  rules : Array[Rule],
  depth : Int,
) -> Bool {
  if depth > 64 {
    return false
  }
  for i = from; i < items.length(); i = i + 1 {
    match analyze(items[i], rules, depth + 1) {
      None => return false
      Some(a) => if !a.nul { return false }
    }
  }
  true
}

///|
/// 是否已进入失败态
pub fn Pda::is_failed(self : Pda) -> Bool {
  self.failed is Some(_)
}

///|
/// 整串判定便捷入口：按 nexts() 的约束驱动输入（字面量取最长前缀匹配，
/// 字符集匹配单码元），全部消费完且栈空则接受。
pub fn Pda::accept(self : Pda, input : String) -> Bool {
  let units = to_units(input)
  let mut i = 0
  while i < units.length() {
    if self.failed is Some(_) {
      return false
    }
    let specs = self.nexts()
    if specs.length() == 0 {
      return false
    }
    // 最长字面量前缀匹配
    let mut best : String? = None
    for k = 0; k < specs.length(); k = k + 1 {
      let sp = specs[k]
      if sp.is_lit && starts_with_at(units, i, sp.lit) {
        match best {
          None => best = Some(sp.lit)
          Some(b) => if sp.lit.length() > b.length() { best = Some(sp.lit) }
        }
      }
    }
    match best {
      Some(lit) => {
        match self.feed(lit) {
          Err(_) => return false
          Ok(_) => ()
        }
        i = i + lit.length()
        continue
      }
      None => ()
    }
    // 字符集单码元
    let ch = units[i].to_int()
    let mut fed = false
    for k = 0; k < specs.length(); k = k + 1 {
      let sp = specs[k]
      if !sp.is_lit {
        let (ranges, neg) = sp.charset
        if chars_contains(ranges, neg, ch) {
          match self.feed(char_str(ch)) {
            Err(_) => return false
            Ok(_) => ()
          }
          i = i + 1
          fed = true
          break
        }
      }
    }
    if !fed {
      return false
    }
  }
  self.accepted()
}

///|
/// units[i..] 是否以 lit 开头
fn starts_with_at(units : Array[UInt16], i : Int, lit : String) -> Bool {
  let lu = to_units(lit)
  if i + lu.length() > units.length() {
    return false
  }
  for k = 0; k < lu.length(); k = k + 1 {
    if units[i + k] != lu[k] {
      return false
    }
  }
  true
}

///|
/// 单码元转字符串
fn char_str(code : Int) -> String {
  let sb = StringBuilder()
  sb.write_char(code.unsafe_to_char())
  sb.to_string()
}

///|
/// 帧副本（nexts 的纯性保证）
fn copy_frame(f : Frame) -> Frame {
  match f {
    FSeq(x) => FSeq(SeqF::{ items: x.items, idx: x.idx, })
    FRep(x) =>
      FRep(RepF::{
        inner: x.inner,
        min_times: x.min_times,
        max_times: x.max_times,
        done: x.done,
      })
    FChoice(x) => FChoice(ChoiceF::{ options: x.options, decided: x.decided, })
  }
}
