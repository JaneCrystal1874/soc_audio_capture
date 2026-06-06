
#define _DELAY_C_

//#include "soc.h"
#include "delay.h"

//-------使用systick中断来做延时---------//

static __IO uint32_t msTicks;

// SysTick_Handler systick中断函数
//void SysTick_Handler()
//{
//	if(msTicks != 0){
//		msTicks --;
//	}
//	
//	uwTick ++;
////	if(usTicks != 0){
////		usTicks --;
////		msTicks ++;
////	}
//}

void HardFault_Handler()
{
	while(1);
}

void SysTick_Handler()
{
	if(msTicks != 0){
		msTicks --;
	}

	uwTick ++;
}

uint32_t GetTick(void)
{
	return uwTick;
}

//配置systick中断时间
void delay_init(void)
{
	// 1ms 定时中断，使用 Cortex-M3 内核自带 SysTick
	SysTick_Config(SYSTEM_CLOCK / 1000);
}

void SysTick_init()
{
	SysTick_Config(SYSTEM_CLOCK / 1000);
}

void delay_us(uint32_t us)
{
	/*
	 * 简单软件延时，保留给很短的等待使用。
	 * 精确毫秒延时请使用 delay_ms()，它由 SysTick 中断驱动。
	 */
	while(us--){
		__NOP();
	}
}

void delay_ms(uint16_t ms)
{
	msTicks = ms;
	
	while(msTicks);
	
//	while(ms --){
//		
//		delay_us(1000);
//	}
}


void Delay_ms(int tmp)
{
	int i; 
	
	for(i = 0; i < (tmp * 5000); i ++){
		
	}
}




