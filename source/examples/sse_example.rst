.. _example-sse:

==========================
SSE/SIMD 浮点运算演示
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 sse_example.asm -o sse_example.o && ld sse_example.o -o sse_example
   ; 运行：./sse_example

.. literalinclude:: sse_example.asm
   :language: none
   :linenos:
