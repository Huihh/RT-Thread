

#ifndef __RT_HW_H__
#define __RT_HW_H__


#include "rtthread.h"

#ifdef __cplusplus
extern "C" {
#endif

	
void rt_hw_context_switch_to(rt_ubase_t to);	
void rt_hw_context_switch(rt_ubase_t from, rt_ubase_t to);


#ifdef __cplusplus	
}
#endif


#endif




