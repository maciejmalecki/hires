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

// ── Parameters ──────────────────────────────────────────────────────────────
.label NUM_LINES  = 36          // number of lines to draw
.label ANGLE      = 170         // turning angle between consecutive lines (degrees)
.label LINE_LEN   = 120          // length of each line (pixels)

// ── Memory layout ───────────────────────────────────────────────────────────
.label BITMAP_MEM_START = $4000
.label SCREEN_MEM_START = $6000

// ── Center of the 320x200 screen ────────────────────────────────────────────
.label CENTER_X = 160
.label CENTER_Y = 100

// ── Pre-compute endpoint coordinates at assembly time ───────────────────────
// Turtle graphics: start at origin (0,0), heading upward (270 deg).
// Each line has length LINE_LEN; after each line the heading turns by ANGLE degrees.
// First pass: compute raw coordinates and bounding box.
// Second pass: offset so the shape is centered on screen.

.var startAngle = 270
.var cx = 0
.var cy = 0
.var heading = startAngle

// Raw coordinate arrays (before centering)
.var rawX = List()
.var rawY = List()

.eval rawX.add(cx)
.eval rawY.add(cy)

.for (var i = 0; i < NUM_LINES; i++) {
    .eval cx = cx + LINE_LEN * cos(toRadians(heading))
    .eval cy = cy + LINE_LEN * sin(toRadians(heading))
    .eval rawX.add(cx)
    .eval rawY.add(cy)
    .eval heading = heading + ANGLE
}

// Compute bounding box
.var minX = rawX.get(0)
.var maxX = rawX.get(0)
.var minY = rawY.get(0)
.var maxY = rawY.get(0)
.for (var i = 1; i <= NUM_LINES; i++) {
    .if (rawX.get(i) < minX) .eval minX = rawX.get(i)
    .if (rawX.get(i) > maxX) .eval maxX = rawX.get(i)
    .if (rawY.get(i) < minY) .eval minY = rawY.get(i)
    .if (rawY.get(i) > maxY) .eval maxY = rawY.get(i)
}

// Offset to center the bounding box on screen
.var offX = CENTER_X - (minX + maxX) / 2
.var offY = CENTER_Y - (minY + maxY) / 2

// Final clamped coordinate arrays
.var pointsX = List()
.var pointsY = List()

.for (var i = 0; i <= NUM_LINES; i++) {
    .var px = round(rawX.get(i) + offX)
    .var py = round(rawY.get(i) + offY)
    .if (px < 0) .eval px = 0
    .if (px > 319) .eval px = 319
    .if (py < 0) .eval py = 0
    .if (py > 199) .eval py = 199
    .eval pointsX.add(px)
    .eval pointsY.add(py)
}

*= $0801 "Basic Upstart"
:BasicUpstart(start)

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

    setColours(hires, BLUE, LIGHT_BLUE)
    jsr hires.resetColours

    // moveTo first point
    lda xLo
    ldx xHi
    ldy yCoord
    jsr hires.moveTo

    // draw all lines
    lda #1
    sta idx
loop:
    ldy idx
    lda xLo, y
    sta tmpXLo
    lda xHi, y
    sta tmpXHi
    lda yCoord, y
    sta tmpY

    lda tmpXLo
    ldx tmpXHi
    ldy tmpY
    jsr hires.lineTo

    inc idx
    lda idx
    cmp #NUM_LINES + 1
    bne loop

    !: jmp !-

idx:    .byte 0
tmpXLo: .byte 0
tmpXHi: .byte 0
tmpY:   .byte 0

    hires: createHires(BITMAP_MEM_START, SCREEN_MEM_START)

// ── Pre-computed coordinate tables ──────────────────────────────────────────
xLo:
    .fill NUM_LINES + 1, <pointsX.get(i)
xHi:
    .fill NUM_LINES + 1, >pointsX.get(i)
yCoord:
    .fill NUM_LINES + 1, pointsY.get(i)
