
#include <stdio.h>
#include <stdint.h>

#include "nvic.h"
#include "drv_usart.h"
#include "delay.h"
#include "usart.h"
#include "soc.h"
#include "gpio.h"

/*
 * TEST_STAGE:
 * 1 = only read I2S status/level
 * 3 = read I2S DATA and write to SDRAM address space
 */
#define TEST_STAGE 3

#define SRAM_CAPTURE_BASE       (0x00004000UL)
#define CAPTURE_WORDS           (256UL)

volatile uint32_t dbg_status;
volatile uint32_t dbg_level;
volatile uint32_t dbg_sample;
volatile uint32_t dbg_done;
volatile uint32_t dbg_overflow_count;

static void audio_i2s_start(uint32_t capture_right)
{
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_FIFO_CLEAR;
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_OVF_CLEAR;

    /*
     * capture_right:
     * 0 = left slot
     * 1 = right slot
     */
    AUDIO_I2S_CONFIG = capture_right ? 1UL : 0UL;
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_ENABLE;
}

static uint32_t audio_i2s_read_blocking(void)
{
    while (AUDIO_I2S_STATUS & AUDIO_I2S_STATUS_EMPTY) {
        dbg_status = AUDIO_I2S_STATUS;
        dbg_level = AUDIO_I2S_FIFO_LEVEL;
    }

    return AUDIO_I2S_DATA;
}

int main(void)
{
    uint32_t i;
    volatile uint32_t *dst;

    dbg_done = 0UL;
    dbg_overflow_count = 0UL;

    /*
     * ModelSim test.v drives left-slot sample data, so use capture_right = 0.
     * If real INMP441 L/R pin selects right channel on board, change to 1.
     */
    audio_i2s_start(0UL);

#if (TEST_STAGE == 1)
    while (1) {
        dbg_status = AUDIO_I2S_STATUS;
        dbg_level = AUDIO_I2S_FIFO_LEVEL;

        if (dbg_status & AUDIO_I2S_STATUS_OVERFLOW) {
            dbg_overflow_count++;
            AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_ENABLE | AUDIO_I2S_CTRL_OVF_CLEAR;
        }
    }

#elif (TEST_STAGE == 2)
    dst = (volatile uint32_t *)SRAM_CAPTURE_BASE;

    for (i = 0UL; i < CAPTURE_WORDS; i++) {
        dbg_sample = audio_i2s_read_blocking();
        dst[i] = dbg_sample;
    }

    dbg_done = 0x22222222UL;

    while (1) {
    }

#elif (TEST_STAGE == 3)
    dst = (volatile uint32_t *)SDRAM_BASE;

    for (i = 0UL; i < CAPTURE_WORDS; i++) {
        dbg_sample = audio_i2s_read_blocking();
        dst[i] = dbg_sample;
    }

    dbg_done = 0x33333333UL;

    while (1) {
    }
#endif
}