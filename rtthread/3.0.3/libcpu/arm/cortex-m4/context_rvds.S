


;************************************************************
;				全局变量
;************************************************************
; 使用 IMPORT 关键字导入一些全局变量, 这 3 个全局变量在 cpuport.c 中定义
	IMPORT	rt_thread_switch_interrupt_flag
	IMPORT	rt_interrupt_from_thread
	IMPORT	rt_interrupt_to_thread
		
;************************************************************
;				常量
;************************************************************

;/**
; * @addtogroup	cortex-m4
; *
; */
;/*@{*/

SCB_VTOR			EQU		0xE000ED08        ; 向量表偏移寄存器
NVIC_INT_CTRL		EQU		0xE000ED04        ; 中断控制状态寄存器
NVIC_SYSPRI2		EQU		0xE000ED20		  ; 系统优先级寄存器 (2)
NVIC_PENDSV_PRI		EQU		0x00FF0000		  ; PendSV 优先级值 (lowest)
NVIC_PENDSVSET		EQU		0x10000000	      ; 触发 PendSV 异常的值


;************************************************************
;				代码产生指令
;************************************************************
; AREA 表示汇编一个新的数据段或代码段
; .text 表示段名, 如果段名不是以字母开头, 而是以其它符号开头则需要在段名两边加上 '|'
; CODE 表示代码
; READONLY	表示只读
; ALIGN=2 表示当前文件指令要 2^2 字节对齐
; THUMB	表示 THUMB 指令代码
; REUIRE8 和 PRESERVE8 均表示当前文件的栈按照 8 字节对齐
	AREA |.text|, CODE, READONLY, ALIGN=2
	THUMB
	REQUIRE8
	PRESERVE8

;/**
; * void rt_hw_context_switch_to(rt_uint32 to);
; * r0 --> to
; * this function is used to perform the first thread switch
; *
; */
; PROC 用于定义子程序, 与 ENDP 成对使用, 表示 rt_hw_context_switch_to() 函数的开始
rt_hw_context_switch_to		PROC
	
	; 导出 rt_hw_context_switch_to, 让其具有全局属性, 可以在 C 文件中调用
	EXPORT	rt_hw_context_switch_to

	; 设置 rt_interrupt_to_thread 的值为 r0 中的值
	; r0 存放的是下一个将要运行的线程的 sp 的地址, 由 rt_interrupt_switch_to((rt_uint32_t)&to_thread->sp)调用时传到 r0 中
	LDR		r1, = rt_interrupt_to_thread
	STR		r0, [r1]
	
	
	; 设置 rt_interrupt_from_thread 的值为 0, 表示启动第一次线程切换
	LDR		r1, = rt_interrupt_from_thread
	MOV		r0, #0x0
	STR		r0, [r1]
	
	
	; 设置中断标志位 rt_thread_switch_interrupt_flag 的值为 1, 当执行了 PendSVC Handler 时,  rt_thread_switch_interrupt_flag 会被清零
	LDR		r1, = rt_thread_switch_interrupt_flag
	MOV		r0, #1
	STR		r0, [r1]
	
	
	; 设置 PendSV 异常优先级 (此处设置为最低优先级)
	LDR		r0, = NVIC_SYSPRI2
	LDR		r1, = NVIC_PENDSV_PRI
	LDR.W	r2, [r0, #0x00]        ; 读
	ORR		r1, r1, r2             ; 改
	STR		r1, [r0]               ; 写

 
	; 触发 PendSV 异常 (产生上下文切换)
	; 如果前面关了, 还要等中断打开才能去执行 PendSV 中断服务函数
	LDR		r0, = NVIC_INT_CTRL
	LDR		r1, = NVIC_PENDSVSET
	STR		r1, [r0]

	; 开中断
	CPSIE	F
	CPSIE	I	

	; 永远不会到达这里
	; ENDP 代表 rt_hw_context_switch_to 子程序结束, 与 PROC 成对使用
	ENDP
		
		
;/**
; *----------------------------------------------------------------------
; * void PendSV_Handler(void);
; * r0 --> switch from thread stack
; * r1 --> switch to thread stack
; * psr, pc, lr, r12, r3, r2, r1, r0 are pushed into [from] stack
; *----------------------------------------------------------------------
; */
PendSV_Handler		PROC
	
	; 导出 PendSV_Handler, 让其具有全局属性, 可以在 C 文件中调用
	EXPORT	PendSV_Handler
	
	; 保存中断屏蔽寄存器的值到 r2 中, 在结束时用于恢复
	; 除能中断, 是为了保护上下文切换不被中断
	MRS		r2, PRIMASK
	CPSID	I
	
	; 获取中断标志位, 查看是否为 0, 如果为 0 则退出 PendSV_Handler, 如果不为 0 则继续往下执行
	LDR		r0, = rt_thread_switch_interrupt_flag
	LDR	  	r1, [r0]
	CBZ		r1, pendsv_exit
	
	
	; 清除中断标志位, 即设置 rt_thread_switch_interrupt_flag = 0
	MOV		r1, #0x00
	STR		r1, [r0]
	
	
	; 判断 rt_interrupt_from_thread 的值是否为 0, 如果为 0, 则表
	; 示第一次线程切换, 不用做上文保存, 直接跳到 switch_to_thread 执行下文切换即可,
	; 不为 0, 则需要先执行上文保存, 然后再进行下文切换
	LDR		r0, = rt_interrupt_from_thread
	LDR		r1, [r0]
	CBZ		r1, switch_to_thread
		
; ========================== 上文保存 ========================	
; 当进入到 PendSV_Handler 时, 上一个线程的运行环境如下:
; xPSR, PC(线程入口地址), R14, R12, R3, R2, R1, R0(线程的形参)
; 这些 CPU 寄存器的值会自动保存到线程的栈中, 剩下的 R4~R11需要手动保存

	;获取线程栈指针到 r1 中, 然后将 r4~r11 的值存储到 r1 指向的地址(每操作一次地址将递减一次)
	MRS		r1, psp
	STMFD	r1!, {r4 - r11}
	
	; 加载 r0 指向的值到 r0 中, 即 r0 = rt_interrupt_from_thread
	; 将 r1 的值存储到 r0, 即更新线程栈 sp
	LDR		r0, [r0]
	STR		r1, [r0]
		
		
; ========================== 下文切换 ========================			
switch_to_thread

	; 加载 rt_interrupt_to_thread 的地址到 r1
	; rt_interrupt_to_thread 是全局变量, 存放的是线程栈指针 sp 的指针
	; 第一次加载 rt_interrupt_to_thread 的值到 r1 中, 即指针 sp 的指针
	; 第二次加载 rt_interrupt_to_thread 的值到 r1 中, 即指针 sp
	LDR		r1, = rt_interrupt_to_thread
	LDR		r1, [r1]
	LDR		r1, [r1]
		
	;将线程栈指针 r1 指向的内容加载到 r4~r11, 操作之前先递减	
	LDMFD 	r1!, {r4 - r11}	
	
	; 将线程栈指针更新到 PSP
	MSR		psp, r1	
		
		
pendsv_exit	

	;恢复中断屏蔽寄存器的值
	MSR PRIMASK, r2
		
	;确保异常返回使用的栈指针是 PSP, 即 lr 寄存器的位 2 要为 1	
	ORR lr, lr, #0x04	
		
	; 异常返回, 这时栈中的剩余内容会自动加载到 CPU 寄存器
	; xPSR, PC(线程入口地址), R14, R12, R3, R2, R1, R0(线程的形参)
	; 同时 PSP 的值也将更新, 即指向线程栈的栈顶
	BX  lr	
		
	; ENDP 代表 PendSV_Handler 子程序结束, 与 PROC 成对使用	
	ENDP




rt_hw_context_switch PROC
	
	; 导出 rt_hw_context_switch, 让其具有全局属性, 可以在 C 文件中调用
	EXPORT rt_hw_context_switch

	; 先加载 rt_thread_switch_interrupt_flag 的地址到 r2, 然后再加载其值到 r3	
	LDR		r2, = rt_thread_switch_interrupt_flag
	LDR		r3, [r2]
	
	; r3 与 1 比较, 相等则执行 BEQ 指令, 否则不执行
	CMP		r3, #1
	BEQ		_reswitch
	
	; 设置中断标志位 rt_thread_switch_interrupt_flag = 1
	MOV		r3, #1
	STR		r3, [r2]
	
	; 设置 rt_interrupt_from_thread 的值为 r0, 即设置 rt_interrupt_from_thread 的值为
	; 上一个线程栈指针 sp 的指针
	LDR		r2, = rt_interrupt_from_thread
	STR		r0, [r2]

_reswitch

	; 设置 rt_interrupt_to_thread 的值为 r1, 即设置 rt_interrupt_to_thread 的值为
	; 下一个线程栈指针 sp 的指针
	LDR		r2, = rt_interrupt_to_thread 
	STR		r1, [r2]
	
	;触发 PendSV 异常, 实现上下文切换
	LDR		r0, = NVIC_INT_CTRL
	LDR		r1, = NVIC_PENDSVSET
	              
	STR		r1, [r0]
	
	; 子程序返回
	BX		LR
	
	;ENDP 代表 rt_hw_context_switch 子程序结束, 与 PROC 成对使用	
	ENDP

	

	; 当前文件指令代码要求 4 字节对齐, 不然会有警告
	ALIGN	4
	
	; 汇编文件结束, 每个汇编文件都需要一个 END	
	END			

