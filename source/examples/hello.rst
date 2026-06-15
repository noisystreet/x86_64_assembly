.. _example-hello:

==========================
Hello World 程序
==========================

.. code-block:: none

   ; 编译：nasm -f elf64 hello.asm -o hello.o && ld hello.o -o hello
   ; 运行：./hello

.. literalinclude:: hello.asm
   :language: none
   :linenos:
