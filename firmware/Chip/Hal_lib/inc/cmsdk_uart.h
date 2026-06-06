#ifndef __CMSDK_UART_H
#define __CMSDK_UART_H

#include <stdint.h>
#include "soc.h"

/*
 * 当前 arm-soc/apb/apb_subsystem.v 中：
 *   UART1 -> APB PORT5 -> 0x4000_5000
 *   UART2 -> APB PORT6 -> 0x4000_6000
 *
 * 注意：这里对应的是 arm-soc/apb/cmsdk_apb_uart.v，
 * 不要和原来的 DesignWare usart.c/usart.h 混用。
 */
#define CMSDK_UART1_BASE        (0x40005000UL)
#define CMSDK_UART2_BASE        (0x40006000UL)

#define CMSDK_UART_DEFAULT_BAUD (115200UL)
#define CMSDK_UART_TIMEOUT      (1000000UL)

typedef enum {
    CMSDK_UART_ID_1 = 1,
    CMSDK_UART_ID_2 = 2
} cmsdk_uart_id_t;

typedef struct {
    __IOM uint32_t DATA;        /* Offset 0x00: R RXD[7:0], W TXD[7:0] */
    __IOM uint32_t STATE;       /* Offset 0x04: STAT[3:0], W1C overrun flags */
    __IOM uint32_t CTRL;        /* Offset 0x08: CTRL[6:0] */
    __IOM uint32_t INTSTATUS;   /* Offset 0x0C: interrupt status, W1C */
    __IOM uint32_t BAUDDIV;     /* Offset 0x10: baud divider[19:0] */
} cmsdk_uart_reg_t;

/* STATE bits */
#define CMSDK_UART_STATE_TX_FULL        (1UL << 0)
#define CMSDK_UART_STATE_RX_FULL        (1UL << 1)
#define CMSDK_UART_STATE_TX_OVERRUN     (1UL << 2)
#define CMSDK_UART_STATE_RX_OVERRUN     (1UL << 3)

/* CTRL bits */
#define CMSDK_UART_CTRL_TX_ENABLE       (1UL << 0)
#define CMSDK_UART_CTRL_RX_ENABLE       (1UL << 1)
#define CMSDK_UART_CTRL_TX_INT_ENABLE   (1UL << 2)
#define CMSDK_UART_CTRL_RX_INT_ENABLE   (1UL << 3)
#define CMSDK_UART_CTRL_TX_OVR_INT_EN   (1UL << 4)
#define CMSDK_UART_CTRL_RX_OVR_INT_EN   (1UL << 5)
#define CMSDK_UART_CTRL_HS_TEST_MODE    (1UL << 6)

void cmsdk_uart_init(cmsdk_uart_id_t uart_id, uint32_t baudrate);
int32_t cmsdk_uart_putc(cmsdk_uart_id_t uart_id, uint8_t ch);
int32_t cmsdk_uart_getc(cmsdk_uart_id_t uart_id, uint8_t *ch);
int32_t cmsdk_uart_write(cmsdk_uart_id_t uart_id, const uint8_t *data, uint32_t len);
int32_t cmsdk_uart_read(cmsdk_uart_id_t uart_id, uint8_t *data, uint32_t len);
void cmsdk_uart_puts(cmsdk_uart_id_t uart_id, const char *str);
uint32_t cmsdk_uart_state(cmsdk_uart_id_t uart_id);

#endif
