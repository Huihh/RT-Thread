


;************************************************************
;				ȫ�ֱ���
;************************************************************
; ʹ�� IMPORT �ؼ��ֵ���һЩȫ�ֱ���, �� 3 ��ȫ�ֱ����� cpuport.c �ж���
	IMPORT	rt_thread_switch_interrupt_flag
	IMPORT	rt_interrupt_from_thread
	IMPORT	rt_interrupt_to_thread
		
;************************************************************
;				����
;************************************************************

;/**
; * @addtogroup	cortex-m4
; *
; */
;/*@{*/

SCB_VTOR			EQU		0xE000ED08        ; ������ƫ�ƼĴ���
NVIC_INT_CTRL		EQU		0xE000ED04        ; �жϿ���״̬�Ĵ���
NVIC_SYSPRI2		EQU		0xE000ED20		  ; ϵͳ���ȼ��Ĵ��� (2)
NVIC_PENDSV_PRI		EQU		0x00FF0000		  ; PendSV ���ȼ�ֵ (lowest)
NVIC_PENDSVSET		EQU		0x10000000	      ; ���� PendSV �쳣��ֵ


;************************************************************
;				�������ָ��
;************************************************************
; AREA ��ʾ���һ���µ����ݶλ�����
; .text ��ʾ����, ���������������ĸ��ͷ, �������������ſ�ͷ����Ҫ�ڶ������߼��� '|'
; CODE ��ʾ����
; READONLY	��ʾֻ��
; ALIGN=2 ��ʾ��ǰ�ļ�ָ��Ҫ 2^2 �ֽڶ���
; THUMB	��ʾ THUMB ָ�����
; REUIRE8 �� PRESERVE8 ����ʾ��ǰ�ļ���ջ���� 8 �ֽڶ���
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
; PROC ���ڶ����ӳ���, �� ENDP �ɶ�ʹ��, ��ʾ rt_hw_context_switch_to() �����Ŀ�ʼ
rt_hw_context_switch_to		PROC
	
	; ���� rt_hw_context_switch_to, �������ȫ������, ������ C �ļ��е���
	EXPORT	rt_hw_context_switch_to

	; ���� rt_interrupt_to_thread ��ֵΪ r0 �е�ֵ
	; r0 ��ŵ�����һ����Ҫ���е��̵߳� sp �ĵ�ַ, �� rt_interrupt_switch_to((rt_uint32_t)&to_thread->sp)����ʱ���� r0 ��
	LDR		r1, = rt_interrupt_to_thread
	STR		r0, [r1]
	
	
	; ���� rt_interrupt_from_thread ��ֵΪ 0, ��ʾ������һ���߳��л�
	LDR		r1, = rt_interrupt_from_thread
	MOV		r0, #0x0
	STR		r0, [r1]
	
	
	; �����жϱ�־λ rt_thread_switch_interrupt_flag ��ֵΪ 1, ��ִ���� PendSVC Handler ʱ,  rt_thread_switch_interrupt_flag �ᱻ����
	LDR		r1, = rt_thread_switch_interrupt_flag
	MOV		r0, #1
	STR		r0, [r1]
	
	
	; ���� PendSV �쳣���ȼ� (�˴�����Ϊ������ȼ�)
	LDR		r0, = NVIC_SYSPRI2
	LDR		r1, = NVIC_PENDSV_PRI
	LDR.W	r2, [r0, #0x00]        ; ��
	ORR		r1, r1, r2             ; ��
	STR		r1, [r0]               ; д

 
	; ���� PendSV �쳣 (�����������л�)
	; ���ǰ�����, ��Ҫ���жϴ򿪲���ȥִ�� PendSV �жϷ�����
	LDR		r0, = NVIC_INT_CTRL
	LDR		r1, = NVIC_PENDSVSET
	STR		r1, [r0]

	; ���ж�
	CPSIE	F
	CPSIE	I	

	; ��Զ���ᵽ������
	; ENDP ���� rt_hw_context_switch_to �ӳ������, �� PROC �ɶ�ʹ��
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
	
	; ���� PendSV_Handler, �������ȫ������, ������ C �ļ��е���
	EXPORT	PendSV_Handler
	
	; �����ж����μĴ�����ֵ�� r2 ��, �ڽ���ʱ���ڻָ�
	; �����ж�, ��Ϊ�˱����������л������ж�
	MRS		r2, PRIMASK
	CPSID	I
	
	; ��ȡ�жϱ�־λ, �鿴�Ƿ�Ϊ 0, ���Ϊ 0 ���˳� PendSV_Handler, �����Ϊ 0 ���������ִ��
	LDR		r0, = rt_thread_switch_interrupt_flag
	LDR	  	r1, [r0]
	CBZ		r1, pendsv_exit
	
	
	; ����жϱ�־λ, ������ rt_thread_switch_interrupt_flag = 0
	MOV		r1, #0x00
	STR		r1, [r0]
	
	
	; �ж� rt_interrupt_from_thread ��ֵ�Ƿ�Ϊ 0, ���Ϊ 0, ���
	; ʾ��һ���߳��л�, ���������ı���, ֱ������ switch_to_thread ִ�������л�����,
	; ��Ϊ 0, ����Ҫ��ִ�����ı���, Ȼ���ٽ��������л�
	LDR		r0, = rt_interrupt_from_thread
	LDR		r1, [r0]
	CBZ		r1, switch_to_thread
		
; ========================== ���ı��� ========================	
; �����뵽 PendSV_Handler ʱ, ��һ���̵߳����л�������:
; xPSR, PC(�߳���ڵ�ַ), R14, R12, R3, R2, R1, R0(�̵߳��β�)
; ��Щ CPU �Ĵ�����ֵ���Զ����浽�̵߳�ջ��, ʣ�µ� R4~R11��Ҫ�ֶ�����

	;��ȡ�߳�ջָ�뵽 r1 ��, Ȼ�� r4~r11 ��ֵ�洢�� r1 ָ��ĵ�ַ(ÿ����һ�ε�ַ���ݼ�һ��)
	MRS		r1, psp
	STMFD	r1!, {r4 - r11}
	
	; ���� r0 ָ���ֵ�� r0 ��, �� r0 = rt_interrupt_from_thread
	; �� r1 ��ֵ�洢�� r0, �������߳�ջ sp
	LDR		r0, [r0]
	STR		r1, [r0]
		
		
; ========================== �����л� ========================			
switch_to_thread

	; ���� rt_interrupt_to_thread �ĵ�ַ�� r1
	; rt_interrupt_to_thread ��ȫ�ֱ���, ��ŵ����߳�ջָ�� sp ��ָ��
	; ��һ�μ��� rt_interrupt_to_thread ��ֵ�� r1 ��, ��ָ�� sp ��ָ��
	; �ڶ��μ��� rt_interrupt_to_thread ��ֵ�� r1 ��, ��ָ�� sp
	LDR		r1, = rt_interrupt_to_thread
	LDR		r1, [r1]
	LDR		r1, [r1]
		
	;���߳�ջָ�� r1 ָ������ݼ��ص� r4~r11, ����֮ǰ�ȵݼ�	
	LDMFD 	r1!, {r4 - r11}	
	
	; ���߳�ջָ����µ� PSP
	MSR		psp, r1	
		
		
pendsv_exit	

	;�ָ��ж����μĴ�����ֵ
	MSR PRIMASK, r2
		
	;ȷ���쳣����ʹ�õ�ջָ���� PSP, �� lr �Ĵ�����λ 2 ҪΪ 1	
	ORR lr, lr, #0x04	
		
	; �쳣����, ��ʱջ�е�ʣ�����ݻ��Զ����ص� CPU �Ĵ���
	; xPSR, PC(�߳���ڵ�ַ), R14, R12, R3, R2, R1, R0(�̵߳��β�)
	; ͬʱ PSP ��ֵҲ������, ��ָ���߳�ջ��ջ��
	BX  lr	
		
	; ENDP ���� PendSV_Handler �ӳ������, �� PROC �ɶ�ʹ��	
	ENDP




rt_hw_context_switch PROC
	
	; ���� rt_hw_context_switch, �������ȫ������, ������ C �ļ��е���
	EXPORT rt_hw_context_switch

	; �ȼ��� rt_thread_switch_interrupt_flag �ĵ�ַ�� r2, Ȼ���ټ�����ֵ�� r3	
	LDR		r2, = rt_thread_switch_interrupt_flag
	LDR		r3, [r2]
	
	; r3 �� 1 �Ƚ�, �����ִ�� BEQ ָ��, ����ִ��
	CMP		r3, #1
	BEQ		_reswitch
	
	; �����жϱ�־λ rt_thread_switch_interrupt_flag = 1
	MOV		r3, #1
	STR		r3, [r2]
	
	; ���� rt_interrupt_from_thread ��ֵΪ r0, ������ rt_interrupt_from_thread ��ֵΪ
	; ��һ���߳�ջָ�� sp ��ָ��
	LDR		r2, = rt_interrupt_from_thread
	STR		r0, [r2]

_reswitch

	; ���� rt_interrupt_to_thread ��ֵΪ r1, ������ rt_interrupt_to_thread ��ֵΪ
	; ��һ���߳�ջָ�� sp ��ָ��
	LDR		r2, = rt_interrupt_to_thread 
	STR		r1, [r2]
	
	;���� PendSV �쳣, ʵ���������л�
	LDR		r0, = NVIC_INT_CTRL
	LDR		r1, = NVIC_PENDSVSET
	              
	STR		r1, [r0]
	
	; �ӳ��򷵻�
	BX		LR
	
	;ENDP ���� rt_hw_context_switch �ӳ������, �� PROC �ɶ�ʹ��	
	ENDP

	

	; ��ǰ�ļ�ָ�����Ҫ�� 4 �ֽڶ���, ��Ȼ���о���
	ALIGN	4
	
	; ����ļ�����, ÿ������ļ�����Ҫһ�� END	
	END			
