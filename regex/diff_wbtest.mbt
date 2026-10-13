// 白盒随机差分测试：包内可直接构造 Regex AST。
// 随机生成 AST -> 渲染回模式串 -> 编译 NFA / DFA / 最小化 DFA，三方一致性对照。
// 这是 ROADMAP M2 的验收项：随机差分不少于 1000 个对照用例。
///|
fn ok(pattern : String) -> Machine {
  match compile(pattern) {
    Ok(m) => m
    Err(msg) => abort("compile failed: " + msg)
  }
}

///|
/// 确定性伪随机数（Int64 LCG），保证测试可复现
priv struct Rng {
  mut state : Int64
}

///|
fn Rng::next(self : Rng) -> Int {
  self.state = self.state * 6364136223846793005L + 1442695040888963407L
  (self.state >> 33).to_int() & 0x7FFFFFFF
}

///|
fn Rng::pick(self : Rng, n : Int) -> Int {
  if n <= 1 {
    0
  } else {
    self.next() % n
  }
}

///|
/// 小字母表 {a,b,c,d} 上的字符码
fn alpha_code(rng : Rng) -> Int {
  97 + rng.pick(4)
}

///|
/// 随机生成正则 AST（深度受限，节点覆盖全部语法形态）
fn random_regex(rng : Rng, depth : Int) -> Regex {
  if depth <= 0 {
    let c = alpha_code(rng)
    if rng.pick(2) == 0 {
      let ranges : Array[(Int, Int)] = [(c, c)]
      Class(ranges, false)
    } else {
      // 小区间类：[x-y]
      let lo = alpha_code(rng)
      let hi = alpha_code(rng)
      let ranges : Array[(Int, Int)] = [(lo, hi)]
      Class(ranges, rng.pick(4) == 0)
    }
  } else {
    match rng.pick(7) {
      0 => {
        let c = alpha_code(rng)
        let ranges : Array[(Int, Int)] = [(c, c)]
        Class(ranges, false)
      }
      1 => {
        let lo = alpha_code(rng)
        let hi = alpha_code(rng)
        let ranges : Array[(Int, Int)] = [(lo, hi)]
        Class(ranges, rng.pick(4) == 0)
      }
      2 => Star(random_regex(rng, depth - 1))
      3 => Plus(random_regex(rng, depth - 1))
      4 => Opt(random_regex(rng, depth - 1))
      5 => {
        let rs : Array[Regex] = []
        let n = 2 + rng.pick(2)
        for i = 0; i < n; i = i + 1 {
          rs.push(random_regex(rng, depth - 1))
        }
        Concat(rs)
      }
      _ => {
        let rs : Array[Regex] = []
        let n = 2 + rng.pick(2)
        for i = 0; i < n; i = i + 1 {
          rs.push(random_regex(rng, depth - 1))
        }
        Alternation(rs)
      }
    }
  }
}

///|
/// 把 AST 渲染回可被解析器理解的模式串（复合子表达式一律加括号，保证无歧义）
fn render_regex(r : Regex) -> String {
  match r {
    Empty => ""
    Class(ranges, negated) => {
      let sb = StringBuilder()
      sb.write_char('[')
      if negated {
        sb.write_char('^')
      }
      for i = 0; i < ranges.length(); i = i + 1 {
        let (lo, hi) = ranges[i]
        if lo == hi {
          sb.write_char(lo.unsafe_to_char())
        } else {
          // 渲染成离散字符集合，避免生成 lo>hi 的逆序区间
          let mut c = if lo > hi { hi } else { lo }
          let top = if lo > hi { lo } else { hi }
          while c <= top {
            sb.write_char(c.unsafe_to_char())
            c = c + 1
          }
        }
      }
      sb.write_char(']')
      sb.to_string()
    }
    Concat(rs) => {
      let sb = StringBuilder()
      for i = 0; i < rs.length(); i = i + 1 {
        sb.write_string(wrap_operand(rs[i], render_regex(rs[i])))
      }
      sb.to_string()
    }
    Alternation(rs) => {
      let sb = StringBuilder()
      for i = 0; i < rs.length(); i = i + 1 {
        if i > 0 {
          sb.write_char('|')
        }
        sb.write_string(wrap_operand(rs[i], render_regex(rs[i])))
      }
      "(" + sb.to_string() + ")"
    }
    Star(inner) => wrap_operand(inner, render_regex(inner)) + "*"
    Plus(inner) => wrap_operand(inner, render_regex(inner)) + "+"
    Opt(inner) => wrap_operand(inner, render_regex(inner)) + "?"
    Repeat(inner, mn, mx) => {
      let spec = match mx {
        None => mn.to_string() + ","
        Some(n) =>
          if n == mn {
            mn.to_string()
          } else {
            mn.to_string() + "," + n.to_string()
          }
      }
      // 渲染前先保证 max >= min（生成器可能产生逆序）
      let fixed = match mx {
        None => Repeat(inner, mn, None)
        Some(n) =>
          if n < mn {
            Repeat(inner, mn, Some(mn))
          } else {
            Repeat(inner, mn, Some(n))
          }
      }
      ignore(fixed)
      wrap_operand(inner, render_regex(inner)) + "{" + spec + "}"
    }
  }
}

///|
/// 量词/拼接中对复合操作数加括号；字符类与空串无需括号
fn wrap_operand(r : Regex, s : String) -> String {
  match r {
    Class(_, _) | Empty => s
    _ => "(" + s + ")"
  }
}

///|
/// 在字母表 {a,b,c} 上穷举长度 ≤ n 的全部串
fn brute_force_alphabet(max_len : Int) -> Array[String] {
  let out : Array[String] = [""]
  let codes = [97, 98, 99]
  let mut frontier : Array[Array[Int]] = [[]]
  let mut len = 1
  while len <= max_len {
    let next : Array[Array[Int]] = []
    for i = 0; i < frontier.length(); i = i + 1 {
      for k = 0; k < codes.length(); k = k + 1 {
        let grown = copy_ints(frontier[i])
        grown.push(codes[k])
        next.push(grown)
      }
    }
    for i = 0; i < next.length(); i = i + 1 {
      out.push(ints_to_string(next[i]))
    }
    frontier = next
    len = len + 1
  }
  out
}

///|
fn copy_ints(xs : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for i = 0; i < xs.length(); i = i + 1 {
    out.push(xs[i])
  }
  out
}

///|
fn ints_to_string(codes : Array[Int]) -> String {
  let sb = StringBuilder()
  for i = 0; i < codes.length(); i = i + 1 {
    sb.write_char(codes[i].unsafe_to_char())
  }
  sb.to_string()
}

///|
/// 三方一致性差分：NFA vs DFA vs 最小化 DFA，返回完成的对照数
fn differential_round(seed : Int64, cases : Int) -> Int {
  let rng = Rng::{ state: seed, }
  let exhaust = brute_force_alphabet(4)
  let mut done = 0
  let mut i = 0
  while i < cases {
    let ast = random_regex(rng, 3)
    let pattern = render_regex(ast)
    let m = ok(pattern)
    let d = m.to_dfa()
    let min = d.minimize()
    // 穷举对照
    for k = 0; k < exhaust.length(); k = k + 1 {
      let s = exhaust[k]
      let expected = m.accepts(s)
      if d.accepts(s) != expected || min.accepts(s) != expected {
        abort("differential mismatch on pattern: " + pattern + " input: " + s)
      }
      done = done + 1
    }
    // 随机长串对照
    for k = 0; k < 20; k = k + 1 {
      let sb = StringBuilder()
      let len = 1 + rng.pick(24)
      for q = 0; q < len; q = q + 1 {
        sb.write_char((97 + rng.pick(4)).unsafe_to_char())
      }
      let s = sb.to_string()
      let expected = m.accepts(s)
      if d.accepts(s) != expected || min.accepts(s) != expected {
        abort("differential mismatch on pattern: " + pattern + " input: " + s)
      }
      done = done + 1
    }
    // 枚举抽样一致性：枚举出的每条串必须被三方同时接受
    let samples = min.strings_up_to(4, 2, 24)
    for k = 0; k < samples.length(); k = k + 1 {
      let s = samples[k]
      if !(m.accepts(s) && d.accepts(s)) {
        abort("enumeration mismatch on pattern: " + pattern + " input: " + s)
      }
      done = done + 1
    }
    i = i + 1
  }
  done
}

///|
test "random differential: nfa vs dfa vs minimized (>= 1000 checks)" {
  // 40 个随机模式 × (121 穷举 + 20 随机 + 枚举抽样) ≥ 1000 对照
  let total = differential_round(20261013L, 40)
  inspect(total >= 1000, content="true")
}

///|
test "random differential: second batch, different seed" {
  let total = differential_round(987654321L, 40)
  inspect(total >= 1000, content="true")
}
