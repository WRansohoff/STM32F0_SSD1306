#ifndef _VVC_UTIL_C_H
#define _VVC_UTIL_C_H

#include "global.h"

void oled_clear_screen(unsigned char color);
void oled_write_pixel(int x, int y, unsigned char color);
void oled_draw_h_line(int x, int y, int w, unsigned char color);
void oled_draw_v_line(int x, int y, int h, unsigned char color);
void oled_draw_rect(int x, int y, int w, int h,
                    int outline, unsigned char color);

#endif
