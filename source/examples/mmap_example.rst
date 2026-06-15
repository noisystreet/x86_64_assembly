.. _example-mmap:

==========================
内存映射 (mmap) 演示
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 mmap_example.asm -o mmap_example.o && ld mmap_example.o -o mmap_example
   ; 运行：./mmap_example

.. literalinclude:: mmap_example.asm
   :language: none
   :linenos:
