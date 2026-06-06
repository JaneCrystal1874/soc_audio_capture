
#ifndef __GPIO_H
#define __GPIO_H

#include "soc.h"


// GPIO基地址修正：
// - APB子系统AHB基地址: 0x4000_0000
// - GPIO连接在APB PORT4，每个PORT偏移0x1000
// - 正确基地址 = 0x4000_0000 + 0x4000 = 0x4000_4000
#define GPIO_BASE       0x40004000u

#define GPIO   GPIO_BASE

// GPIO寄存器偏移（根据gpio_apbif.v中的定义）
// SWPORT_DR:    offset 0x00 (paddr[6:2] = 00000)
// SWPORT_DDR:   offset 0x04 (paddr[6:2] = 00001)  
// PORT_CTL:     offset 0x08 (paddr[6:2] = 00010)
// EXT_PORTA:    offset 0x50 (paddr[6:2] = 10100)
#define GPIO_DIR  	  (*(volatile unsigned int *)(GPIO_BASE + 0x04))  // 数据方向寄存器
#define GPIO_OUT	  (*(volatile unsigned int *)(GPIO_BASE + 0x00))  // 数据输出寄存器
#define GPIO_IN		  (*(volatile unsigned int *)(GPIO_BASE + 0x50))  // 外部端口读取

#define LED_PIN_OUT	(0xFF)      // GPIO全部8位作为控制（如果需要全部输出）
// 如果只需要低4位，保持 (0x0F)
#define LED_PIN_IN	(0x00)

#define LED_ON	    (0x0F)      // 4个LED全亮
#define LED_OFF	    (0x00)      // 4个LED全灭

#define LED0_ON     (0x01)      // LED0单独点亮


//全局路径定义
#ifdef  _GPIO_C_

#define GLOBAL
#else
#define GLOBAL extern
#endif

GLOBAL uint8_t led_num;





#undef GLOBAL


typedef struct {
    __IOM uint32_t SWPORT_DR;                     /* Offset: 0x000 (W/R)  PortA data register */
    __IOM uint32_t SWPORT_DDR;                    /* Offset: 0x004 (W/R)  PortA data direction register */
    __IOM uint32_t PORT_CTL;                      /* Offset: 0x008 (W/R)  PortA source register */

} dw_gpio_reg_t;



void gpio_init(void);
void led_blink(void);
void led_flow(void);




#endif


