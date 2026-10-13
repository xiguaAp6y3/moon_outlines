///|
/// 枚举搜索前沿的硬上限，防止组合爆炸。
const FRONTIER_CAP : Int = 4096

///|
/// 从 DFA 枚举长度不超过 max_len 的合法串（测试数据生成场景）。
///
/// 每个原子区间最多取 max_width 个代表字符（区间起点/终点），
/// 代表字符避开 UTF-16 代理区以保证生成的字符串合法；结果按长度升序，
/// 条数上限 limit、搜索前沿上限 FRONTIER_CAP 共同防止组合爆炸。
pub fn Dfa::strings_up_to(
  self : Dfa,
  max_len : Int,
  max_width : Int,
  limit : Int,
) -> Array[String] {
  let results : Array[String] = []
  if limit <= 0 || max_len < 0 {
    return results
  }
  if self.accept[self.start] {
    results.push("")
  }
  // 预计算每个区间的代表字符
  let reps : Array[Array[Char]] = []
  for i = 0; i < self.intervals.length(); i = i + 1 {
    let (lo, hi) = self.intervals[i]
    reps.push(interval_reps(lo, hi, max_width))
  }
  let mut frontier : Array[(Int, Array[Char])] = [(self.start, [])]
  let mut len = 1
  while len <= max_len {
    if results.length() >= limit {
      break
    }
    let next : Array[(Int, Array[Char])] = []
    let mut stop = false
    for fi = 0; fi < frontier.length(); fi = fi + 1 {
      let (s, chars) = frontier[fi]
      for j = 0; j < self.intervals.length(); j = j + 1 {
        let t = self.trans[s][j]
        if t < 0 {
          continue
        }
        for ci = 0; ci < reps[j].length(); ci = ci + 1 {
          let grown = copy_chars(chars)
          grown.push(reps[j][ci])
          if self.accept[t] && results.length() < limit {
            results.push(chars_to_string(grown))
          }
          if results.length() >= limit {
            stop = true
            break
          }
          next.push((t, grown))
        }
        if stop {
          break
        }
      }
      if stop {
        break
      }
    }
    if stop || next.length() == 0 || next.length() > FRONTIER_CAP {
      break
    }
    frontier = next
    len = len + 1
  }
  results
}

///|
/// 计算原子区间的代表字符：取区间起点/终点，避开代理区，去重并限量
fn interval_reps(lo : Int, hi : Int, max_width : Int) -> Array[Char] {
  let out : Array[Char] = []
  if max_width <= 0 {
    return out
  }
  let candidates = [lo, hi]
  for i = 0; i < candidates.length(); i = i + 1 {
    let mut code = candidates[i]
    if code < 0 || code > CODE_MAX {
      continue
    }
    // 代理区码元无法单独构成合法字符：跨过代理区的区间用 0xE000 代表，
    // 完全落在代理区内的区间丢弃代表
    if code >= 0xD800 && code <= 0xDFFF {
      if hi >= 0xE000 {
        code = 0xE000
      } else {
        continue
      }
    }
    let mut dup = false
    for k = 0; k < out.length(); k = k + 1 {
      if Char::to_int(out[k]) == code {
        dup = true
        break
      }
    }
    if !dup && out.length() < max_width {
      out.push(code.unsafe_to_char())
    }
  }
  out
}

///|
/// 拷贝字符数组
fn copy_chars(chars : Array[Char]) -> Array[Char] {
  let out : Array[Char] = []
  for i = 0; i < chars.length(); i = i + 1 {
    out.push(chars[i])
  }
  out
}

///|
/// 由字符数组构造字符串
fn chars_to_string(chars : Array[Char]) -> String {
  let sb = StringBuilder()
  for i = 0; i < chars.length(); i = i + 1 {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
