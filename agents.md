# agents.md — x86_64 汇编语言教程项目

## 项目概述

本项目编写一本 **x86_64 汇编语言教程**，使用 reStructuredText（`.rst`）格式，基于 Sphinx 构建。

- 文档源目录：`source/`
- 构建输出：`./_build/html/`（`make html` 后生成）
- 目标读者：有高级语言编程经验的开发者、计算机专业学生
- 汇编器：**NASM**（主线），第 1.5 节讲解 GAS 与 ``gcc -S`` 作为扩展
- 参考编译器：**GCC (C)** — 选择 C 而非 C++，因为 C 的 ABI 更简单直接，适合初学者理解汇编交互
- 平台：Linux x86_64

## 项目文件说明

| 文件 | 说明 |
|------|------|
| `source/preface.rst` | 前言：为什么学习汇编、目标读者、预备知识、全书结构 |
| `source/index.rst` | Sphinx 根文档（toctree 入口） |
| `source/chapter_01_basics/` | 基础知识与环境搭建（汇编概念、NASM 安装、Hello World、语法基础） |
| `source/chapter_02_architecture/` | x86_64 体系结构（寄存器、内存模型、寻址方式、栈） |
| `source/chapter_03_instructions/` | 指令集（数据传送、算术、逻辑、控制流、系统调用） |
| `source/chapter_04_subroutines/` | 子程序与调用约定（System V ABI、栈帧、递归） |
| `source/chapter_05_data/` | 数据结构（数组、字符串、结构体） |
| `source/chapter_06_floating_point/` | 浮点运算与 SIMD（SSE、AVX、浮点运算深入） |
| `source/chapter_07_interfacing/` | 与 C 语言交互（内联汇编、调用 C 函数、汇编库） |
| `source/chapter_08_optimization/` | 性能分析与优化（profiling、指令级优化） |
| `source/chapter_09_multithreading/` | 多线程编程基础（线程创建、同步、原子操作） |
| `source/appendix/` | 附录（指令参考、系统调用表、工具与 GDB 调试） |
| `source/examples/` | 可运行的汇编示例（每个 `.asm` 对应一个 `.rst` 说明页） |
| `source/conf.py` | Sphinx 构建配置 |
| `Makefile` | 构建入口（`make html` / `make clean`） |
| `scripts/precommit-check.sh` | 预提交检查脚本（在 commit 前自动验证 RST 文档语法） |
| `requirements.txt` | 构建依赖（sphinx, sphinx-rtd-theme） |
| `.readthedocs.yaml` | Read the Docs 构建配置 |
| `LICENSE` | CC BY-SA 4.0 许可证 |
| `.gitignore` | 版本控制忽略规则 |
| `agents.md` | **本文件**：AI 助手的工作上下文和约束 |

## 通用约束

1. **许可证**：本文档采用 CC BY-SA 4.0（Creative Commons Attribution-ShareAlike 4.0 International），详见 `LICENSE` 文件
2. **文档格式**：使用 reStructuredText（`.rst`）格式
3. **引用源码**：使用绝对路径的 `file:///` 链接引用源码文件，格式为 `` `链接文本 <file:///绝对路径/文件>`__ ``
4. **避免冗余**：不创建不必要的文件，优先编辑已有文件
5. **权限**：不做 `git push --force`、`reset --hard` 等破坏性操作
6. **代码示例**：在文档中引用代码时，说明其所属文件和行号范围
7. **示例验证**：所有 `.asm` 示例代码应保证可编译、可运行

## 文档写作规范

### 文档结构
- 每篇文档应有标题和目录
- 按章节组织，章节层级不超过三级
- 末尾标注生成日期和项目名称

### 引用规范
- 引用源码文件使用绝对路径 markdown 链接
- 引用指令或寄存器使用 `` ` `` 反引号标记
- 关键代码片段应提供文件定位

### 内容深度
- 概念讲解与代码示例相结合
- 复杂流程配合 ASCII 图表说明
- 关键指令用表格列出格式与效果
- 避免大段堆叠代码，优先提炼核心模式

### 写作风格
- **由浅入深**：从直观例子出发引入概念，逐步深入到底层细节
- **夹叙夹议**：叙述代码事实的同时穿插说明（为什么这样用、性能考量、与其他方案的对比）
- **过渡自然**：章节之间、段落之间要有承上启下的过渡，避免生硬切换
- **避免知识点罗列**：每个知识点应有上下文铺垫，能用表格/图表/对比表达的内容不要用列表堆砌

## 写作路线图

按以下顺序推进内容编写：

1. **第 1 章：基础知识与环境搭建** — 汇编概念、NASM 安装、Hello World、语法基础
2. **第 2 章：体系结构** — 寄存器、内存模型、寻址方式、栈
3. **第 3 章：指令集** — 数据传送 → 算术 → 逻辑 → 控制流 → 系统调用
4. **第 4 章：子程序与调用约定** — ABI、栈帧、递归
5. **第 5 章：数据结构** — 数组、字符串、结构体
6. **第 6 章：浮点与 SIMD** — SSE、AVX
7. **第 7 章：与 C 交互** — 内联汇编、混合编程
8. **第 8 章：优化** — 性能分析、优化技术
9. **第 9 章：多线程** — 线程、同步、原子操作

## 构建方法

```bash
# 安装依赖
pip install -r requirements.txt

# 构建 HTML 文档
make html

# 构建产物位于 _build/html/
```

自动部署到 Read the Docs 后，文档会自动构建并托管。本地构建也可通过 `make html` 完成。
