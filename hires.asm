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
        rts
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
}
