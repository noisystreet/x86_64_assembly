.. _example-functions:

==========================
子程序与栈帧演示
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 functions.asm -o functions.o && ld functions.o -o functions
   ; 运行：./functions

.. literalinclude:: functions.asm
   :language: none
   :linenos:
