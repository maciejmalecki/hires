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

.macro moveTo(hires, x, y) {
    lda #<x
    ldx #>x
    ldy #y
    jsr hires.moveTo
}

.macro lineTo(hires, x, y) {
    lda #<x
    ldx #>x
    ldy #y
    jsr hires.lineTo
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
        // In:  A = x1 lo byte, X = x1 hi byte (0 or 1), Y = y1 (0–199)
        // Draws a line from (__posX, __posY) to (x1, y1) via Bresenham's algorithm.
        // __posX/__posY are updated to (x1, y1) on return.

        sta __x1Lo
        stx __x1Hi
        sty __y1

        // ── Seed working position from stored cursor ──────────────────────
        lda __posX
        sta __cx
        lda __posX + 1
        sta __cx + 1
        lda __posY
        sta __cy

        // ── dx = |x1 − x0|,  sx = sign(x1 − x0) ─────────────────────────
        lda __x1Lo
        sec
        sbc __cx
        sta __dx
        lda __x1Hi
        sbc __cx + 1
        sta __dx + 1            // __dx = x1 − x0  (signed 16-bit)
        bpl __sx_pos
            lda #$ff            // sx = −1
            sta __sx
            lda __dx            // negate __dx
            eor #$ff
            clc
            adc #1
            sta __dx
            lda __dx + 1
            eor #$ff
            adc #0
            sta __dx + 1
            jmp __sx_done
        __sx_pos:
            lda #1
            sta __sx            // sx = +1
        __sx_done:

        // ── dy = |y1 − y0|,  sy = sign(y1 − y0) ─────────────────────────
        lda __y1
        sec
        sbc __cy
        sta __dy                // __dy = y1 − y0  (signed byte)
        bpl __sy_pos
            lda #$ff            // sy = −1
            sta __sy
            lda __dy            // negate __dy
            eor #$ff
            clc
            adc #1
            sta __dy
            jmp __sy_done
        __sy_pos:
            lda #1
            sta __sy            // sy = +1
        __sy_done:

        // ── err = dx − dy  (signed 16-bit) ───────────────────────────────
        lda __dx
        sec
        sbc __dy                // __dy hi-byte is implicitly 0
        sta __err
        lda __dx + 1
        sbc #0
        sta __err + 1

        // ── Main Bresenham loop ───────────────────────────────────────────
        __loop:
            lda __cx
            ldx __cx + 1
            ldy __cy
            jsr _plot           // plot current pixel (reuses all lookup tables)

            // Exit when cursor has reached the destination
            lda __cx
            cmp __x1Lo
            bne __step
            lda __cx + 1
            cmp __x1Hi
            bne __step
            lda __cy
            cmp __y1
            bne !+
                jmp __done
            !:

        __step:
            // e2 = 2 * err
            lda __err
            asl
            sta __e2
            lda __err + 1
            rol
            sta __e2 + 1

            // ── Condition 1: if e2 > −dy  ⟺  (e2 + dy) > 0 ──────────────
            //    → err −= dy;  cx += sx
            lda __e2
            clc
            adc __dy            // dy ≥ 0, so hi-byte contribution = 0
            tax                 // save lo result in X
            lda __e2 + 1
            adc #0              // propagate carry
            bmi __skip_x        // result negative → condition false
            bne __do_x          // hi-byte > 0 → strictly positive
            cpx #0
            beq __skip_x        // both bytes zero → result == 0, not strictly >
        __do_x:
            lda __err
            sec
            sbc __dy
            sta __err
            lda __err + 1
            sbc #0
            sta __err + 1
            // cx += sx
            lda __sx
            bmi __cx_dec
                inc __cx
                bne __skip_x
                inc __cx + 1    // propagate carry into hi byte
                jmp __skip_x
            __cx_dec:
                lda __cx
                bne __cx_no_borrow
                dec __cx + 1    // borrow from hi byte
            __cx_no_borrow:
                dec __cx
        __skip_x:

            // ── Condition 2: if e2 < dx  ⟺  (e2 − dx) < 0 ───────────────
            //    → err += dx;  cy += sy
            //    Both conditions use the same e2 (diagonal steps fire both).
            lda __e2
            sec
            sbc __dx
            lda __e2 + 1
            sbc __dx + 1        // result hi-byte; lo discarded (sign test only)
            bpl __skip_y        // result ≥ 0 → condition false
            lda __err
            clc
            adc __dx
            sta __err
            lda __err + 1
            adc __dx + 1
            sta __err + 1
            // cy += sy
            lda __sy
            bmi __cy_dec
                inc __cy
                jmp __skip_y
            __cy_dec:
                dec __cy
        __skip_y:

            jmp __loop

        // ── Done: commit final position ───────────────────────────────────
        __done:
            lda __x1Lo
            sta __posX
            lda __x1Hi
            sta __posX + 1
            lda __y1
            sta __posY
            rts

        // ── Local scratch / variables ─────────────────────────────────────
        __x1Lo: .byte 0         // destination X lo
        __x1Hi: .byte 0         // destination X hi
        __y1:   .byte 0         // destination Y
        __cx:   .word 0         // current X (working copy)
        __cy:   .byte 0         // current Y (working copy)
        __dx:   .word 0         // |Δx|  (up to 319 → needs 16 bits)
        __dy:   .byte 0         // |Δy|  (up to 199 → fits in 8 bits)
        __sx:   .byte 0         // X step direction: $01 or $ff (−1)
        __sy:   .byte 0         // Y step direction: $01 or $ff (−1)
        __err:  .word 0         // Bresenham error accumulator (signed 16-bit)
        __e2:   .word 0         // 2 * err  (scratch, per iteration)
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
