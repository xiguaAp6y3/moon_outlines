///|
/// moon_outlines 演示 CLI：编译正则子集并对样例输入做全串匹配。
/// 运行：`moon run cmd/main`
fn main {
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
      Ok(m) =>
        for j = 0; j < inputs.length(); j = j + 1 {
          let input = inputs[j]
          let verdict = if m.accepts(input) { "accept" } else { "reject" }
          println("  " + input + " => " + verdict)
        }
    }
  }
}
