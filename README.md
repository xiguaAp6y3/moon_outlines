# moon_outlines

> 面向 LLM 结构化输出的约束解码核心库 —— outlines 核心思路的 MoonBit 移植。

让本地模型**永远输出合法的结构化数据**：把正则 / JSON Schema / CFG 编译成自动机，
再与 tokenizer 词表结合，在每一步采样时给出合法 token 集合（token mask），
从机制上杜绝非法 JSON、越界数字、格式错误，而不是生成后再修补。

## 为什么需要它

MoonBit 生态里已经有 HF tokenizers 移植（`howtomakeaname/tokenizers-moonbit`）、
llama.cpp 绑定（`Kaida-Amethyst/llama`）和各类 LLM 客户端，但结构化输出这条链路上
**只有"事后校验"（moonschema、moon_zod 等），没有"事前约束"**。校验只能告诉你
"错了重来"，约束解码让模型根本走不到错误分支。本库补上这块拼图。

## 当前状态（M1，详见 [ROADMAP.md](ROADMAP.md)）

- [x] 正则子集解析：字面量、`.`、字符类 `[a-z]`/`[^a-z]`、`\d \D \w \W \s \S`、
  分组 `()`、分支 `|`、量词 `* + ? {m} {m,} {m,n}`
- [x] Thompson NFA 构造与全串匹配（全匹配语义，专为生成场景设计）
- [ ] DFA 确定化与最小化、NFA 状态枚举（测试数据生成）
- [ ] EBNF (Lark 语法) -> 下推自动机
- [ ] JSON Schema 子集 -> 正则/文法降级
- [ ] token mask 引擎（tokenizer.json 词表 × 自动机状态）
- [ ] GBNF 文法导出（对接 llama.cpp）

## 使用

```moonbit
// moon add outlineuser/moon_outlines（发布后）
let machine = @regex.compile("\"(yes|no)\"")
match machine {
  Ok(m) => {
    println(m.accepts("\"yes\"")) // true
    println(m.accepts("\"maybe\"")) // false
  }
  Err(msg) => println("compile error: " + msg)
}
```

运行示例：`moon run cmd/main`

## 开发

```bash
moon check        # 类型检查
moon test         # 运行测试
moon fmt          # 格式化
moon run cmd/main # 演示 CLI
```

## 结构

```
regex/      正则子集解析（AST + 递归下降）+ Thompson NFA + 全串匹配
cmd/main/   演示 CLI
```

## 上游与许可证

- 本项目移植 [dottxt-ai/outlines](https://github.com/dottxt-ai/outlines)
  （Apache-2.0）的核心思路，不包含其代码；参考实现还包括
  [mlc-ai/xgrammar](https://github.com/mlc-ai/xgrammar)（Apache-2.0）。
- 本项目采用 Apache-2.0 许可证（见 [LICENSE](LICENSE)）。

## 路线图

见 [ROADMAP.md](ROADMAP.md)；申报材料草稿见 [PROPOSAL.md](PROPOSAL.md)。
