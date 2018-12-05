
#include <rtthread.h>
#include <rtconfig.h>
#include <rtservice.h>

rt_list_t	rt_thread_priority_table[RT_THREAD_PRIORITY_MAX];



struct rt_thread *rt_current_thread;




/**
 * @ingroup	SystemInit
 * This function will initialize the system scheduler
 *
 */
void rt_system_scheduler_init(void)
{
		//定义一个局部变量, 用 C 语言关键字 register 修饰, 防止被编译器优化
		register rt_base_t offset;

	
		/* 线程就绪列表初始化 */
		for (offset = 0; offset < RT_THREAD_PRIORITY_MAX; offset ++) {
			rt_list_init(&rt_thread_priority_table[offset]);
		}

		/* 初始化当前线程控制块指针 */
		rt_current_thread = RT_NULL;
}
 

/**
 * @ingroup SystemInit
 * This function will startup scheduler, It will select one thread
 * with the highest priority level, then switch to it
 *
 */
void rt_system_scheduler_start(void)
{
		register	struct rt_thread *to_thread;
		
	  /* 手动指定第一个运行的线程 */
		to_thread = rt_list_entry(rt_thread_priority_table[0].next, 
															struct rt_thread,
															tlist);
															
		rt_current_thread = to_thread;													

		/* 切换到第一个线程, 该函数在 context_rvds.S 中实现, 
			 在 rthw.h 声明, 用于实现第一次线程切换.
       当一个汇编函数在 C 文件中调用的时候, 如果有形参, 
       则执行的时候将形参传入到CPU寄存器 r0. */															
		rt_hw_context_switch_to((rt_uint32_t)&to_thread->sp);													
}


/* 系统调度 */
void rt_schedule(void)
{
		struct rt_thread *to_thread;
		struct rt_thread *from_thread;

		if (rt_current_thread == rt_list_entry(rt_thread_priority_table[0].next,
																					 struct rt_thread,
																					tlist)) {
				from_thread = rt_current_thread;
				to_thread	= rt_list_entry(rt_thread_priority_table[1].next,
																					 struct rt_thread,
																					tlist);													

				rt_current_thread = to_thread;																																				
		} 
		else {
		
				from_thread = rt_current_thread;
				to_thread	= rt_list_entry(rt_thread_priority_table[0].next,
																					 struct rt_thread,
																					tlist);													

				rt_current_thread = to_thread;		
		}																			
	
		/* 产生上下文切换 */
		rt_hw_context_switch((rt_uint32_t)&from_thread->sp, (rt_uint32_t)&to_thread->sp);
}



