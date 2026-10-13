///|
/// moon_outlines —— 面向 LLM 结构化输出的约束解码核心库。
///
/// 本库移植 outlines（dottxt-ai/outlines, Apache-2.0）的核心思路：
/// 把正则 / JSON Schema / CFG 编译成自动机，再与 tokenizer 词表结合，
/// 为受限采样提供逐步合法 token 集合，使本地模型永远输出合法结构化数据。
///
/// 当前进度见 ROADMAP.md：M1 正则子集 -> NFA -> 全串匹配已可用（`regex` 包）。
