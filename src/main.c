#include "main.h"

/**
 * Main program. For now, just a test to blink some LEDs.
 */
int main(void) {
    // Enable the GPIOA peripheral's clock.
    RCC_AHBPeriphClockCmd(RCC_AHBPeriph_GPIOA, ENABLE);
    // Enable the I2C1 peripheral's clock.
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_I2C1, ENABLE);

    // Initialize GPIO pins 9 and 10 for I2C.
    // Set AF values. I2C1 = AF4.
    GPIO_PinAFConfig(GPIOA, GPIO_PinSource9, GPIO_AF_4);
    GPIO_PinAFConfig(GPIOA, GPIO_PinSource10, GPIO_AF_4);
    GPIO_InitTypeDef gpio_init_struct;
    gpio_init_struct.GPIO_Pin   = GPIO_Pin_9 | GPIO_Pin_10;
    gpio_init_struct.GPIO_Mode  = GPIO_Mode_AF;
    gpio_init_struct.GPIO_OType = GPIO_OType_OD;
    gpio_init_struct.GPIO_Speed = GPIO_Speed_2MHz;
    gpio_init_struct.GPIO_PuPd  = GPIO_PuPd_NOPULL;
    GPIO_Init(GPIOA, &gpio_init_struct);

    // Initialize the I2C1 peripheral.
    i2c_periph_init(I2C1_BASE, VVC_TIMING_1MHzI2C_48MHzPLL);

    // Initialize the Monochrome OLED screen.
    i2c_init_ssd1306(I2C1_BASE);

    // Clear the framebuffer.
    oled_clear_screen(0x00);
    // Draw an outline.
    oled_draw_rect(0, 0, 127, 63, 2, 1);

    // Since this is a microcontroller, there's no point in
    // exiting our program before power-off.
    while (1) {
        // Display the framebuffer.
        i2c_display_framebuffer(I2C1_BASE, &oled_fb);

        // Delay ~500ms.
        delay_us(500000);
    }
}
