///|
/// moon_outlines 演示 CLI：编译正则子集并对样例输入做全串匹配。
/// 运行：`moon run cmd/main`
fn main {
  ebnf_demo()
  json_demo()
  let cases : Array[(String, Array[String])] = []
  // 结构化输出场景的雏形：把"合法输出的形状"写成正则
  cases.push(("true|false", ["true", "false", "True", "tru"]))
  cases.push(("-?\\d+(\\.\\d+)?", ["42", "-7", "3.14", "1.", "+1"]))
  cases.push(("\"(yes|no|maybe)\"", ["\"yes\"", "\"no\"", "\"sure\""]))
  cases.push(("\\d{3}-\\d{4}", ["555-1234", "555-123"]))
  cases.push(("[a-z_][a-z0-9_]*", ["snake_case", "9bad", "_ok"]))
  for i = 0; i < cases.length(); i = i + 1 {
    let (pattern, inputs) = cases[i]
    println("pattern: " + pattern)
    match @re.compile(pattern) {
      Err(msg) => println("  compile error: " + msg)
      Ok(m) => {
        let dfa = m.to_dfa()
        let min = dfa.minimize()
        println(
          "  states: nfa=" +
          m.state_count().to_string() +
          " dfa=" +
          dfa.state_count().to_string() +
          " minimized=" +
          min.state_count().to_string(),
        )
        for j = 0; j < inputs.length(); j = j + 1 {
          let input = inputs[j]
          let verdict = if m.accepts(input) { "accept" } else { "reject" }
          println("  " + input + " => " + verdict)
        }
        // 枚举演示：该模式下的合法样例（测试数据生成场景）
        let samples = min.strings_up_to(6, 2, 5)
        if samples.length() > 0 {
          let sb = StringBuilder()
          for j = 0; j < samples.length(); j = j + 1 {
            if j > 0 {
              sb.write_char(' ')
            }
            sb.write_string("\"" + samples[j] + "\"")
          }
          println("  samples: " + sb.to_string())
        }
      }
    }
  }
}

///|
/// EBNF 演示：解析 Lark 风格文法并输出规范化形式（M3）。
fn ebnf_demo() -> Unit {
  println("")
  println("== ebnf demo ==")
  let src = "value: \"-\"? digit+\ndigit: \"0\" | \"1\" | \"2\"\nlist: \"[\" (value | list)* \"]\""
  match @eb.parse_grammar(src) {
    Err(m) => println("parse error: " + m)
    Ok(g) => {
      println("canonical grammar:")
      println(@eb.render_grammar(g))
      println("start rule: " + g.start)
    }
  }
}

///|
/// JSON 演示：内置 RFC 8259 文法的下推自动机对样例串做整串判定（M3）。
fn json_demo() -> Unit {
  println("")
  println("== json pda demo ==")
  let cases : Array[String] = [
    "{\"k\": [1, 2.5e3, null, true]}", "[1, 2, ]", "{\"a\" 1}", "\"esc \\u0041\"",
    "tru",
  ]
  for i = 0; i < cases.length(); i = i + 1 {
    let p = match @eb.json_pda() {
      Err(m) => {
        println("grammar error: " + m)
        return
      }
      Ok(p) => p
    }
    let input = cases[i]
    let verdict = if p.accept(input) { "accept" } else { "reject" }
    println("  " + input + " => " + verdict)
  }
}
