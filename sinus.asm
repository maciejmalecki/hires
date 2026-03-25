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

    setColours(hires, BLACK, CYAN)
    jsr hires.resetColours

    // moveTo first point (x=0, y=sinY[0])
    lda #0
    ldx #0
    ldy sinY
    jsr hires.moveTo

    // draw lines for x = 1..255
    lda #1
    sta idx
firstPage:
    ldy idx
    lda sinY, y         // load Y coord from table
    sta yTmp
    lda idx              // A = x lo
    ldx #0               // X = x hi = 0
    ldy yTmp             // Y = y coord
    jsr hires.lineTo
    inc idx
    bne firstPage        // loops until idx wraps 255->0

    // draw lines for x = 256..319
    lda #0
    sta idx
secondPage:
    ldy idx
    lda sinY + 256, y   // Y coord from second page of table
    sta yTmp
    lda idx              // A = x lo (256+idx, lo byte = idx)
    ldx #1               // X = x hi = 1
    ldy yTmp             // Y = y coord
    jsr hires.lineTo
    inc idx
    lda idx
    cmp #64              // 320 - 256 = 64 points
    bne secondPage

    !: jmp !-

idx:    .byte 0
yTmp:   .byte 0

    hires: createHires(BITMAP_MEM_START, SCREEN_MEM_START)

// Pre-calculated sine curve: Y = 100 + 95 * sin(x * 2π / 320)
// Mapped to 0..199 vertical range across all 320 horizontal pixels
sinY:
    .fill 320, round(100 + 95 * sin(i * 2 * PI / 320))
