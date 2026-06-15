.. _example-registers:

==========================
寄存器操作演示
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 registers.asm -o registers.o && ld registers.o -o registers
   ; 运行：./registers

.. literalinclude:: registers.asm
   :language: none
   :linenos:
