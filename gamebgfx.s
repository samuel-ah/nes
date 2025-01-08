; reserve row buffer index R_BUF_IDX

lda m_rbuf_idx
cmp #$08
bne WAIT_NEXT_FRAME

:   jsr RNG
    and #%00001111 ; get number 0-15
    clc
    lsr A ; bit 0 -> C
    sta m_block_hi ; num 0-7 -> high address byte
    lda #$00 ; clear A
    sta m_rbuf_idx
    ror A ; C -> bit 7 in A
    sta m_block_lo ; $00 or $80 -> low address byte
    
    lda .lobyte(COURSE_BLOCKS)
    clc
    adc m_block_lo
    sta m_block_lo
    lda .hibyte(COURSE_BLOCKS)
    adc m_block_hi
    sta m_block_hi

    ldx #$00

    :   lda (m_block_lo), X ; copy 128 tiles to framebuffer
        sta F_BUF, X
        inx
        cpx #$80
        bne :-

DONE:
;...

;store m_block_lo before m_block_hi when allocating
; to load tile: lda (m_block_lo), Y 

;

;shift right once to get high address byte
; 00001111 - 15
; -> 00000111 - 7

; 00000101 - 5
; -> 00000010 - 2

; lowest bit is 1? -> low address byte is $80


; block 0 at $0000 - $007F
; block 1 at $0080 - $00FF
; block 2 at $0100 - $017F
; block 3 at $0180 - $01FF
; block 4 at $0200 - $027F
; block 5 at $0280 - $02FF

; block 15 at $0780 - $07FF