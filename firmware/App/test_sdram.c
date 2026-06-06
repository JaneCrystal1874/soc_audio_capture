#include <stdint.h>

#include "soc.h"

/*
 * SDRAM 独立验证程序。
 *
 * 使用方法：
 * 1. 在 Keil 工程里临时把 main.c 从编译中移除，加入本文件；
 * 2. Build 后生成 firmware/prj/keil/output/outfile.bin；
 * 3. 在 ModelSim 中运行 arm-soc/run_sdram_model.do；
 * 4. 观察 g_sdram_test_status：
 *      0x1234ABCD = 测试通过
 *      0xDEADxxxx = 测试失败，低 16 bit 为失败步骤编号
 *
 * 注意：本文件自带 main()，不要和 App/main.c 同时编译。
 */

#define SDRAM_TEST_WORDS        (64UL)
#define SDRAM_TEST_BASE_OFFSET  (0x00000000UL)

/*
 * 0 = 只验证 CPU 写 SDRAM，ModelSim testbench 直接检查 SDRAM model 内存；
 * 1 = 软件再从 SDRAM 读回比较。读回会受到 SDRAM model CAS/相位实现影响。
 */
#define SDRAM_TEST_ENABLE_READBACK  (0UL)

/* 固定 SRAM 调试区。当前 scatter 中 0x4000-0x7FFF 可作为临时观察区。 */
#define DBG_BASE                (0x00004000UL)
#define DBG_STATUS              (*(volatile uint32_t *)(DBG_BASE + 0x00UL))
#define DBG_STEP                (*(volatile uint32_t *)(DBG_BASE + 0x04UL))
#define DBG_INDEX               (*(volatile uint32_t *)(DBG_BASE + 0x08UL))
#define DBG_ADDR                (*(volatile uint32_t *)(DBG_BASE + 0x0CUL))
#define DBG_EXPECTED            (*(volatile uint32_t *)(DBG_BASE + 0x10UL))
#define DBG_ACTUAL              (*(volatile uint32_t *)(DBG_BASE + 0x14UL))

#define SDRAM_STATUS_RUNNING    (0x11111111UL)
#define SDRAM_STATUS_WRITE_DONE (0x22222222UL)
#define SDRAM_STATUS_PASS       (0x1234ABCDUL)
#define SDRAM_STATUS_FAIL_BASE  (0xDEAD0000UL)

volatile uint32_t g_sdram_test_status = 0UL;
volatile uint32_t g_sdram_test_step = 0UL;
volatile uint32_t g_sdram_test_index = 0UL;
volatile uint32_t g_sdram_test_addr = 0UL;
volatile uint32_t g_sdram_expected = 0UL;
volatile uint32_t g_sdram_actual = 0UL;

static void update_debug_block(void)
{
    /*
     * status 最后写。
     * testbench 会根据 status 判断 PASS/FAIL；如果先写 status，
     * ModelSim 可能在 step/index/expected/actual 写完前就停下。
     */
    DBG_STEP = g_sdram_test_step;
    DBG_INDEX = g_sdram_test_index;
    DBG_ADDR = g_sdram_test_addr;
    DBG_EXPECTED = g_sdram_expected;
    DBG_ACTUAL = g_sdram_actual;
    DBG_STATUS = g_sdram_test_status;
}

static void sdram_write_word(uint32_t offset, uint32_t data)
{
    volatile uint32_t *addr = (volatile uint32_t *)(SDRAM_BASE + offset);
    *addr = data;
}

static uint32_t sdram_read_word(uint32_t offset)
{
    volatile uint32_t *addr = (volatile uint32_t *)(SDRAM_BASE + offset);
    return *addr;
}

static uint32_t make_pattern(uint32_t index)
{
    return 0xA5A50000UL ^ (index * 0x00010203UL) ^ index;
}

static void fail(uint32_t step, uint32_t index, uint32_t offset,
                 uint32_t expected, uint32_t actual)
{
    g_sdram_test_step = step;
    g_sdram_test_index = index;
    g_sdram_test_addr = SDRAM_BASE + offset;
    g_sdram_expected = expected;
    g_sdram_actual = actual;
    g_sdram_test_status = SDRAM_STATUS_FAIL_BASE | (step & 0xFFFFUL);
    update_debug_block();

    while (1) {
    }
}

static void sdram_linear_pattern_test(void)
{
    uint32_t i;
    uint32_t offset;
    uint32_t expected;
    uint32_t actual;

    g_sdram_test_step = 1UL;

    for (i = 0UL; i < SDRAM_TEST_WORDS; i++) {
        offset = SDRAM_TEST_BASE_OFFSET + (i * 4UL);
        expected = make_pattern(i);
        sdram_write_word(offset, expected);
    }

    g_sdram_test_step = 0x100UL;
    g_sdram_test_status = SDRAM_STATUS_WRITE_DONE;
    update_debug_block();

#if (SDRAM_TEST_ENABLE_READBACK == 0UL)
    while (1) {
    }
#endif

    g_sdram_test_step = 2UL;

    for (i = 0UL; i < SDRAM_TEST_WORDS; i++) {
        offset = SDRAM_TEST_BASE_OFFSET + (i * 4UL);
        expected = make_pattern(i);
        actual = sdram_read_word(offset);

        if (actual != expected) {
            fail(2UL, i, offset, expected, actual);
        }
    }
}

static void sdram_selected_address_test(void)
{
    static const uint32_t offsets[] = {
        0x00000000UL,
        0x00000004UL,
        0x00000008UL,
        0x000000FCUL,
        0x00000400UL,
        0x00001000UL,
        0x00004000UL,
        0x00010000UL
    };

    static const uint32_t patterns[] = {
        0x00000000UL,
        0xFFFFFFFFUL,
        0x5555AAAAUL,
        0xAAAA5555UL,
        0x12345678UL,
        0x87654321UL,
        0xCAFEBABEUL,
        0x0BADF00DUL
    };

    uint32_t i;
    uint32_t actual;

    g_sdram_test_step = 3UL;

    for (i = 0UL; i < (sizeof(offsets) / sizeof(offsets[0])); i++) {
        sdram_write_word(offsets[i], patterns[i]);
    }

    g_sdram_test_step = 4UL;

    for (i = 0UL; i < (sizeof(offsets) / sizeof(offsets[0])); i++) {
        actual = sdram_read_word(offsets[i]);

        if (actual != patterns[i]) {
            fail(4UL, i, offsets[i], patterns[i], actual);
        }
    }
}

int main(void)
{
    g_sdram_test_status = SDRAM_STATUS_RUNNING;
    update_debug_block();

    sdram_linear_pattern_test();
    sdram_selected_address_test();

    g_sdram_test_step = 0xFFFFUL;
    g_sdram_test_status = SDRAM_STATUS_PASS;
    update_debug_block();

    while (1) {
    }
}
