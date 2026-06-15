.. _chapter-07-inline:

===============================
C 语言内联汇编
===============================

.. 本篇内容

    - GCC 内联汇编语法
    - 基本 asm
    - 扩展 asm（输入/输出/破坏列表）
    - 使用 volatile

.. code-block:: c

   // 内联汇编示例
   int result;
   asm volatile (
       "mov $42, %0"
       : "=r" (result)
   );

TODO: 编写内容
