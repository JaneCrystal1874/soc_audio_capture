#include "cmsdk_uart.h"

static cmsdk_uart_reg_t *cmsdk_uart_get_regs(cmsdk_uart_id_t uart_id)
{
    if (uart_id == CMSDK_UART_ID_2) {
        return (cmsdk_uart_reg_t *)CMSDK_UART2_BASE;
    }

    return (cmsdk_uart_reg_t *)CMSDK_UART1_BASE;
}

static uint32_t cmsdk_uart_make_bauddiv(uint32_t baudrate)
{
    uint32_t div;

    if (baudrate == 0UL) {
        baudrate = CMSDK_UART_DEFAULT_BAUD;
    }

    /*
     * cmsdk_apb_uart 的 BAUDDIV 是 PCLK / baudrate。
     * RTL 要求最小值为 16；SYSTEM_CLOCK 当前作为 PCLK 使用。
     */
    div = (SYSTEM_CLOCK + (baudrate / 2UL)) / baudrate;
    if (div < 16UL) {
        div = 16UL;
    }

    return div;
}

void cmsdk_uart_init(cmsdk_uart_id_t uart_id, uint32_t baudrate)
{
    cmsdk_uart_reg_t *uart = cmsdk_uart_get_regs(uart_id);

    /*
     * 初始化顺序：
     * 1. 先关闭 TX/RX；
     * 2. 清 overrun 和中断状态；
     * 3. 配置波特率；
     * 4. 打开 TX/RX。
     */
    uart->CTRL = 0UL;
    uart->STATE = CMSDK_UART_STATE_TX_OVERRUN | CMSDK_UART_STATE_RX_OVERRUN;
    uart->INTSTATUS = 0x0FUL;
    uart->BAUDDIV = cmsdk_uart_make_bauddiv(baudrate);
    uart->CTRL = CMSDK_UART_CTRL_TX_ENABLE | CMSDK_UART_CTRL_RX_ENABLE;
}

int32_t cmsdk_uart_putc(cmsdk_uart_id_t uart_id, uint8_t ch)
{
    cmsdk_uart_reg_t *uart = cmsdk_uart_get_regs(uart_id);
    uint32_t timeout = CMSDK_UART_TIMEOUT;

    while ((uart->STATE & CMSDK_UART_STATE_TX_FULL) != 0UL) {
        if (timeout-- == 0UL) {
            return -1;
        }
    }

    uart->DATA = (uint32_t)ch;
    return 0;
}

int32_t cmsdk_uart_getc(cmsdk_uart_id_t uart_id, uint8_t *ch)
{
    cmsdk_uart_reg_t *uart = cmsdk_uart_get_regs(uart_id);
    uint32_t timeout = CMSDK_UART_TIMEOUT;

    if (ch == (uint8_t *)0) {
        return -1;
    }

    while ((uart->STATE & CMSDK_UART_STATE_RX_FULL) == 0UL) {
        if (timeout-- == 0UL) {
            return -1;
        }
    }

    *ch = (uint8_t)(uart->DATA & 0xFFUL);
    return 0;
}

int32_t cmsdk_uart_write(cmsdk_uart_id_t uart_id, const uint8_t *data, uint32_t len)
{
    uint32_t i;

    if (data == (const uint8_t *)0) {
        return -1;
    }

    for (i = 0UL; i < len; i++) {
        if (cmsdk_uart_putc(uart_id, data[i]) < 0) {
            return -1;
        }
    }

    return 0;
}

int32_t cmsdk_uart_read(cmsdk_uart_id_t uart_id, uint8_t *data, uint32_t len)
{
    uint32_t i;

    if (data == (uint8_t *)0) {
        return -1;
    }

    for (i = 0UL; i < len; i++) {
        if (cmsdk_uart_getc(uart_id, &data[i]) < 0) {
            return -1;
        }
    }

    return 0;
}

void cmsdk_uart_puts(cmsdk_uart_id_t uart_id, const char *str)
{
    if (str == (const char *)0) {
        return;
    }

    while (*str != '\0') {
        if (*str == '\n') {
            (void)cmsdk_uart_putc(uart_id, (uint8_t)'\r');
        }

        (void)cmsdk_uart_putc(uart_id, (uint8_t)*str);
        str++;
    }
}

uint32_t cmsdk_uart_state(cmsdk_uart_id_t uart_id)
{
    cmsdk_uart_reg_t *uart = cmsdk_uart_get_regs(uart_id);

    return uart->STATE;
}
