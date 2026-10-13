///|
/// DFA 最小化：Moore 风格分区细化。
///
/// 步骤：
/// 1. 活性分析——从接受状态沿反向转移做可达遍历，标记"能到达接受"的活状态；
///    其余状态（含 -1 死路目标）在细化中统一视为死态。
/// 2. 初始分区：活非接受 / 活接受。
/// 3. 反复细化：对每个分区按"目标分区签名"分组，签名不同的组拆为新分区；
///    目标为死态或 -1 的分量统一记为 -1。
/// 4. 以分区代表重建 DFA；若起点不活，返回单状态空语言 DFA。
pub fn Dfa::minimize(self : Dfa) -> Dfa {
  let m = self.trans.length()
  let n_int = self.intervals.length()
  // 1) 反向邻接表
  let rev : Array[Array[Int]] = []
  for s = 0; s < m; s = s + 1 {
    rev.push([])
  }
  for s = 0; s < m; s = s + 1 {
    for j = 0; j < n_int; j = j + 1 {
      let t = self.trans[s][j]
      if t >= 0 && t < m {
        rev[t].push(s)
      }
    }
  }
  // 从全部接受状态反向 BFS，标记活状态
  let live : Array[Bool] = []
  for s = 0; s < m; s = s + 1 {
    live.push(false)
  }
  let queue : Array[Int] = []
  for s = 0; s < m; s = s + 1 {
    if self.accept[s] {
      live[s] = true
      queue.push(s)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let t = queue[head]
    head = head + 1
    for k = 0; k < rev[t].length(); k = k + 1 {
      let s = rev[t][k]
      if !live[s] {
        live[s] = true
        queue.push(s)
      }
    }
  }
  // 2) 初始分区：0 = 活非接受，1 = 活接受（死态不参与细化）
  let mut part : Array[Int] = []
  for s = 0; s < m; s = s + 1 {
    if !live[s] {
      part.push(-1)
    } else if self.accept[s] {
      part.push(1)
    } else {
      part.push(0)
    }
  }
  let mut part_count = 2
  // 3) 迭代细化：对每个分区按签名分组拆分
  let mut changed = true
  while changed {
    changed = false
    let next : Array[Int] = []
    for s = 0; s < m; s = s + 1 {
      next.push(part[s])
    }
    for pid = 0; pid < part_count; pid = pid + 1 {
      // 收集该分区成员
      let members : Array[Int] = []
      for s = 0; s < m; s = s + 1 {
        if part[s] == pid {
          members.push(s)
        }
      }
      if members.length() <= 1 {
        continue
      }
      // assigned[i]：成员 i 的新分区号，-1 表示未分配
      let assigned : Array[Int] = []
      for i = 0; i < members.length(); i = i + 1 {
        assigned.push(-1)
      }
      assigned[0] = pid // 领袖保持原分区号
      let mut new_groups = 0
      for i = 1; i < members.length(); i = i + 1 {
        if assigned[i] >= 0 {
          continue
        }
        // 与领袖同签名 → 留在原分区
        if same_signature(self, part, live, members[0], members[i], n_int) {
          assigned[i] = pid
          continue
        }
        // 尝试并入先前拆出的组（与该组领袖同签名）
        let mut joined = -1
        for k = 1; k < i; k = k + 1 {
          if assigned[k] > pid && assigned[k] < part_count + new_groups {
            if same_signature(self, part, live, members[k], members[i], n_int) {
              joined = assigned[k]
              break
            }
          }
        }
        if joined >= 0 {
          assigned[i] = joined
          continue
        }
        // 新建一组，并吸收后续同签名成员
        let new_pid = part_count + new_groups
        new_groups = new_groups + 1
        assigned[i] = new_pid
        for k2 = i + 1; k2 < members.length(); k2 = k2 + 1 {
          if assigned[k2] < 0 {
            if same_signature(self, part, live, members[i], members[k2], n_int) {
              assigned[k2] = new_pid
            }
          }
        }
      }
      if new_groups > 0 {
        for i = 0; i < members.length(); i = i + 1 {
          next[members[i]] = assigned[i]
        }
        part_count = part_count + new_groups
        changed = true
      }
    }
    part = next
  }
  // 4) 重建
  if !live[self.start] {
    // 空语言：单状态、无转移
    let row : Array[Int] = []
    for j = 0; j < n_int; j = j + 1 {
      row.push(-1)
    }
    return Dfa::{
      intervals: copy_intervals(self.intervals),
      trans: [row],
      accept: [false],
      start: 0,
    }
  }
  // 每个分区取最小编号成员作为代表，重新编号为稠密 id
  let repr_of : Array[Int] = []
  let pid_to_new : Array[Int] = []
  for pid = 0; pid < part_count; pid = pid + 1 {
    repr_of.push(-1)
    pid_to_new.push(-1)
  }
  for s = 0; s < m; s = s + 1 {
    if live[s] && part[s] >= 0 {
      let pid = part[s]
      if repr_of[pid] < 0 {
        repr_of[pid] = s
      }
    }
  }
  let new_of_state : Array[Int] = []
  for s = 0; s < m; s = s + 1 {
    new_of_state.push(-1)
  }
  let mut next_new = 0
  for pid = 0; pid < part_count; pid = pid + 1 {
    if repr_of[pid] >= 0 {
      pid_to_new[pid] = next_new
      new_of_state[repr_of[pid]] = next_new
      next_new = next_new + 1
    }
  }
  // 同分区其余成员共享代表的新编号
  for s = 0; s < m; s = s + 1 {
    if live[s] && part[s] >= 0 {
      new_of_state[s] = pid_to_new[part[s]]
    }
  }
  let new_trans : Array[Array[Int]] = []
  let new_accept : Array[Bool] = []
  for pid = 0; pid < part_count; pid = pid + 1 {
    if repr_of[pid] >= 0 {
      let rep = repr_of[pid]
      let row : Array[Int] = []
      for j = 0; j < n_int; j = j + 1 {
        let t = self.trans[rep][j]
        if t >= 0 && live[t] {
          row.push(new_of_state[t])
        } else {
          row.push(-1)
        }
      }
      new_trans.push(row)
      new_accept.push(self.accept[rep])
    }
  }
  Dfa::{
    intervals: copy_intervals(self.intervals),
    trans: new_trans,
    accept: new_accept,
    start: new_of_state[self.start],
  }
}

///|
/// 判断两个状态在所有原子区间上的"目标分区号"是否一致（死目标记 -1）
fn same_signature(
  dfa : Dfa,
  part : Array[Int],
  live : Array[Bool],
  a : Int,
  b : Int,
  n_int : Int,
) -> Bool {
  for j = 0; j < n_int; j = j + 1 {
    let ta = dfa.trans[a][j]
    let tb = dfa.trans[b][j]
    let ma = if ta >= 0 && live[ta] { part[ta] } else { -1 }
    let mb = if tb >= 0 && live[tb] { part[tb] } else { -1 }
    if ma != mb {
      return false
    }
  }
  true
}

///|
/// 拷贝区间表
fn copy_intervals(intervals : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for i = 0; i < intervals.length(); i = i + 1 {
    out.push(intervals[i])
  }
  out
}
