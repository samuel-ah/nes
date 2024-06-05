;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PPU_CTRL = $2000                       ; PPU control flags
                                       ; VPHB SINN
                                       ; NMI enable (V) PPU master/slave (P) sprite height (H) background tile select (B)
                                       ; sprite pattern table address select (0: $0000, 1: $1000) (S) increment mode (I) nametable select (NN)
PPU_MASK = $2001                       ; mask control, color settings **use greyscale mask for interesting effect ?
PPU_STATUS = $2002                     ; PPU status flags
                                       ; VSO- ---- 
                                       ; vblank flag (V) sprite 0hit (S) sprite overflow (O) unused (-)
                                       ; NOTE: read from this address to reset write flag for PPUADDR
                                       ; to allow PPU VRAM address to be changed
OAM_ADDR = $2003                       ; points to address of OAM being used, usually ignored and set to $00 as DMA is better
OAM_DATA = $2004                       ; OAM data read/write
PPU_SCROLL = $2005
PPU_ADDR = $2006                       ; PPU accessing address read/write (2 byte address, HI byte first. Read from $2002 before this.)
PPU_DATA = $2007                       ; PPU data write
DMC_FREQ = $4010
OAM_DMA = $4014

JOYPAD_1 = $4016
JOYPAD_2 = $4017

PAD_A = $80
PAD_B = $40
PAD_SELECT = $20
PAD_START = $10
PAD_UP = $08
PAD_DOWN = $04
PAD_LEFT = $02
PAD_RIGHT = $01

SPRITE_PAGE = $0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "HEADER"
    .byte "NES", $1a                   ; iNES header format
    .byte $02                          ; 2 segments 16kb PRG
    .byte $01                          ; 1 segments 8kb CHR
    .byte $00                          ; mapper 0

.segment "VECTORS"
    .addr NMI
    .addr RESET
    .addr 0                            ; irq unused

.segment "STARTUP"

.segment "ZEROPAGE"
    NMI_FLAGS: .res 1                  ; ----RPSN
                                       ;     |||+- 0: NMI occurred
                                       ;     ||+-- 1: Safe to enter NMI
                                       ;     |+--- 1: Update palettes during NMI
                                       ;     +---- 1: Disable rendering during NMI
    MISC_FLAGS: .res 1                 ; ------TI
                                       ;       |+- 1: Ignore input this frame
                                       ;       +-- 1: Title graphics currently loaded
    GAMEMODE: .res 1                   ; 0: Title screen
                                       ; 1: Game
                                       ; 2: 2P Game
                                       ; 3: Game over
    XSCROLL: .res 1
    YSCROLL: .res 1
    JOYPAD_1_BUTTONS: .res 1
    JOYPAD_2_BUTTONS: .res 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"

RESET:
    sei                                ; disable irq
    cld                                ; disable broken decimal mode

    ldx #%01000000                     ; disable APU irqs
    stx JOYPAD_2
    
    ldx #$ff                           ; initialize stack
    txs
    
    inx                                ; X: 255 -> 0

    stx PPU_CTRL                       ; disable nmi
    stx PPU_MASK                       ; disable screen output 
    stx DMC_FREQ                       ; disable APU DMC (delta modulation channel) irqs

    jsr NMI_WAIT_RESET                 ; first wait for NMI

    :   lda #00                        ; clear WRAM
        sta $0000, X
        sta $0100, X
        sta $0200, X
        sta $0300, X
        sta $0400, X
        sta $0500, X
        sta $0600, X
        sta $0700, X
        inx
        bne :-

    jsr NMI_WAIT_RESET

PALETTE_INIT:                          ; FIXME: initialize to title screen palette
    lda PPU_STATUS                     ; clear PPUADDR write flag

    lda #$3f                           ; set palette transfer address
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR

    ldx #$00

    :   lda PALETTES, X
        sta PPU_DATA
        inx
        cpx #$20                       ; 32 bytes (4x4 bytes * 2 palette sets)
        bne :-

TEST_SPRITE_INIT:
    ldx #$00

    :   lda SPRITES_DEFAULT, X
        sta SPRITE_PAGE, X
        inx
        cpx #$04
        bne :-

FILL_TEST_NT:
    lda PPU_STATUS
    lda #$20                           ; $2000 start of first nametable
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldy #$08
    ldx #$00
    lda #$00

    :   sta PPU_DATA
        dex
        bne :-
        dey
        bne :-

FILL_TEST_AT:
    lda PPU_STATUS
    lda #$23                           ; $23c0 start of first attribute table
    sta PPU_ADDR
    lda #$c0
    sta PPU_ADDR
    ldx #$40                           ; 64
    lda #$00

    :   sta PPU_DATA
        dex
        bne :-

GAME_STATE_INIT:
    lda #$00
    sta GAMEMODE

ENABLE_RENDER_INIT:
    lda #%10010000                     ; nmi enable
    sta PPU_CTRL

    lda #%00011110                     ; sprite enable
    sta PPU_MASK

NMI_FLAGS_INIT:
    lda #%00000001
    sta NMI_FLAGS

MAIN:                                  
    nop
    jsr READ_JOYPAD_1

LOGIC_STATE:
    ldx GAMEMODE
    beq LOGIC_TITLE
    dex
    beq LOGIC_1P_GAME
    dex
    beq LOGIC_2P_GAME
    jmp LOGIC_GAME_OVER

LOGIC_TITLE:
    lda MISC_FLAGS
    and #%00000010
    bne TGFX_LOADED

LOAD_TGFX:
    jsr DISABLE_RENDER
    jsr DISABLE_INPUT
    jsr NMI_WAIT_SAFE
    jsr LOAD_TGFX_NT
    jsr SET_TGFX_LOADED
    jsr ENABLE_RENDER
    jsr ENABLE_INPUT

    ; set selection to 0

    lda #$ef
    sta YSCROLL
    jmp LOGIC_TITLE_DONE

TGFX_LOADED:
    lda YSCROLL
    beq TITLE_ANIM_DONE
    lda JOYPAD_1_BUTTONS
    bne TITLE_SKIP_ANIM

TITLE_ANIM_CONTINUE:
    dec YSCROLL
    jsr ENABLE_INPUT
    jmp LOGIC_TITLE_DONE

TITLE_SKIP_ANIM:
    lda #$00
    sta YSCROLL
    jsr DISABLE_INPUT
    jmp LOGIC_TITLE_DONE

TITLE_ANIM_DONE:
    lda JOYPAD_1_BUTTONS
    and #%00101100 ; Select, up, or down pressed
    bne TITLE_CHANGE_SELECTION

TITLE_CHECK_START:
    lda JOYPAD_1_BUTTONS
    and #%10010000 ; A or Start pressed
    bne TITLE_START_GAME
    jsr ENABLE_INPUT
    jmp LOGIC_TITLE_DONE

TITLE_CHANGE_SELECTION:
    jmp LOGIC_TITLE_DONE
;     lda MISC_FLAGS
;     and #%00000001
;     beq LOGIC_TITLE_DONE
;     lda TITLE_GAME_SELECTION
;     eor #%00000001
;     sta TITLE_GAME_SELECTION
;     jsr SET_NT_UPDATE
;     jsr TITLE_SELECTION_NT_UPDATE
;     jsr DISABLE_INPUT
;     jmp LOGIC_TITLE_DONE

TITLE_START_GAME:
    jmp LOGIC_TITLE_DONE
    ;;;;

LOGIC_TITLE_DONE:
LOGIC_1P_GAME:
LOGIC_2P_GAME:
LOGIC_GAME_OVER:
    jmp WAIT_NEXT_FRAME

WAIT_NEXT_FRAME:
    jsr NMI_WAIT_SAFE
    jmp MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NMI_WAIT_RESET:
    bit PPU_STATUS
    bpl NMI_WAIT_RESET
    rts
;
NMI_WAIT_SAFE:
    lda NMI_FLAGS
    ora #%00000010
    sta NMI_FLAGS

    :   lda NMI_FLAGS                  ; NMI_FLAGS == 0 when returning from NMI
        bne :-
    
    inc NMI_FLAGS                      ; set unsafe to enter NMI, clear 'NMI occurred'
    rts
;
READ_JOYPAD_1:
    lda #$01
    sta JOYPAD_1                       ; write 1 then 0 to controller port to start serial transfer
    sta JOYPAD_1_BUTTONS               ; store 1 in buttons
    lsr A                              ; A: 1 -> 0
    sta JOYPAD_1

    :   lda JOYPAD_1
        lsr A                          ; bit 0 -> C
        rol JOYPAD_1_BUTTONS           ; C -> bit 0 in JOYPAD_1_BUTTONS, shift all other to left
        bcc :-                         ; if sentinel bit shifted out end loop
    
    rts
;
DISABLE_INPUT:
    lda MISC_FLAGS
    ora #%00000001
    sta MISC_FLAGS
    rts
;
ENABLE_INPUT:
    lda MISC_FLAGS
    and #%11111110
    sta MISC_FLAGS
    rts
;
DISABLE_RENDER:
    lda NMI_FLAGS
    ora #%00001000
    sta NMI_FLAGS
    rts
;
ENABLE_RENDER:
    lda NMI_FLAGS
    and #%11110111
    sta NMI_FLAGS
    rts
;
SET_TGFX_LOADED:
    lda MISC_FLAGS
    ora #%00000010
    sta MISC_FLAGS
    rts
;
CLEAR_TGFX_LOADED:
    lda MISC_FLAGS
    and #%11111101
    sta MISC_FLAGS
    rts
;
LOAD_TGFX_NT:
    lda PPU_STATUS
    lda #$20
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldx #$00
    ldy #$04
    lda #$00
    
    :   sta PPU_DATA
        dex
        bne :-
        dey
        bne :-

    lda PPU_STATUS
    lda #$28
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldx #$00
    ldy #$04
    lda #$01
    
    :   sta PPU_DATA
        dex
        bne :-
        dey
        bne :-

AT_TOP:
    lda PPU_STATUS
    lda #$23
    sta PPU_ADDR
    lda #$c0
    sta PPU_ADDR
    ldx #$40
    lda #$00

    :   sta PPU_DATA
        dex
        bne :-

    lda PPU_STATUS
    lda #$2b
    sta PPU_ADDR
    lda #$c0
    sta PPU_ADDR
    ldx #$40
    lda #%10101010

    :   sta PPU_DATA
        dex
        bne :-
        rts

    lda #$00

;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
    lda NMI_FLAGS
    and #%00000010
    beq NMI_DONE

SPRITE_DMA:
    lda #$00                           ; set index into DMA page to 00
    sta OAM_ADDR
    lda #$02                           ; start OAM DMA from page at $0200
    sta OAM_DMA

; HORIZ_SCROLL:
;     lda PPU_STATUS
;     inc XSCROLL
;     lda XSCROLL
;     sta PPU_SCROLL
;     lda #$00
;     sta PPU_SCROLL
Y_SCROLL:
    lda PPU_STATUS
    lda #$00
    sta PPU_SCROLL
    lda YSCROLL
    sta PPU_SCROLL

SELECT_NAMETABLE:
    lda #%10010000
    sta PPU_CTRL

ENABLE_RENDER:
    lda NMI_FLAGS
    and #%00001000
    bne NMI_DONE
    lda #%00011110
    sta PPU_MASK

NMI_DONE:
    lda #$00
    sta NMI_FLAGS

    pla
    tay
    pla
    tax
    pla
    
    rti
.endscope
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SPRITES_DEFAULT:
        ; y    tile attr x
    .byte $20, $00, $00, $20

PALETTES:
    BG_PALETTES:
        .byte $0f, $30, $10, $00       ; black, green
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
    SPRITE_PALETTES:
        .byte $0f, $12, $12, $12       ; black, blue, blue, blue
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CHARS"
.incbin "chars.chr"