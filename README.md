# x86_64 汇编语言教程

[![CI](https://github.com/noisystreet/x86_64_assembly/actions/workflows/ci.yml/badge.svg)](https://github.com/noisystreet/x86_64_assembly/actions/workflows/ci.yml)

x86_64 汇编语言入门与进阶教程，涵盖基础语法、指令集、调用约定、SIMD、优化、多线程等主题。

## 文档

在线文档（Read the Docs）：

> **<https://x86-64-assembly.readthedocs.io/zh-cn/latest/>**

## 本地构建

```bash
pip install -r requirements.txt
make html       # 构建 HTML
make serve      # 构建并在 localhost:8000 启动预览
make check      # 编译验证所有示例
```

## 目录结构

```
source/
├── chapter_01_basics/          # 基础知识
├── chapter_02_architecture/    # x86_64 架构
├── chapter_03_instructions/    # 指令集
├── chapter_04_subroutines/     # 子程序与调用约定
├── chapter_05_data/            # 数据结构
├── chapter_06_floating_point/  # 浮点与 SIMD
├── chapter_07_interfacing/     # C/汇编互操作
├── chapter_08_optimization/    # 性能优化
├── chapter_09_multithreading/  # 多线程
├── examples/                   # 可编译运行示例
└── appendix/                   # 附录
```

## 许可证

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
