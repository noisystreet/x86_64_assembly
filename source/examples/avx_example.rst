.. _example-avx:

==========================
AVX/AVX2 SIMD 运算演示
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 avx_example.asm -o avx_example.o && ld avx_example.o -o avx_example
   ; 运行：./avx_example
   ; 注意：需要支持 AVX/AVX2 的 CPU（2013 年后的主流 x86_64）

.. literalinclude:: avx_example.asm
   :language: none
   :linenos:
