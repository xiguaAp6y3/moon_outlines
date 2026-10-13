///|
/// Thompson NFA：边标签为 ε 或字符区间类。
pub enum Label {
  Epsilon
  ClassLabel(Array[(Int, Int)], Bool)
}

///|
pub struct Edge {
  label : Label
  to : Int
}

///|
pub struct Nfa {
  edges : Array[Array[Edge]]
  accept : Array[Bool]
  mut start : Int
}

///|
fn Nfa::new() -> Nfa {
  Nfa::{ edges: [], accept: [], start: 0, }
}

///|
fn Nfa::new_state(self : Nfa) -> Int {
  self.edges.push([])
  self.accept.push(false)
  self.edges.length() - 1
}

///|
fn Nfa::epsilon(self : Nfa, from : Int, to : Int) -> Unit {
  self.edges[from].push(Edge::{ label: Epsilon, to, })
}

///|
/// Thompson 构造：把 AST 编译为 NFA 片段，返回 (入口状态, 出口状态)。
/// 出口状态的 accept 位在片段内为真；组合时由调用方清除中间出口。
fn Nfa::build(self : Nfa, r : Regex) -> (Int, Int) {
  match r {
    Empty => {
      let s = self.new_state()
      self.accept[s] = true
      (s, s)
    }
    Class(ranges, negated) => {
      let s = self.new_state()
      let a = self.new_state()
      self.accept[a] = true
      self.edges[s].push(Edge::{ label: ClassLabel(ranges, negated), to: a, })
      (s, a)
    }
    Concat(rs) => {
      let frags : Array[(Int, Int)] = []
      for i = 0; i < rs.length(); i = i + 1 {
        frags.push(self.build(rs[i]))
      }
      self.chain(frags)
    }
    Alternation(rs) => {
      let s = self.new_state()
      let a = self.new_state()
      self.accept[a] = true
      for i = 0; i < rs.length(); i = i + 1 {
        let (bs, ba) = self.build(rs[i])
        self.epsilon(s, bs)
        self.epsilon(ba, a)
        self.accept[ba] = false
      }
      (s, a)
    }
    Star(r) => self.star_fragment(self.build(r))
    Plus(r) => {
      let (s, a) = self.build(r)
      // 出口回环到入口，保持出口 accept
      self.epsilon(a, s)
      (s, a)
    }
    Opt(r) => self.opt_fragment(self.build(r))
    Repeat(r, mn, mx) => {
      // 种子空片段，保证 min=0 时也有入口
      let seed = self.new_state()
      self.accept[seed] = true
      let frags : Array[(Int, Int)] = []
      frags.push((seed, seed))
      for i = 0; i < mn; i = i + 1 {
        frags.push(self.build(r))
      }
      match mx {
        None => {
          // r{m,} = r{m} r*
          frags.push(self.star_fragment(self.build(r)))
          self.chain(frags)
        }
        Some(n) => {
          // r{m,n} = r{m} (opt r){n-m}
          for j = mn; j < n; j = j + 1 {
            frags.push(self.opt_fragment(self.build(r)))
          }
          self.chain(frags)
        }
      }
    }
  }
}

///|
/// 串联片段；中间出口的 accept 被清除
fn Nfa::chain(self : Nfa, frags : Array[(Int, Int)]) -> (Int, Int) {
  let mut first = -1
  let mut prev_end = -1
  for i = 0; i < frags.length(); i = i + 1 {
    let (s, a) = frags[i]
    if first < 0 {
      first = s
    } else {
      self.epsilon(prev_end, s)
      self.accept[prev_end] = false
    }
    prev_end = a
  }
  (first, prev_end)
}

///|
/// 片段的星闭包
fn Nfa::star_fragment(self : Nfa, frag : (Int, Int)) -> (Int, Int) {
  let (s0, a0) = frag
  let s = self.new_state()
  let a = self.new_state()
  self.accept[a] = true
  self.accept[a0] = false
  self.epsilon(s, a)
  self.epsilon(s, s0)
  self.epsilon(a0, s0)
  self.epsilon(a0, a)
  (s, a)
}

///|
/// 片段的可选包装
fn Nfa::opt_fragment(self : Nfa, frag : (Int, Int)) -> (Int, Int) {
  let (s0, a0) = frag
  let s = self.new_state()
  let a = self.new_state()
  self.accept[a] = true
  self.accept[a0] = false
  self.epsilon(s, a)
  self.epsilon(s, s0)
  self.epsilon(a0, a)
  (s, a)
}

///|
/// 就地扩展 ε-闭包：membership 为状态隶属向量。
fn Nfa::close_over_epsilon(self : Nfa, membership : Array[Bool]) -> Unit {
  let stack : Array[Int] = []
  for i = 0; i < membership.length(); i = i + 1 {
    if membership[i] {
      stack.push(i)
    }
  }
  while stack.length() > 0 {
    let s = stack.pop().unwrap()
    let edges = self.edges[s]
    for k = 0; k < edges.length(); k = k + 1 {
      let e = edges[k]
      match e.label {
        Epsilon =>
          if !membership[e.to] {
            membership[e.to] = true
            stack.push(e.to)
          }
        _ => ()
      }
    }
  }
}

///|
/// 匹配机：编译后的正则（全匹配语义，专为生成/约束场景设计）。
pub struct Machine {
  pattern : String
  nfa : Nfa
}

///|
/// 编译正则子集为匹配机。
pub fn compile(pattern : String) -> Result[Machine, String] {
  match parse(pattern) {
    Err(msg) => Err(msg)
    Ok(ast) => {
      let nfa = Nfa::new()
      let (start, _end) = nfa.build(ast)
      nfa.start = start
      Ok(Machine::{ pattern, nfa, })
    }
  }
}

///|
/// 判断输入是否**完整**匹配该正则（子串不视为匹配）。
pub fn Machine::accepts(self : Machine, input : String) -> Bool {
  let n = self.nfa.edges.length()
  let mut cur : Array[Bool] = []
  for i = 0; i < n; i = i + 1 {
    cur.push(false)
  }
  cur[self.nfa.start] = true
  self.nfa.close_over_epsilon(cur)
  let units = to_code_units(input)
  for i = 0; i < units.length(); i = i + 1 {
    let code = units[i].to_int()
    let nxt : Array[Bool] = []
    for j = 0; j < n; j = j + 1 {
      nxt.push(false)
    }
    let mut alive = false
    for s = 0; s < n; s = s + 1 {
      if cur[s] {
        let edges = self.nfa.edges[s]
        for k = 0; k < edges.length(); k = k + 1 {
          let e = edges[k]
          match e.label {
            Epsilon => ()
            ClassLabel(ranges, negated) =>
              if class_contains(ranges, negated, code) && !nxt[e.to] {
                nxt[e.to] = true
                alive = true
              }
          }
        }
      }
    }
    if !alive {
      return false
    }
    cur = nxt
    self.nfa.close_over_epsilon(cur)
  }
  for i = 0; i < n; i = i + 1 {
    if cur[i] && self.nfa.accept[i] {
      return true
    }
  }
  false
}

///|
/// 源模式串
pub fn Machine::pattern(self : Machine) -> String {
  self.pattern
}

///|
/// NFA 状态数（观测用）
pub fn Machine::state_count(self : Machine) -> Int {
  self.nfa.edges.length()
}
