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
