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

.macro setColours(hires, fg, bg) {
    lda #(16*fg + bg)
    jsr hires.setColours
}

.macro plot(hires, x, y) {
    lda #<x
    ldx #>x
    ldy #y
    jsr hires.plot
}

.macro createHires(bitmapPtr, screenMemoryPtr) {

    // Jump table
    .label init = *
    jmp _init
    .label clear = *
    jmp _clear
    .label resetColours = *
    jmp _resetColours
    .label setColours = *
    jmp _setColours
    .label plot = *
    jmp _plot
    .label moveTo = *
    jmp _moveTo
    .label lineTo = *
    jmp _lineTo

    // Labels
    .label DEFAULT_COLOUR = LIGHT_GREY + 16*DARK_GREY

    // Methods
    _init: {
        lda #0
        sta __posX
        sta __posX + 1
        sta __posY
        lda #DEFAULT_COLOUR
        sta __colours
        jsr _resetColours
        jsr _clear
        rts
    }

    _clear: {
        lda #<bitmapPtr
        sta targetAddress
        lda #>bitmapPtr
        sta targetAddress + 1

        ldy #40
        outer:
            ldx #0
            lda #0
            inner:
                sta targetAddress:$a000, x
                inx
                cpx #200
            bne inner
            lda targetAddress
            clc
            adc #200
            sta targetAddress
            bcc !+
                inc targetAddress + 1
            !:
            dey
        bne outer
        rts
    }

    _resetColours: {
        lda __colours
        ldx #0
        !:
            sta screenMemoryPtr, x
            sta screenMemoryPtr + 200, x
            sta screenMemoryPtr + 400, x
            sta screenMemoryPtr + 600, x
            sta screenMemoryPtr + 800, x
            inx
            cpx #200
            bne !-
        rts
    }

    _setColours: {
        sta __colours
        rts
    }

    _plot: {
        // In:  A = x lo byte, X = x hi byte (0 or 1), Y = y (0–199)
        // Y is preserved throughout and used as the table index directly.

        sta __xLo
        stx __xHi

        // ── Pixel bitmask: table[$80 >> (xLo & 7)] ───────────────────
        and #%00000111              // xLo & 7  (A still has xLo from entry)
        tax
        lda __maskTable, x
        sta __mask

        // ── Bitmap address ────────────────────────────────────────────
        //
        // addr = __bmYOff[y]           (bitmapPtr + row*320 + ySub, from table)
        //      + (xLo & $F8)           (byte column within the row)
        //      + xHi * 256             (high byte contribution)
        //
        // Carry from lo addition flows naturally into the hi byte.

        lda __xLo
        and #%11111000              // zero the 3 sub-pixel bits
        clc
        adc __bmYOffLo, y           // lo = (xLo & $F8) + table_lo[y]
        sta __rdAddr                // self-modify: read address lo byte
        sta __wrAddr                // self-modify: write address lo byte
        lda __bmYOffHi, y
        adc __xHi                   // hi = table_hi[y] + xHi + carry
        sta __rdAddr + 1            // self-modify: read address hi byte
        sta __wrAddr + 1            // self-modify: write address hi byte

        // ── Read–modify–write the bitmap byte ────────────────────────
        lda __rdAddr:$1234
        ora __mask
        sta __wrAddr:$1234

        // ── Screen colour address ─────────────────────────────────────
        //
        // addr = __scrYOff[y]          (screenMemoryPtr + row*40, from table)
        //      + col                   (col = xHi*32 | xLo>>3, range 0–39)
        //
        // col fits in 6 bits: xLo>>3 uses bits 4:0, xHi<<5 uses bit 5 — no overlap.

        lda __xHi
        asl
        asl
        asl
        asl
        asl                         // xHi * 32  (0 or 32)
        sta __tmp
        lda __xLo
        lsr
        lsr
        lsr                         // xLo >> 3  (0–31)
        ora __tmp                   // col = 0–39
        clc
        adc __scrYOffLo, y          // lo = col + table_lo[y]
        sta __clrAddr               // self-modify: colour write lo byte
        lda __scrYOffHi, y
        adc #0                      // propagate carry only
        sta __clrAddr + 1           // self-modify: colour write hi byte

        // ── Write colour to screen memory ─────────────────────────────
        lda __colours
        sta __clrAddr:$1234

        rts

        // Local scratch
        __xLo:  .byte 0
        __xHi:  .byte 0
        __mask: .byte 0
        __tmp:  .byte 0
    }

    _moveTo: {
        sty __posY
        sta __posX
        stx __posX + 1
        rts
    }

    _lineTo: {
        rts
    }

    // Variables
    __posX: .word 0
    __posY: .byte 0
    __colours: .byte DEFAULT_COLOUR

    //
    // Pixel bitmask
    //
    __maskTable:
        .byte $80, $40, $20, $10, $08, $04, $02, $01

    //
    // Bitmap byte offset for each Y scanline (0–199), base address included.
    //
    __bmYOffLo:
        .fill 200, <(bitmapPtr + (i>>3)*320 + mod(i, 8))
    __bmYOffHi:
        .fill 200, >(bitmapPtr + (i>>3)*320 + mod(i, 8))

    //
    // Screen memory offset for each Y scanline (0–199), base address included.
    //
    __scrYOffLo:
        .fill 200, <(screenMemoryPtr + (i>>3)*40)
    __scrYOffHi:
        .fill 200, >(screenMemoryPtr + (i>>3)*40)
}
