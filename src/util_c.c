#include "util_c.h"

/*
 * Clear the OLED display to a set color byte.
 * 0x00 = off,
 * 0xFF = primary color 'on'.
 * But technically, you could use any value and get a pattern
 * of horizontal lines repeating every 8 rows. 
 */
void oled_clear_screen(unsigned char color) {
    int i;
    for (i = 0; i < OLED_FB_SIZE; ++i) {
        oled_fb[i] = color;
    }
}

/*
 * Write a pixel in the current OLED framebuffer.
 * Note that the positioning is a bit odd; each byte is a VERTICAL column
 * of 8 pixels, but each successive byte increments the row position by 1.
 * This means that the buffer is 8x 128-byte pages stacked on top of one
 * another. To set an (x, y) pixel, we |= one position in one byte.
 *   Byte offset = x + ((y / 8) * 128)
 *   Bit offset  = (y & 0x07)
 * 'color' indicates whether to set or unset the pixel. 0 means 'unset.'
 */
void oled_write_pixel(int x, int y, unsigned char color) {
    int y_page = y / 8;
    int byte_to_mod = x + (y_page * 128);
    int bit_to_set = 0x01 << (y & 0x07);
    if (color) {
        oled_fb[byte_to_mod] |= bit_to_set;
    }
    else {
        bit_to_set = ~bit_to_set;
        oled_fb[byte_to_mod] &= bit_to_set;
    }
}

/*
 * Draw a horizontal line.
 * First, calculate the Y bitmask and byte offset, then just go from x->x.
 */
void oled_draw_h_line(int x, int y, int w, unsigned char color) {
    int y_page_offset = y / 8;
    y_page_offset *= 128;
    int bit_to_set = 0x01 << (y & 0x07);
    if (!color) {
        bit_to_set = ~bit_to_set;
    }
    int x_pos;
    for (x_pos = x; x_pos < (x+w); ++x_pos) {
        if (color) {
            oled_fb[x_pos + y_page_offset] |= bit_to_set;
        }
        else {
            oled_fb[x_pos + y_page_offset] &= bit_to_set;
        }
    }
}

/*
 * Draw a veritcal line.
 */
void oled_draw_v_line(int x, int y, int h, unsigned char color) {
    int y_page_offset;
    int bit_to_set;
    int y_pos;
    for (y_pos = y; y_pos < (y+h); ++y_pos) {
        y_page_offset = y_pos/8;
        y_page_offset *= 128;
        bit_to_set = 0x01 << (y_pos & 0x07);
        if (color) {
            oled_fb[x + y_page_offset] |= bit_to_set;
        }
        else {
            bit_to_set = ~bit_to_set;
            oled_fb[x + y_page_offset] &= bit_to_set;
        }
    }
}

/*
 * Draw a rectangle on the display.
 * I guess just pick the longer dimension, and either draw
 * horizontal or vertical lines.
 * Notable args:
 *   - outline: If <=0, fill the rectangle with 'color'.
 *              If >0, draw an outline inside the dimensions of N pixels.
 *   - color: If 0, clear drawn bits. If not 0, set drawn bits.
 */
void oled_draw_rect(int x, int y, int w, int h,
                    int outline, unsigned char color) {
    if (outline > 0) {
        // Draw an outline.
        int o_pos;
        // Top.
        for (o_pos = y; o_pos < (y+outline); ++o_pos) {
            oled_draw_h_line(x, o_pos, w, color);
        }
        // Bottom.
        for (o_pos = (y+h-1); o_pos > (y+h-1-outline); --o_pos) {
            oled_draw_h_line(x, o_pos, w, color);
        }
        // Left.
        for (o_pos = x; o_pos < (x+outline); ++o_pos) {
            oled_draw_v_line(o_pos, y, h, color);
        }
        // Right.
        for (o_pos = (x+w-1); o_pos > (x+w-1-outline); --o_pos) {
            oled_draw_v_line(o_pos, y, h, color);
        }
    }
    else {
        // Draw a filled rectangle.
        if (w > h) {
            // Draw fewer horizontal lines than vertical ones.
            int y_pos;
            for (y_pos = y; y_pos < (y+h); ++y_pos) {
                oled_draw_h_line(x, y_pos, w, 1);
            }
        }
        else {
            // Draw fewer (or ==) vertical lines than horizontal ones.
            int x_pos;
            for (x_pos = x; x_pos < (x+w); ++x_pos) {
                oled_draw_v_line(x_pos, y, h, 1);
            }
        }
    }
}
