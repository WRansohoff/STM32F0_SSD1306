#ifndef _VVC_UTIL_ASM
#define _VVC_UTIL_ASM

/*
 * Utility functions, for better legibility.
 */

.syntax unified
#ifdef VVC_F0
    .cpu cortex-m0
#elif  VVC_F3
    .cpu cortex-m4
#endif
.fpu softvfp
.thumb

// Instead of #include'ing this file everywhere, we can
// just declare the methods 'global' and make sure our
// Makefile compiles/links with this source file.
.global delay_us
// Assembly functions for common I2C operations.
.global i2c_periph_init
.global i2c_send_start
.global i2c_send_stop
.global i2c_set_saddr
.global i2c_num_bytes_to_send
.global i2c_send_byte
// (Primarily for RTCs and maybe EEPROMs, etc)
.global i2c_read_register
// (Primarily for SSD1306 OLED or other 0/1 D/C I2C protocols)
.global i2c_send_command
.global i2c_send_data
// SSD1306 control functions.
.global i2c_display_framebuffer
.global i2c_init_ssd1306

/*
 * Delay a given number of microseconds.
 * Expects:
 *  r0 contains the number of microseconds to wait.
 */
.type delay_us,%function
.section .text.delay_us,"ax",%progbits
delay_us:
    PUSH { r1, r2, lr }
    // We are running at 48MHz, so 10 microsecond is X cycles.
    // How long is 1 cycle? 1 / (48,000,000 * second).
    // How long is 1 us?    1 / (1,000,000 * second).
    // So 1 us = 48 clock cycles. I think.
    // I still need to confirm this with a scope, but it
    // looks about right when used for half-second delays...
    MOV  r1, r0
    ADDS r1, r1, #1
    delay_us_loop:
        // Spend 48 cycles cycling:
        // 4 instructions to subtract 1x us and check if done.
        // 44x instructions executing a 4-instruction loop
        // 11 times. Each 48 cycles is a us 'step'.
        /*
         * NOTE/TODO: This is not totally accurate!!
         * It turns out that 'branch' instructions take
         * 2 cycles, not 1, but only if they do take the branch.
         * So, 'BEQ' is 1 cycle if it does not branch, 2 if
         * it does. That means that this timing is slightly off.
         * But hey, it's close enough for government work.
         */
        MOVS r2, #44
        SUBS r1, r1, #1
        CMP  r1, #0
        BEQ  delay_us_done
        delay_us_subloop:
            SUBS r2, r2, #4
            CMP  r2, #0
            BEQ  delay_us_loop
            B    delay_us_subloop
        B    delay_us_loop
    delay_us_done:
        POP  { r1, r2, pc }
.size delay_us, .-delay_us

/*
 * Initialize an I2C peripheral with some fairly typical settings.
 * Expects:
 *   r0: I2Cx_CR1 (base) address.
 *   r1: I2C speed peripheral value.
 *       At 48MHz, here are some common values:
 *         - 0x50100103: 1MHz   'fast mode+'
 *         - 0x50330309: 400KHz 'fast mode'
 *         - 0xB0420F13: 100KHz
 *         - 0xB042C3C7: 10KHz
 */
.type i2c_periph_init,%function
.section .text.i2c_periph_init,"ax",%progbits
i2c_periph_init:
    PUSH { r0, r1, r2, r3, r4, lr }
    // First, disable I2Cx by resetting PE in I2Cx_CR1.
    LDR  r2, [r0]
    LDR  r3, =0xFFFFFFFE
    ANDS r2, r2, r3
    STR  r2, [r0]
    // With the periph off, clear a few other bits in CR1 to reset state:
    LDR  r2, [r0]
    LDR  r3, =0x00CFE0FF
    ANDS r2, r2, r3
    STR  r2, [r0]
    // Configure I2C timing. Clear all but the reserved TIMINGR[27:24] bits
    LDR  r4, =0x00000010
    ADDS r0, r0, r4
    LDR  r2, [r0]
    LDR  r3, =0x0F000000
    ANDS r2, r2, r3
    ORRS r2, r2, r1
    STR  r2, [r0]
    // Clear I2C1_CR2 with a reset mask, and then set ACK config.
    // 0x07FF7FFF is recommended in the std periph lib.
    // But I'll use 0x04... to also clear AUTOEND/RELOAD.
    LDR  r3, =0x0000000C
    SUBS r0, r0, r3
    LDR  r2, [r0]
    LDR  r3, =0x04FF7FFF
    ANDS r2, r2, r3
    // ('Ack_Enable' is 0, so no bit sets are needed.)
    STR  r2, [r0]
    // Set EN bit in CR1 to enable the I2Cx peripheral.
    SUBS r0, r0, #4
    LDR  r2, [r0]
    LDR  r3, =0x00000001
    ORRS r2, r2, r3
    STR  r2, [r0]
    POP  { r0, r1, r2, r3, r4, pc }
.size i2c_periph_init, .-i2c_periph_init

/*
 * Send a 'start transmission' sequence over I2C
 * Expects:
 *   r0 contains the I2Cx_CR2 register location.
 */
.section .text.i2c_send_start,"ax",%progbits
i2c_send_start:
    PUSH { r1, r2, lr }
    // 'Send start transmission' is bit 13 of I2Cx_CR2
    LDR  r2, =0x00002000
    LDR  r1, [r0]
    ORRS r1, r1, r2
    STR  r1, [r0]
    // Wait for the start condition to manifest.
    i2c_wait_for_start:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ  i2c_wait_for_start
    POP  { r1, r2, pc }
.size i2c_send_start, .-i2c_send_start

/*
 * Send an 'end/stop transmission' sequence over I2C
 * Expects:
 *   r0 contains the I2Cx_CR2 register location.
 */
.section .text.i2c_send_stop,"ax",%progbits
i2c_send_stop:
    PUSH { r1, r2, lr }
    // 'Send stop transmission' is bit 14 of I2Cx_CR2
    LDR  r2, =0x00004000
    LDR  r1, [r0]
    ORRS r1, r1, r2
    STR  r1, [r0]
    // Wait for the stop condition to manifest.
    i2c_wait_for_stop:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ  i2c_wait_for_stop
    // With a stop condition detected, clear the STOPF flag by
    // writing to STOPCF flag in I2C_ICR (Offset 0x1C)
    ADDS r0, r0, #24
    LDR  r2, =0x0000020
    LDR  r1, [r0]
    ORRS r1, r1, r2
    STR  r1, [r0]
    // Wait for flag to clear in I2C_ISR (Offset 0x18)
    SUBS r0, r0, #4
    i2c_wait_for_stop_clear:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        CMP  r1, r2
        BEQ i2c_wait_for_stop_clear
    // Return r0 to CR1/Base address.
    SUBS r0, r0, #20
    POP  { r1, r2, pc }
.size i2c_send_stop, .-i2c_send_stop

/*
 * Set slave device address. I mean, that's what the manual
 * and even abbreviations call it. And 'replicant' is really only
 * an appropriate replacement in database terminology.
 * Expects:
 *   r0 contains I2Cx_CR2 register address.
 *   r2 contains SADDR[7:0] 7-bit address: 0b0xxx-xxxx
 */
.section .text.i2c_set_saddr,"ax",%progbits
i2c_set_saddr:
    PUSH { r1, r3, lr }
    //LSLS r2, r2, #1
    LDR  r1, [r0]
    LDR  r3, =0xFFFFFF00
    ANDS r1, r1, r3
    ORRS r1, r1, r2
    STR  r1, [r0]
    POP  { r1, r3, pc }
.size i2c_set_saddr, .-i2c_set_saddr

/*
 * Set how many bytes a transmission will contain.
 * Expects:
 *   r0 contains I2Cx_CR2 register address.
 *   r2 contains total # of bytes to send.
 */
.section .text.i2c_num_bytes_to_send,"ax",%progbits
i2c_num_bytes_to_send:
    PUSH { r1, r2, r3, lr }
    // Perform a slightly more complex load/modify/store,
    // to clear then set the 8 NYBYTES bits.
    // Reset NBYTES to 0, then set to the desired value.
    LDR  r3, [r0]
    LDR  r1, =0xFF00FFFF
    ANDS r3, r3, r1
    // Shift to NBYTES location; [23:16] from [7:0], << 16.
    LSLS r2, #16
    ORRS r3, r3, r2
    STR  r3, [r0]
    POP  { r1, r2, r3, pc }
.size i2c_num_bytes_to_send, .-i2c_num_bytes_to_send

/*
 * Send a byte of data over I2C.
 * Expects:
 *   - I2Cx peripheral is in an active transmission ('START' sent)
 *   r0 contains I2Cx[_CR1] base register address.
 *   r2 contains the byte to write; 0x000000BB.
 *   r3 contains the 'success' flag:
 *       TXIS    (standard): 0x00000002
 *       TC     (last byte): 0x00000040
 *       TCR (reload ready): 0x00000080
 */
.section .text.i2c_send_byte,"ax",%progbits
i2c_send_byte:
    PUSH { r1, r2, r4, lr }
    // Target the TXDR buffer (0x28 = 40)
    ADDS r0, #40
    // Write/modify/store to the TX buffer.
    // (Clear the TX bits first :/)
    LDR  r1, =0xFFFFFF00
    LDR  r4, [r0]
    ANDS r4, r4, r1
    // Ensure that we only write bits [7:0]
    LDR  r1, =0x000000FF
    ANDS r2, r2, r1
    ORRS r4, r4, r2
    // Store the value to transmit.
    STR  r4, [r0]

    // Wait for the TXIS bit to be set in I2Cx_ICR.
    // (Offset 0x18 = 24, 40-24=16)
    SUBS r0, #16
    MOVS r2, r3
    // (Load the status register for debug)
    LDR  r4, =0x40005404
    LDR  r4, [r4]
    i2c_send_byte_tx_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  i2c_send_byte_tx_wait

    // Reset the address register that was passed in.
    SUBS r0, #24
    // Return.
    POP { r1, r2, r4, pc }
.size i2c_send_byte, .-i2c_send_byte

/*
 * Read a byte from an I2C device's address.
 * Expects:
 *   r0 contains I2Cx[_CR1] base register address.
 *   r1 contains the address of the device.
 *   r2 contains the address to read.
 * Writes:
 *   r0 will store the resulting byte.
 */
.type i2c_read_register,%function
.section .text.i2c_read_register,"ax",%progbits
i2c_read_register:
    PUSH { r1, r2, r3, r4, r5, r6, lr }
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    // Store the address to read, and set target address.
    MOVS r6, r2
    MOVS r5, r1
    // Disable the RELOAD flag.
    LDR  r2, =0xFEFFFFFF
    LDR  r1, [r0]
    ANDS r1, r1, r2
    STR  r1, [r0]
    // Set device address.
    MOVS r2, r5
    BL   i2c_set_saddr
    // Set the number of bytes to send, start transmission.
    MOVS r2, #1
    BL   i2c_num_bytes_to_send
    BL   i2c_send_start
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    // Send the address of the byte to read.
    MOVS r2, r6
    LDR  r3, =0x00000040
    BL   i2c_send_byte
    // Stop the 'write' transmission.
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Read 1 byte.
    //SUBS r0, r0, #4
    MOVS r2, #1
    BL   i2c_num_bytes_to_send
    // In I2Cx_CR2, set bit 10 ('read' direction.)
    //ADDS r0, r0, #4
    LDR  r2, =0x00000400
    LDR  r1, [r0]
    ORRS r1, r1, r2
    STR  r1, [r0]
    BL   i2c_send_start
    // Wait for RXNE (bit 2 in I2Cx_ISR [+0x18], 'rx register not empty')
    LDR  r1, =0x00000014
    ADDS r0, r0, r1
    LDR  r2, =0x00000004
    i2c_read_byte_rx_wait:
        LDR  r1, [r0]
        ANDS r1, r1, r2
        BEQ  i2c_read_byte_rx_wait
    // Read I2Cx_RXDR (+0x24)
    LDR  r1, =0x0000000C
    ADDS r0, r0, r1
    LDR  r7, [r0]
    // In I2Cx_CR2, send stop and reset bit 10 ('write' direction.)
    SUBS r0, r0, #32
    BL   i2c_send_stop
    LDR  r2, =0xFFFFFBFF
    LDR  r1, [r0]
    ANDS r1, r1, r2
    STR  r1, [r0]
    // Set return value.
    MOVS r0, r7
    POP  { r1, r2, r3, r4, r5, r6, pc }
.size i2c_read_register, .-i2c_read_register

/*
 * Copy the current framebuffer into the OLED.
 * Note: Framebuffer RAM is [heap_start:+1024]
 * Expects:
 *   r0: I2Cx_CR1 base address.
 *   r1: Start of framebuffer address.
 */
.type i2c_display_framebuffer,%function
.section .text.i2c_display_framebuffer,"ax",%progbits
i2c_display_framebuffer:
    PUSH { r0, r1, r2, r3, r4, r5, r6, lr }
    // Start of framebuffer memory
    MOVS r5, r1
    /*
     * In a single I2C transmission, write one 128B page
     * simply like, '0x40 / 0xdat / 0xdat / 0xdat / ...'
     * No need for interleaved 'DAT/CMD' bytes.
     * This chip can only send up to 255 bytes at once,
     * so first enable the 'RELOAD' flag in CR2.
     */
    /*
    LDR  r3, =0x00000010
    BL   i2c_send_command
    LDR  r3, =0x00000001
    BL   i2c_send_command
    LDR  r3, =0x00000040
    BL   i2c_send_command
    */
    LDR  r3, =0x00000021
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #127
    BL   i2c_send_command
    LDR  r3, =0x00000022
    BL   i2c_send_command
    MOVS r3, #0
    BL   i2c_send_command
    MOVS r3, #7
    BL   i2c_send_command
    //LDR  r3, =0x00000040
    //BL   i2c_send_command
    // Enable the RELOAD flag.
    ADDS r0, r0, #4
    LDR  r2, =0x01000000
    LDR  r4, [r0]
    ORRS r4, r4, r2
    STR  r4, [r0]
    // Set address (0x78 or 0x7A)
    LDR  r2, =0x78
    LDR  r4, [r0]
    ORRS r4, r4, r2
    STR  r4, [r0]
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    MOVS r6, #8
    SUBS r5, r5, #4
    send_framebuffer_oled_row:
        ADDS r0, r0, #4
        CMP  r6, #8
        BEQ  send_framebuffer_skip_stop
        //LDR  r4, =0x00000001
        //ANDS r4, r4, r6
        //BNE  i2c_continue_send
        BL   i2c_send_stop
        send_framebuffer_skip_stop:
        MOVS r4, #129
        MOVS r2, r4
        BL   i2c_num_bytes_to_send
        BL   i2c_send_start
        // Reset r0 to I2Cx_base
        SUBS r0, r0, #4
        LDR  r2, =0x00000040
        LDR  r3, =0x00000002
        BL   i2c_send_byte
        SUBS r4, r4, #1
        B    i2c_fb_sendforreal
        /*
        i2c_continue_send:
        MOVS r4, #128
        MOVS r2, r4
        BL   i2c_num_bytes_to_send
        // Reset r0 to I2Cx_base
        SUBS r0, r0, #4
        */
        i2c_fb_sendforreal:
        // Send bytes according to framebuffer progress. (r5)
        send_oled_row_bits:
            ADDS r5, r5, #4
            LDR  r2, [r5]
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            LDR  r2, [r5]
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            LSRS r2, r2, #8
            CMP  r4, #4
            BNE  send_framebuffer_normal_byte4
            LDR  r3, =0x00000080
            BL   i2c_send_byte
            B    send_framebuffer_bytes_done
            send_framebuffer_normal_byte4:
            LDR  r3, =0x00000002
            BL   i2c_send_byte
            send_framebuffer_bytes_done:
            SUBS r4, r4, #4
            BNE  send_oled_row_bits
        SUBS r6, r6, #1
        BNE  send_framebuffer_oled_row
    // Disable the RELOAD flag.
    ADDS r0, r0, #4
    LDR  r2, =0xFEFFFFFF
    LDR  r1, [r0]
    ANDS r1, r1, r2
    STR  r1, [r0]
    BL   i2c_send_stop
    POP  { r0, r1, r2, r3, r4, r5, r6, pc }
.size i2c_display_framebuffer, .-i2c_display_framebuffer

/*
 * Initialize an SSD1306 OLED monochrome display.
 * Expects:
 *   r0: I2Cx_CR1 (base) address.
 */
.type i2c_init_ssd_1306,%function
.section .text.i2c_init_ssd1306,"ax",%progbits
i2c_init_ssd1306:
    PUSH { r0, r1, r2, r3, lr }
    // 'Display Off' = 0xAE
    LDR  r3, =0x000000AE
    BL   i2c_send_command
    // Set display clock division; recommended value of 0x80
    // (Command: 0xD5, and apparently the arg is cmd not dat.)
    LDR  r3, =0x000000D5
    BL   i2c_send_command
    LDR  r3, =0x00000080
    //LDR  r3, =0x000000F0
    BL   i2c_send_command
    // 'Set Multiplex' command: 0xA8, recommended 0x3F (1:64)
    LDR  r3, =0x000000A8
    BL   i2c_send_command
    LDR  r3, =0x0000003F
    BL   i2c_send_command
    // Set display offset to 0; command is 0xD3
    LDR  r3, =0x000000D3
    BL   i2c_send_command
    LDR  r3, =0x00000000
    BL   i2c_send_command
    // 'Set Start Line' command = 0b01xxxxxx for line x. Use 0.
    LDR  r3, =0x00000040
    BL   i2c_send_command
    // Internal charge pump settings; 0x14 on, 0x10 off.
    // (Command: 0x8D)
    LDR  r3, =0x0000008D
    BL   i2c_send_command
    LDR  r3, =0x00000014
    BL   i2c_send_command
    // 'Memory Mode' command: 0x20
    // 0x00 means 'act like ks0108' according to Adafruit...okay
    // (Seems to mean 'horizontal addressing' - 01 for vert.)
    LDR  r3, =0x00000020
    BL   i2c_send_command
    LDR  r3, =0x00000000
    // ...and '10' means 'page addressing mode'.
    //LDR  r3, =0x00000010
    BL   i2c_send_command
    // 'SEGREMAP' of 0x1. (|| with command 0xA0) Uh...I dunno.
    LDR  r3, =0x000000A1
    BL   i2c_send_command
    // 'COMSCANDEC' command: 0xC8 ('...INC' = 0xC0)
    LDR  r3, =0x000000C8
    BL   i2c_send_command
    // 'SETCOMPINS' command: 0xDA, recommended value 0x12
    LDR  r3, =0x000000DA
    BL   i2c_send_command
    LDR  r3, =0x00000012 // 0x02 for 128x32 display.
    BL   i2c_send_command
    // 'Set Contrast' command: 0x81. With internal charge pump,
    // use value of 0xCF.
    LDR  r3, =0x00000081
    BL   i2c_send_command
    LDR  r3, =0x000000CF // 0x8F for 128x32 display.
    //LDR  r3, =0x000000FF
    BL   i2c_send_command
    // 'Set Precharge' command: 0xD9. With internal charge pump,
    // use value of 0xF1.
    LDR  r3, =0x000000D9
    BL   i2c_send_command
    LDR  r3, =0x000000F1
    //LDR  r3, =0x00000022
    BL   i2c_send_command
    // 'Set VCOM Detect' command: 0xDB, recommended 0x40?
    // (Level at which logic level '1' is detected...I wonder if
    // this could be lowered to drive from 1.8V L-series or 1.2V FPGAs)
    LDR  r3, =0x000000DB
    BL   i2c_send_command
    LDR  r3, =0x00000040
    //LDR  r3, =0x00000020
    BL   i2c_send_command
    // 'DISPLAYALLON_RESUME' command: 0xA4
    // (Output follows RAM content)
    LDR  r3, =0x000000A4
    BL   i2c_send_command
    // 'Normal Display Mode' command: 0xA6
    // ('Invert Display Mode' command: 0xA7)
    LDR  r3, =0x000000A6
    BL   i2c_send_command
    // Set Page start address.
    //LDR  r3, =0x000000B0
    //BL   i2c_send_command
    // Set high column address.
    /*
    LDR  r3, =0x00000010
    BL   i2c_send_command
    // Set low column address.
    LDR  r3, =0x00000001
    BL   i2c_send_command
    */
    // 'Display On' command: 0xAF
    LDR  r3, =0x000000AF
    BL   i2c_send_command
    POP  { r0, r1, r2, r3, pc }
.size i2c_init_ssd1306, .-i2c_init_ssd1306

/*
 * Send a command over I2C.
 * Expects:
 *   r0 contains I2Cx[_CR1] base address.
 *   r3 contains command byte. (0x000000BB)
 */
.section .text.i2c_send_command,"ax",%progbits
i2c_send_command:
    PUSH { r1, r2, r3, r4, lr }
    MOVS r4, r3
    // 'D/C' here is indicated by the first byte.
    // 0x00 means 'command / active'
    // i2c1_cr2_base:         0x40005404
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    // Set the screen's SADD[7:0] bits.
    // My breakout defaults to 0x78, 0x7A configurable by jumper.
    LDR  r2, =0x78
    BL   i2c_set_saddr
    // Send 2 bytes; 'D/C', then the actual content.
    MOVS r2, #2
    BL   i2c_num_bytes_to_send
    BL   i2c_send_start
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    LDR  r2, =0x00000000
    LDR  r3, =0x00000002
    BL   i2c_send_byte
    MOVS r2, r4
    LDR  r3, =0x00000040
    BL   i2c_send_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4

    POP  { r1, r2, r3, r4, pc }
.size i2c_send_command, .-i2c_send_command

/*
 * Send a byte of data over I2C.
 * Expects:
 *   r0 contains I2Cx[_CR1] base address.
 *   r3 contains data byte. (0x000000BB)
 */
.section .text.i2c_send_data,"ax",%progbits
i2c_send_data:
    PUSH { r1, r2, r3, r4, lr }
    MOVS r4, r3
    // 'D/C' here is indicated by the first byte.
    // 0x40 means 'data / active'
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    // Set the screen's SADD[7:0] bits.
    // My breakout defaults to 0x78, 0x7A configurable by jumper.
    LDR  r2, =0x78
    BL   i2c_set_saddr
    // Send 2 bytes; 'D/C', then the actual content.
    MOVS r2, #2
    BL   i2c_num_bytes_to_send
    BL   i2c_send_start
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    LDR  r2, =0x00000040
    LDR  r3, =0x00000002
    BL   i2c_send_byte
    MOVS r2, r4
    LDR  r4, =0x000000FF
    ANDS r2, r2, r4
    LDR  r3, =0x00000040
    BL   i2c_send_byte
    // Set r0 to I2Cx_CR2
    ADDS r0, r0, #4
    BL   i2c_send_stop
    // Reset r0 to I2Cx_base
    SUBS r0, r0, #4
    POP { r1, r2, r3, r4, pc }
.size i2c_send_data, .-i2c_send_data

#endif
