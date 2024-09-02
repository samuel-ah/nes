NMI:
.scope NMI_LOCAL
    pha
    txa
    pha
    tya
    pha

DISABLE_RENDER:
    lda #$00
    sta PPU_MASK

CHECK_NMI_SAFE:
    lda m_nmi_flags
    and #%00000010
    beq NMI_DONE

SPRITE_DMA:
    lda #$00                           ; set index into DMA page to 00
    sta OAM_ADDR
    lda #$02                           ; start OAM DMA from page at $0200
    sta OAM_DMA

LOAD_GFX_ROW:
    lda m_nmi_flags
    and #%00010000
    beq SCROLL_UPDATE                  ; flag for next row to be loaded

    :   lda m_yscroll                  ; find HI offset from $20 or $28, bits 7, 6 of YSCROLL -> m_row_hi (every 8 rows of tiles adds $0100 to PPU_ADDR)
        lsr A
        lsr A
        lsr A
        lsr A
        lsr A
        lsr A
        sta m_row_hi

        lda m_nametable                ; determine whether to offset from $20 or $28, load new row in nametable not currently being used
        eor #%00000010
        asl A
        asl A
        clc 
        adc #$20
        clc
        adc m_row_hi
        sta m_row_hi                   ; determine final hi byte of PPU_ADDR

        lda m_yscroll
        asl A
        asl A
        sta m_row_lo

        lda PPU_STATUS
        lda m_row_hi
        sta PPU_ADDR
        lda m_row_lo
        sta PPU_ADDR

        ldx #$00

        :   lda F_BUF, X
            sta PPU_DATA
            inx
            cpx #$20
            bne :-

SCROLL_UPDATE:
    lda PPU_STATUS
    lda m_xscroll
    sta PPU_SCROLL
    lda m_yscroll
    sta PPU_SCROLL

INC_SCROLL:
    lda m_nmi_flags
    and #%00100000
    beq DEC_SCROLL

    :   inc m_yscroll

DEC_SCROLL:
    lda m_nmi_flags
    and #%01000000
    beq SELECT_NAMETABLE

    :   dec m_yscroll

SELECT_NAMETABLE:
    lda m_nametable
    ora #%10010000
    sta PPU_CTRL

ENABLE_RENDER:
    lda m_nmi_flags
    and #%00001000
    bne NMI_DONE
    lda #%00011110
    sta PPU_MASK

NMI_DONE:
    lda #$00
    sta m_nmi_flags

    pla
    tay
    pla
    tax
    pla
    
    rti
.endscope