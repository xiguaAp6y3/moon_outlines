// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x

name = "outlineuser/moon_outlines"

version = "0.1.0"

readme = "README.md"

repository = ""

license = "Apache-2.0"

keywords = [
  "llm",
  "structured-output",
  "regex",
  "automata",
  "constrained-decoding",
]

preferred_target = "wasm"

description = "Constrained decoding core for MoonBit LLM tooling: compile regex / JSON-Schema into automata and token masks. A MoonBit port of the core ideas of outlines (upstream: dottxt-ai/outlines, Apache-2.0)."
