# moon_outlines 项目申报书（草稿框架）

> 注意：本文件只是结构参考。正式申报书必须**人工撰写**（一页 Markdown），
> 明显 AI 套话会在审核阶段被驳回。每个 TODO 用你自己的理解填写。

## 基本信息

- 项目名称：moon_outlines —— LLM 结构化输出约束解码核心库
- 项目方向：AI 基础设施 / 开源库移植（通用性：任何需要模型输出合法结构化数据的场景）
- 是否为移植项目：是
- 原项目名称：outlines
- 原项目链接：https://github.com/dottxt-ai/outlines
- 原项目许可证：Apache-2.0
- 本项目许可证：Apache-2.0
- GitHub 仓库链接：TODO（建仓后填写）

## 项目简介

TODO：3-5 句话。要点参考——把正则 / JSON Schema / CFG 编译成自动机，
再与 tokenizer 词表结合，为受限采样提供逐步合法 token 集合；
移植的是 outlines 的核心思路（自动机 + 掩码），以 MoonBit 原生包结构重新实现，
不包含上游代码。

## 三个完整的预期使用场景（章程要求 ≥3 个）

1. TODO 本地小模型生成配置 / API 响应：给 JSON Schema，模型输出 100% 合法 JSON
2. TODO Agent 工具调用参数约束：工具签名 -> 文法，杜绝参数格式错误
3. TODO 测试数据生成：从 Schema/正则直接采样合法样例（该场景无需模型，自动机独立可用）

每个场景写清楚：谁在什么情况下用它、解决什么具体痛点。

## 拟实现的核心功能

- 正则子集 -> NFA/DFA 编译器（全匹配语义）
- EBNF -> 下推自动机；JSON 值文法内置
- token mask 引擎（自动机状态 × tokenizer 词表）
- GBNF 文法导出，对接 llama.cpp 绑定
- 差分测试（NFA vs DFA）与生成-校验闭环（对接 moonschema）

## 移植说明与边界

- 上游 outlines 为 Apache-2.0，本项目同为 Apache-2.0，仅移植算法思路，无代码复制
- 明确不做：模型训练/ serving、流式 logits 服务、tokenizer 训练、
  上游的模型集成层（transformers/vllm bindings）
- 与生态内校验库（moonschema 等）的关系：事前约束 vs 事后校验，互补；
  并以其作为闭环测试依赖

## 实现路径（体现技术理解）

TODO：用自己的话写清楚——为什么全匹配语义、为什么解析期脱糖量词、
token 掩码的正确性难点在 token 边界与多字节字符、朴素逐 token 推进的取舍。
