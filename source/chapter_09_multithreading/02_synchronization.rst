.. _chapter-09-sync:

===============================
同步原语
===============================

当多个线程共享数据时，必须使用同步机制防止数据竞争。本节介绍如何在汇编中实现各种同步原语。

互斥锁（Mutex）
==================

互斥锁确保同一时间只有一个线程可以进入临界区。最简单的实现基于原子 ``xchg`` 指令：

.. code-block:: none

   ; 自旋互斥锁实现
   section .data
       mutex dq 0                        ; 0 = 未锁定，1 = 已锁定

   section .text

   ; void mutex_lock(int *lock)
   mutex_lock:
       mov rax, 1                        ; 期望设置的值（已锁定）
   .spin:
       xchg rax, [rdi]                   ; 原子交换：rax ↔ *lock
       test rax, rax                     ; 检查原来的值
       jz   .acquired                    ; 原来是 0 → 成功获取锁
       pause                              ; 等待提示（避免忙等风暴）
       mov rax, 1                        ; 恢复 rax = 1
       jmp  .spin                        ; 继续旋转等待
   .acquired:
       ret

   ; void mutex_unlock(int *lock)
   mutex_unlock:
       mov qword [rdi], 0                ; 解锁（普通 store 即可，因为只有拥有者才解锁）
       ret

使用示例：

.. code-block:: none

   section .data
       shared_counter dq 0
       counter_lock   dq 0

   section .text
       ; 安全自增共享计数器
       mov rdi, counter_lock
       call mutex_lock

       ; 临界区开始
       inc qword [shared_counter]
       ; 临界区结束

       mov rdi, counter_lock
       call mutex_unlock

.. note::

   ``pause`` 指令（PAUSE）在自旋锁中非常重要。它在等待时向 CPU 提示这是一个自旋循环，
   CPU 可以优化流水线，减少功耗和总线竞争。

自旋锁（Spinlock）
=====================

自旋锁是最简单的锁形式——线程在获取锁之前一直忙等。适用于锁持有时间极短的场景。

.. code-block:: none

   ; 使用 cmpxchg 实现的自旋锁（比 xchg 版本快一些）
   section .data
       spinlock dq 0                     ; 0 = 未锁定

   section .text

   ; void spin_lock(int *lock)
   spin_lock:
       mov rax, 0                        ; 期望值（未锁定）
       mov rcx, 1                        ; 新值（锁定）
   .spin:
       lock cmpxchg [rdi], rcx           ; 原子比较并交换
       je   .acquired                    ; 如果 *lock == 0（期望值），则锁定成功
       pause                              ; 避免总线风暴
       mov rax, 0                        ; 重置期望值
       jmp  .spin
   .acquired:
       ret

   ; void spin_unlock(int *lock)
   spin_unlock:
       mov qword [rdi], 0                ; 释放锁
       ret

.. warning::

   自旋锁在单核 CPU 上**不能工作**——持有锁的线程被调度走时，等待的线程会永远旋转下去。
   在多核系统上，也要避免长时间持有自旋锁。

读写锁（Read-Write Lock）
============================

读写锁允许多个读者同时访问，但写者独占：

.. code-block:: none

   ; 简单读写锁：高 32 位 = 写者标记，低 32 位 = 读者计数
   ; 状态值：0 = 自由，0xFFFFFFFF00000000 = 写者锁定，N = N 个读者
   section .data
       rwlock dq 0

   ; 读者获取锁
   read_lock:
   .retry:
       mov rax, [rdi]
       test rax, rax                      ; 检查是否有写者
       js   .retry                        ; 有写者，重试
       inc qword [rdi]                   ; 读者计数 +1
       ret

   ; 读者释放锁
   read_unlock:
       dec qword [rdi]                   ; 读者计数 -1
       ret

   ; 写者获取锁
   write_lock:
       mov rax, [rdi]
       test rax, rax
       jnz  .wait                        ; 有任何读者或写者，等待
       ; 在实际实现中，应该使用 CAS 来设置写者标记
       ret

信号量（Semaphore）
=====================

信号量是一个计数器，支持 P（等待）和 V（释放）操作：

.. code-block:: none

   ; 信号量实现
   section .data
       sem_value dq 2                    ; 初始值为 2（最多允许 2 个线程）

   section .text

   ; void sem_wait(int *sem)——P 操作
   sem_wait:
   .retry:
       mov rax, [rdi]
       test rax, rax
       jz   .wait                        ; 值为 0，等待
       ; 尝试原子递减
       mov rax, 1
       lock xadd [rdi], rax              ; rax = *sem; *sem += 1
       dec rax                           ; 原子递减
       lock xadd [rdi], rax              ; rax = *sem; *sem += rax
       ; （简化实现，实际应该用 futex 避免忙等）
       ret
   .wait:
       pause
       jmp .retry

   ; void sem_post(int *sem)——V 操作
   sem_post:
       lock inc qword [rdi]              ; 原子递增
       ret

使用 futex 实现高效锁
=========================

自旋锁在争用激烈的场景下浪费 CPU 时间。高效的实现应该自旋几次，如果仍获取不到就通过 futex 休眠：

.. code-block:: none

   ; futex 系统调用号
   SYS_FUTEX      equ 202
   FUTEX_WAIT     equ 0
   FUTEX_WAKE     equ 1

   ; 基于 futex 的互斥锁
   ; 锁状态：0=自由，1=已锁定（无等待者），2=已锁定（有等待者）
   section .data
       futex_mutex dq 0

   ; 尝试获取锁
   futex_lock:
       mov rax, 0                         ; 期望值（自由）
       mov rcx, 1                         ; 新值（锁定，无等待者）
       lock cmpxchg [rdi], rcx
       je  .acquired                      ; 成功获取

       ; 锁被占用，需要等待
   .contend:
       cmp qword [rdi], 2                 ; 已标记为有等待者？
       mov rax, 2
       xchg rax, [rdi]                   ; 设置为 2（有等待者）

       ; 调用 futex_wait
       mov rdi, futex_mutex
       mov rsi, FUTEX_WAIT
       mov rdx, 2                         ; 期望值 = 2
       mov r10, 0                         ; 无超时
       mov rax, SYS_FUTEX
       syscall

       ; 被唤醒后，再次尝试获取
       mov rax, 0
       mov rcx, 2
       lock cmpxchg [rdi], rcx
       jne .contend

   .acquired:
       ret

   ; 释放锁
   futex_unlock:
       ; 如果状态从 1→0，无需唤醒等待者
       mov rax, 1
       mov rcx, 0
       lock cmpxchg [rdi], rcx
       je  .done

       ; 有等待者，设置为 0 并唤醒
       mov qword [rdi], 0
       mov rdi, futex_mutex
       mov rsi, FUTEX_WAKE
       mov rdx, 1                         ; 唤醒 1 个线程
       mov rax, SYS_FUTEX
       syscall
   .done:
       ret

.. tip::

   实际的 ``pthread_mutex`` 实现比上述示例复杂得多，但核心思想相同：
   先尝试在用户态获取（快速路径），失败后再陷入内核（慢速路径）。
   这种 "两阶段锁" 策略平衡了低争用场景的性能和高争用场景的 CPU 利用率。
