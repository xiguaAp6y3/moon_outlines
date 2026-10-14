// JSON 文法差分测试：PDA.accept 必须与 core @json.parse 的判定一致。
//
// 已知的有意偏差（不进入语料，M4 掩码阶段收紧）：
// - 字符串内容未排除原始控制字符（RFC 8259 禁止，本文法暂允许）
// - \uXXXX 不校验代理对合法性（core 拒绝孤立代理，本位法接受）

///|
/// core JSON 解析是否成功
fn core_json_ok(s : String) -> Bool {
  try {
    @json.parse(s) |> ignore
    true
  } catch {
    _ => false
  }
}

///|
/// 差分运行：返回不一致样本的报告（格式：core=OK/NO pda=OK/NO <样本>）
fn differential(corpus : Array[String]) -> String {
  let report = StringBuilder()
  for i = 0; i < corpus.length(); i = i + 1 {
    let s = corpus[i]
    let core_ok = core_json_ok(s)
    let p = match @ebnf.json_pda() {
      Err(m) => abort("json grammar error: " + m)
      Ok(p) => p
    }
    let pda_ok = p.accept(s)
    if core_ok != pda_ok {
      report.write_string(
        "MISMATCH core=" +
        core_ok.to_string() +
        " pda=" +
        pda_ok.to_string() +
        " <" +
        s +
        ">" +
        "\n",
      )
    }
  }
  report.to_string()
}

///|
test "json differential: valid documents" {
  let report = differential([
    "{\"k\":[1,2.5e3,null,true],\"s\":\"x\u0041y\"}", "[]", "{}", "\"-0.5\"", "[ ]",
    " { \"k\" : [ 1 , 2 ] } ", "\"a\\\"b\"", "[[[[1]]]]", "\"\\u00e9\\n\\t\"", "0",
    "-0", "1e10", "123.456E-7", "{\"nested\":{\"deep\":[{\"x\":[-1.5e-3]}]}}",
  ])
  inspect(report, content="")
}

///|
test "json differential: invalid documents" {
  let report = differential([
    "", "   ", "{\"a\":}", "[1,]", "01", "1.", "\"unterminated", "tru", "{\"a\" 1}",
    "+1", "NaN", "[1 true]", "{\"a\":1,}", ".5", "\"\\x\"", "[1,2,]", "{", "[", "\"",
    "-", "1e", "{\"a\":\"b\"",
  ])
  inspect(report, content="")
}

///|
test "json start set exposes structural terminals" {
  let p = match @ebnf.json_pda() {
    Err(m) => abort(m)
    Ok(p) => p
  }
  // 顶层（ws 后）可进入五种值：{ [ " 数字 负号 true false null
  let specs = p.nexts()
  inspect(specs.length() >= 8, content="true")
}
