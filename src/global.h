#ifndef _VVC_GLOBAL_H
#define _VVC_GLOBAL_H

#include "stm32f0xx.h"

// Constant value definitions.
#define VVC_TIMING_1MHzI2C_48MHzPLL   0x50100103
#define VVC_TIMING_400KHzI2C_48MHzPLL 0x50330309
#define VVC_TIMING_100KHzI2C_48MHzPLL 0xB0420F13
#define VVC_TIMING_10KHzI2C_48MHzPLL  0xB042C3C7

// 128x64-px monochrome. (1 Byte = 8 pixels)
// TODO: support 128x32-px version of the screen.
#define OLED_FB_SIZE (128*64)/8

// Assembly methods.
extern void delay_us(unsigned int d);
extern void i2c_periph_init(unsigned int i2c_addr, unsigned int i2c_speed);
extern void i2c_init_ssd1306(unsigned int i2c_addr);
extern void i2c_display_framebuffer(unsigned int i2c_addr, void* fb_addr);
extern unsigned char i2c_read_register(unsigned int i2c_register,
                                       unsigned char i2c_device_addr,
                                       unsigned char i2c_device_mem_addr);

// Global variables/storage.
unsigned char oled_fb[OLED_FB_SIZE];

#endif
