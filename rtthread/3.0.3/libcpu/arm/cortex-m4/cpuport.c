
#include <rtthread.h>

/* 用于存储上一个线程栈的 sp 的指针 */
rt_uint32_t	rt_interrupt_from_thread;

/* 用于存储下一个将要运行的线程的栈的 sp 的指针 */
rt_uint32_t rt_interrupt_to_thread;

/* PendSV 中断服务函数执行标志 */
rt_uint32_t	rt_thread_switch_interrupt_flag;








struct exception_stack_frame
{
		/* 异常发生时, 自动加载到 CPU 寄存器的内容 */
		rt_uint32_t		r0;
		rt_uint32_t		r1;
		rt_uint32_t		r2;
		rt_uint32_t		r3;
		rt_uint32_t		r12;
		rt_uint32_t		lr;
		rt_uint32_t		pc;
		rt_uint32_t		psr;
};




struct stack_frame
{

		/* 异常发生时, 需手动加载到 CPU 寄存器的内容 */
		rt_uint32_t		r4;
		rt_uint32_t		r5;
		rt_uint32_t		r6;
		rt_uint32_t		r7;
		rt_uint32_t		r8;
		rt_uint32_t		r9;
		rt_uint32_t		r10;
		rt_uint32_t		r11;
	
		struct exception_stack_frame	exception_stack_frame;
};





rt_uint8_t *rt_hw_stack_init(void 				*tentry,
														 void      		*parameter,
														 rt_uint8_t 	*stack_addr)
{
		struct stack_frame  *stack_frame;
		rt_uint8_t					*stk;
		unsigned long				i;
	
		/* 获取栈顶指针
			rt_hw_stack_init 在调用的时候, 传递给 stack_addr 的时候 (栈顶指针 - 4)	*/
		stk = stack_addr + sizeof(rt_uint32_t);
	
		/* 让 stk 指针向下 8 字节对齐 */
		stk = (rt_uint8_t *)RT_ALIGN_DOWN((rt_uint32_t)stk, 8);
	
		/* stk 继续向下移动 sizeof(struct stack_frame) 个偏移 */
		stk -= sizeof(struct stack_frame);
	
		/* 将 stk 强制转换成 stack_frame 类型的指针后存放在指针 stack_frame 中 */
		stack_frame = (struct stack_frame *)stk;

		/* 以 stack_frame 为起始地址, 将栈空间里面的 sizeof(struct stack_frame)
		个内存初始化为 0xdeabbeef */
		for (i = 0; i < sizeof(struct stack_frame)/sizeof(rt_uint32_t); i++) {
				((rt_uint32_t *)stack_frame)[i] = 0xdeabbeef;
		}
	
		stack_frame->exception_stack_frame.r0 = (unsigned long)parameter;     /* r0: argument */
		stack_frame->exception_stack_frame.r1 = 0;                            /* r1 */
		stack_frame->exception_stack_frame.r2 = 0;                            /* r2 */
		stack_frame->exception_stack_frame.r3 = 0;                            /* r3 */
		stack_frame->exception_stack_frame.r12 = 0;	                          /* r12 */
		stack_frame->exception_stack_frame.lr = 0;                            /* lr: 暂时初始化为 0 */
		stack_frame->exception_stack_frame.pc = (unsigned long)tentry;		    /* entry point, pc */
		stack_frame->exception_stack_frame.psr = 0x01000000L;                 /* PSR */
		
		/* 返回线程指针 */
		return stk;
}





