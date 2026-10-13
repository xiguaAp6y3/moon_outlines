///|
/// 码点论域上界：MoonBit 字符串按 UTF-16 码元组织，字符类覆盖 [0, 0xFFFF]。
const CODE_MAX : Int = 0xFFFF

///|
/// 确定有限自动机（DFA）。
///
/// 转移表按"原子区间"组织：汇总全部边标签的区间边界后，
/// 把论域 [0, CODE_MAX] 切成若干原子区间；同一区间内所有码点行为一致，
/// 因此 trans[s][i] 对整个区间 i 有效，避免逐字符建表。
/// trans 目标为 -1 表示死路（该输入下无后续）。
pub struct Dfa {
  intervals : Array[(Int, Int)]
  trans : Array[Array[Int]]
  accept : Array[Bool]
  start : Int
}

///|
/// 隶属向量相等（长度与逐项比较）。
fn sets_equal(a : Array[Bool], b : Array[Bool]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// 在已注册状态集合里查找等价集合，返回其 DFA 状态号。
fn find_set(sets : Array[Array[Bool]], set : Array[Bool]) -> Int? {
  for i = 0; i < sets.length(); i = i + 1 {
    if sets_equal(sets[i], set) {
      return Some(i)
    }
  }
  None
}

///|
/// 归一化区间集合：裁剪到论域、排序、合并相交/相邻区间；
/// negated 时按论域求补。结果为升序不相交区间。
fn normalize_ranges(
  ranges : Array[(Int, Int)],
  negated : Bool,
) -> Array[(Int, Int)] {
  let items : Array[(Int, Int)] = []
  for i = 0; i < ranges.length(); i = i + 1 {
    let (lo, hi) = ranges[i]
    let l = if lo < 0 { 0 } else { lo }
    let h = if hi > CODE_MAX { CODE_MAX } else { hi }
    if l <= h {
      items.push((l, h))
    }
  }
  // 插入排序（区间数量小）
  for i = 1; i < items.length(); i = i + 1 {
    let key = items[i]
    let mut j = i - 1
    while j >= 0 && items[j].0 > key.0 {
      items[j + 1] = items[j]
      j = j - 1
    }
    items[j + 1] = key
  }
  // 合并相交或相邻的区间
  let merged : Array[(Int, Int)] = []
  for i = 0; i < items.length(); i = i + 1 {
    let (lo, hi) = items[i]
    if merged.length() > 0 {
      let last = merged[merged.length() - 1]
      if lo <= last.1 + 1 {
        if hi > last.1 {
          merged[merged.length() - 1] = (last.0, hi)
        }
        continue
      }
    }
    merged.push((lo, hi))
  }
  if negated {
    let comp : Array[(Int, Int)] = []
    let mut next = 0
    for i = 0; i < merged.length(); i = i + 1 {
      let (lo, hi) = merged[i]
      if lo > next {
        comp.push((next, lo - 1))
      }
      next = hi + 1
    }
    if next <= CODE_MAX {
      comp.push((next, CODE_MAX))
    }
    comp
  } else {
    merged
  }
}

///|
/// 由全部归一化边标签构造原子区间表：
/// 收集所有边界点（lo 与 hi+1），去重排序后取相邻边界对。
fn build_atomic_intervals(
  out : Array[Array[(Array[(Int, Int)], Int)]],
) -> Array[(Int, Int)] {
  let bounds : Array[Int] = []
  bounds.push(0)
  bounds.push(CODE_MAX + 1)
  for s = 0; s < out.length(); s = s + 1 {
    for k = 0; k < out[s].length(); k = k + 1 {
      let (norm, _) = out[s][k]
      for i = 0; i < norm.length(); i = i + 1 {
        let (lo, hi) = norm[i]
        bounds.push(lo)
        bounds.push(hi + 1)
      }
    }
  }
  // 排序（插入排序，去重）
  for i = 1; i < bounds.length(); i = i + 1 {
    let key = bounds[i]
    let mut j = i - 1
    while j >= 0 && bounds[j] > key {
      bounds[j + 1] = bounds[j]
      j = j - 1
    }
    bounds[j + 1] = key
  }
  let intervals : Array[(Int, Int)] = []
  for i = 0; i < bounds.length() - 1; i = i + 1 {
    if bounds[i] < bounds[i + 1] && bounds[i] <= CODE_MAX {
      intervals.push((bounds[i], bounds[i + 1] - 1))
    }
  }
  intervals
}

///|
/// 子集构造：把 NFA 确定化为 DFA。
///
/// DFA 状态对应 NFA 状态的一个 ε-闭包集合；对每个原子区间，
/// 目标集合 = 当前集合内所有"标签完整覆盖该区间"的边的目标并集，再做 ε-闭包。
/// 集合查重采用线性扫描（M2 规模下集合数很小；M4 引擎接入时再换哈希）。
pub fn Machine::to_dfa(self : Machine) -> Dfa {
  let nfa = self.nfa
  let n = nfa.edges.length()
  // 1) 预归一化每个 NFA 状态的非 ε 出边
  let out : Array[Array[(Array[(Int, Int)], Int)]] = []
  for s = 0; s < n; s = s + 1 {
    let list : Array[(Array[(Int, Int)], Int)] = []
    for k = 0; k < nfa.edges[s].length(); k = k + 1 {
      let e = nfa.edges[s][k]
      match e.label {
        Epsilon => ()
        ClassLabel(ranges, negated) =>
          list.push((normalize_ranges(ranges, negated), e.to))
      }
    }
    out.push(list)
  }
  // 2) 原子区间表
  let intervals = build_atomic_intervals(out)
  let n_int = intervals.length()
  // 3) BFS 子集构造
  let start_set : Array[Bool] = []
  for i = 0; i < n; i = i + 1 {
    start_set.push(false)
  }
  start_set[nfa.start] = true
  nfa.close_over_epsilon(start_set)
  let sets : Array[Array[Bool]] = [start_set]
  // 接受标记统一在状态"被发现"时登记，保证与状态号对齐
  let accept_flags : Array[Bool] = [nfa.has_accept(start_set)]
  let trans_rows : Array[Array[Int]] = []
  let mut head = 0
  while head < sets.length() {
    let set = sets[head]
    let row : Array[Int] = []
    for i = 0; i < n_int; i = i + 1 {
      let (ilo, ihi) = intervals[i]
      let target : Array[Bool] = []
      for j = 0; j < n; j = j + 1 {
        target.push(false)
      }
      let mut moved = false
      for s = 0; s < n; s = s + 1 {
        if set[s] {
          let edges = out[s]
          for k = 0; k < edges.length(); k = k + 1 {
            let (norm, to) = edges[k]
            // 原子区间与归一化标签要么不相交、要么被完整包含
            let mut contains = false
            for q = 0; q < norm.length(); q = q + 1 {
              let (nlo, nhi) = norm[q]
              if nlo <= ilo && nhi >= ihi {
                contains = true
                break
              }
            }
            if contains && !target[to] {
              target[to] = true
              moved = true
            }
          }
        }
      }
      if moved {
        nfa.close_over_epsilon(target)
        match find_set(sets, target) {
          Some(id) => row.push(id)
          None => {
            sets.push(target)
            accept_flags.push(nfa.has_accept(target))
            row.push(sets.length() - 1)
          }
        }
      } else {
        row.push(-1)
      }
    }
    trans_rows.push(row)
    head = head + 1
  }
  Dfa::{ intervals, trans: trans_rows, accept: accept_flags, start: 0, }
}

///|
/// 判断输入是否**完整**匹配（与 Machine::accepts 语义一致）。
pub fn Dfa::accepts(self : Dfa, input : String) -> Bool {
  let units = to_code_units(input)
  let mut s = self.start
  for i = 0; i < units.length(); i = i + 1 {
    let code = units[i].to_int()
    let mut t = -1
    for j = 0; j < self.intervals.length(); j = j + 1 {
      let (lo, hi) = self.intervals[j]
      if code >= lo && code <= hi {
        t = self.trans[s][j]
        break
      }
    }
    if t < 0 {
      return false
    }
    s = t
  }
  self.accept[s]
}

///|
/// DFA 状态数（观测用）
pub fn Dfa::state_count(self : Dfa) -> Int {
  self.trans.length()
}

///|
/// 原子区间数（观测用）
pub fn Dfa::interval_count(self : Dfa) -> Int {
  self.intervals.length()
}
