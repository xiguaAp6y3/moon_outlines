// DFA 确定化与最小化的黑盒测试（经 Machine::to_dfa / Dfa::accepts 公共 API）。

///|
fn dfa_of(pattern : String) -> @regex.Dfa {
  ok(pattern).to_dfa()
}

///|
/// NFA 与 DFA 对同一输入的行为必须一致
fn agree(pattern : String, inputs : Array[String]) -> Bool {
  let m = ok(pattern)
  let d = m.to_dfa()
  let min = d.minimize()
  let mut good = true
  for i = 0; i < inputs.length(); i = i + 1 {
    let s = inputs[i]
    if !(m.accepts(s) == d.accepts(s) && d.accepts(s) == min.accepts(s)) {
      good = false
    }
  }
  good
}

///|
test "dfa agrees with nfa: literals" {
  inspect(agree("abc", ["", "a", "ab", "abc", "abcd", "ABC"]), content="true")
}

///|
test "dfa agrees with nfa: alternation and star" {
  inspect(
    agree("a(b|c)*d", ["", "ad", "abd", "acd", "abcd", "abcbcbcd", "abc", "aad"]),
    content="true",
  )
}

///|
test "dfa agrees with nfa: classes and repeats" {
  inspect(
    agree("[a-c]{2,4}\\d", ["", "ab1", "abc2", "abcd3", "a5", "abcde5", "abx"]),
    content="true",
  )
}

///|
test "dfa agrees with nfa: negated class and dot" {
  inspect(
    agree("[^a-c].x", ["dx&x", "ax!x", "dxx", "e?xy", ""]),
    content="true",
  )
}

///|
test "dfa state count is small for simple patterns" {
  let d = dfa_of("ab")
  inspect(d.state_count() <= 4, content="true")
  let min = d.minimize()
  inspect(min.state_count() <= d.state_count(), content="true")
}

///|
test "minimize collapses equivalent dfa states" {
  // (a|b)* 语言上不需要区分 a/b，最小化后状态数应显著少于确定化结果
  let raw = dfa_of("(a|b)*c(a|b)*")
  let min = raw.minimize()
  inspect(min.state_count() < raw.state_count(), content="true")
  // 语言不变
  inspect(
    agree("(a|b)*c(a|b)*", ["", "c", "ac", "cb", "abca", "ab"]),
    content="true",
  )
}

///|
test "epsilon language minimizes to a single accepting state" {
  // a{0}b{0} = 两个零次重复拼接，语言 = {ε}
  let min = dfa_of("a{0}b{0}").minimize()
  inspect(min.accepts(""), content="true")
  inspect(min.accepts("a"), content="false")
  inspect(min.state_count() == 1, content="true")
}

///|
fn contains_str(arr : Array[String], s : String) -> Bool {
  for i = 0; i < arr.length(); i = i + 1 {
    if arr[i] == s {
      return true
    }
  }
  false
}

///|
test "enumerate exact strings for literal patterns" {
  let min = dfa_of("(ab|ba)").minimize()
  let got = min.strings_up_to(4, 2, 100)
  // 单字符区间下枚举应完备：恰好 ab、ba
  inspect(
    got.length() == 2 && contains_str(got, "ab") && contains_str(got, "ba"),
    content="true",
  )
  // 且每条都被原机器接受
  let m = ok("(ab|ba)")
  for i = 0; i < got.length(); i = i + 1 {
    if !m.accepts(got[i]) {
      abort("enumerated invalid string")
    }
  }
}

///|
test "enumerate all strings over small alphabet up to length 3" {
  let min = dfa_of("(a|b)*").minimize()
  let got = min.strings_up_to(3, 2, 100)
  // 1 + 2 + 4 + 8 = 15 条
  inspect(got.length(), content="15")
}

///|
test "enumerated samples from wide classes are all accepted" {
  let min = dfa_of("\\d{2}-\\d").minimize()
  let got = min.strings_up_to(8, 2, 16)
  inspect(got.length() > 0, content="true")
  let m = ok("\\d{2}-\\d")
  for i = 0; i < got.length(); i = i + 1 {
    if !m.accepts(got[i]) {
      abort("enumerated invalid string")
    }
  }
}
