#include <stdint.h>
#include "soc.h"
#include "gpio.h"
#include "delay.h"

#define KEY0_PIN (0x10)
#define KEY0Pressed() ((GPIO_IN & KEY0_PIN) == 0)

#define SW1_ADPCM_PIN     (0x02)
#define SW1AdpcmMode()    ((GPIO_IN & SW1_ADPCM_PIN) != 0)

#define RECORD_LED_PIN    (0x01)
#define ADPCM_LED_PIN     (0x04)
#define LEDS_SET(value)   (GPIO_OUT = (value))
#define ADPCM_LED_VALUE() (SW1AdpcmMode() ? ADPCM_LED_PIN : 0UL)

#define I2S_HCLK_HZ                 (SYSTEM_CLOCK)
#define I2S_SCK_HALF_PERIOD         (16UL)
#define I2S_BITS_PER_STEREO_FRAME   (64UL)
#define I2S_SAMPLE_RATE_DIVISOR     (2UL * I2S_SCK_HALF_PERIOD * I2S_BITS_PER_STEREO_FRAME)
#define I2S_SAMPLE_RATE_HZ          ((I2S_HCLK_HZ + (I2S_SAMPLE_RATE_DIVISOR / 2UL)) / I2S_SAMPLE_RATE_DIVISOR)
#define RECORD_DURATION_SEC         (25UL)
#define TOTAL_SAMPLES               (((I2S_HCLK_HZ * RECORD_DURATION_SEC) + (I2S_SAMPLE_RATE_DIVISOR / 2UL)) / I2S_SAMPLE_RATE_DIVISOR)
#define ADPCM_SAMPLES_PER_WORD      (8UL)
#define TOTAL_ADPCM_WORDS           ((TOTAL_SAMPLES + ADPCM_SAMPLES_PER_WORD - 1UL) / ADPCM_SAMPLES_PER_WORD)

volatile uint32_t g_record_done;
volatile uint32_t g_sample_count;
volatile uint32_t g_record_word_count;
volatile uint32_t g_record_target_words;
volatile uint32_t g_adpcm_mode;

volatile uint32_t g_i2s_status;
volatile uint32_t g_i2s_fifo_level;
volatile uint32_t g_i2s_read_count;
volatile uint32_t g_i2s_empty_count;
volatile uint32_t g_sdram_write_count;
volatile uint32_t g_last_sample;
volatile uint32_t g_sample_sum;
volatile uint32_t g_nonzero_count;
volatile uint32_t g_verify_0;
volatile uint32_t g_verify_1;
volatile uint32_t g_verify_100;
volatile uint32_t g_verify_1000;
volatile uint32_t g_verify_last;

volatile uint32_t g_sample_min;
volatile uint32_t g_sample_max;
volatile uint32_t g_sample_mean;
volatile uint32_t g_variance_high;
volatile uint32_t g_variance_low;
volatile uint32_t g_zero_crossings;

static void audio_i2s_init(uint32_t adpcm_enable)
{
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_FIFO_CLEAR;
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_OVF_CLEAR;
    
		// adpcm_enable 1:启用ADPCM压缩模式, 0:原始PCM模式
    AUDIO_I2S_CONFIG = adpcm_enable ? AUDIO_I2S_CONFIG_ADPCM_ENABLE : 0UL;
    AUDIO_I2S_CTRL = AUDIO_I2S_CTRL_ENABLE;
}

static void audio_i2s_stop(void)
{
    AUDIO_I2S_CTRL &= ~AUDIO_I2S_CTRL_ENABLE;
}

// 从FIFO读取一个32位采样数据
static uint32_t audio_i2s_read_sample(void)
{
		while (AUDIO_I2S_STATUS & AUDIO_I2S_STATUS_EMPTY) {
        g_i2s_empty_count++;
    }

    g_i2s_status = AUDIO_I2S_STATUS;
    g_i2s_fifo_level = AUDIO_I2S_FIFO_LEVEL;
    return AUDIO_I2S_DATA;
}

static void gpio_key_led_init(void)
{
    GPIO_DIR = RECORD_LED_PIN | ADPCM_LED_PIN;
    GPIO_OUT = 0x00;
}

// 等待KEY0按键按下并释放，同时更新模式选择指示灯状态
static void wait_for_key0_press(void)
{
    while (!KEY0Pressed()) {
        LEDS_SET(ADPCM_LED_VALUE());
			  g_adpcm_mode = SW1AdpcmMode() ? 1UL : 0UL;
    }

    while (KEY0Pressed()) {
        LEDS_SET(ADPCM_LED_VALUE());
			  g_adpcm_mode = SW1AdpcmMode() ? 1UL : 0UL;
    }
}

// 调试用，数据分析
static void analyze_audio_stats(volatile uint32_t *sdram_base, uint32_t start_idx, uint32_t count)
{
    uint32_t i;
    uint32_t sample;
    uint32_t prev_sample;
    uint64_t sum = 0;
    uint32_t min_val = 0xFFFFFFFF;
    uint32_t max_val = 0;
    uint32_t zero_cross = 0;
    uint32_t high_activity = 0;

    prev_sample = sdram_base[start_idx];

    for (i = start_idx; i < start_idx + count; i++) {
        sample = sdram_base[i];

        if (sample < min_val) min_val = sample;
        if (sample > max_val) max_val = sample;

        sum += sample;

        if ((prev_sample < 0x800000 && sample >= 0x800000) ||
            (prev_sample > 0x800000 && sample <= 0x800000)) {
            zero_cross++;
        }

        if (sample > 0x801000 || sample < 0x7FF000) {
            high_activity++;
        }

        prev_sample = sample;
    }

    g_sample_min = min_val;
    g_sample_max = max_val;
    g_sample_mean = (uint32_t)(sum / count);
    g_zero_crossings = zero_cross;
    g_variance_high = high_activity;
}

int main(void)
{
    uint32_t i;
    volatile uint32_t *sdram_dst;

    gpio_key_led_init();
    delay_init();


    g_record_done = 0;
    g_sample_count = 0;
    g_record_word_count = 0;
    g_record_target_words = 0;
    g_adpcm_mode = 0;
    g_i2s_read_count = 0;
    g_i2s_empty_count = 0;
    g_sdram_write_count = 0;
    g_last_sample = 0;
    g_sample_sum = 0;
    g_nonzero_count = 0;
    g_sample_min = 0;
    g_sample_max = 0;
    g_sample_mean = 0;
    g_zero_crossings = 0;
    g_variance_high = 0;

    while (1) {
			
        wait_for_key0_press();

        g_adpcm_mode = SW1AdpcmMode() ? 1UL : 0UL;
        g_record_target_words = g_adpcm_mode ? TOTAL_ADPCM_WORDS : TOTAL_SAMPLES;

        LEDS_SET(RECORD_LED_PIN | (g_adpcm_mode ? ADPCM_LED_PIN : 0UL));

        audio_i2s_init(g_adpcm_mode);

        sdram_dst = (volatile uint32_t *)SDRAM_BASE;

        for (i = 0; i < g_record_target_words; i++) {
            uint32_t word = audio_i2s_read_sample();
            sdram_dst[i] = word;
            g_record_word_count++;
            g_sample_count += g_adpcm_mode ? ADPCM_SAMPLES_PER_WORD : 1UL;
            g_i2s_read_count++;
            g_last_sample = word;
            if (word != 0) {
                g_nonzero_count++;
                g_sample_sum += word;
            }


            if ((i & 0x3FFF) == 0) {
                g_sdram_write_count++;
            }
        }

        audio_i2s_stop();
        LEDS_SET(ADPCM_LED_VALUE());	 //录音过程中模式指示灯锁定

        g_record_done = 1;

			
        if (!g_adpcm_mode) {
            analyze_audio_stats(sdram_dst, 0, TOTAL_SAMPLES);

            analyze_audio_stats(sdram_dst, 138, 1000);
        }

        while (1) {
            g_verify_0 = sdram_dst[0];
            g_verify_1 = sdram_dst[1];
            g_verify_100 = sdram_dst[100];
            g_verify_1000 = sdram_dst[1000];
            g_verify_last = sdram_dst[g_record_target_words - 1UL];
        }
				
    }
}
