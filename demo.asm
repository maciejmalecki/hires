/*
 * MIT License
 *
 * Copyright (c) 2026 Maciej Małecki
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "hires.asm"

.label BITMAP_MEM_START = $4000
.label SCREEN_MEM_START = $6000

*= $0801 "Basic Upstart"
:BasicUpstart(start) // Basic start routine

*= $0810 "Program"
start:
    // set up VIC2 bank
    lda $DD00
    and #%11111100
    ora #2
    sta $DD00
    // turn on hires bitmap mode
    lda $D011
    and #%10111111
    ora #%00100000
    sta $D011
    lda $D016
    and #%11101111
    sta $D016
    // set VIC2 memory (bitmap position 0, screen mem right after bitmap)
    lda #%10000000
    sta $D018
    lda #BLACK
    sta $D020

    // initialize screen
    jsr hires.init

    setColours(hires, BLACK, LIGHT_GREY)

    plot(hires, 0, 0)
    plot(hires, 10, 10)
    plot(hires, 20, 20)
    plot(hires, 30, 30)

    plot(hires, 160, 100)
    plot(hires, 319, 199)

    moveTo(hires, 100, 80)
    lineTo(hires, 200, 100)
    lineTo(hires, 180, 150)
    lineTo(hires, 100, 80)

    !: jmp !-

    hires: createHires(BITMAP_MEM_START, SCREEN_MEM_START)
