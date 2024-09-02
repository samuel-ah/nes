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
PPU_ADDR = $2006                       ; PPU accessing address read/write
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
SPRITE_0_YPOS = $0200
SPRITE_0_TILE = $0201
SPRITE_0_ATTR = $0202
SPRITE_0_X = $0203

F_BUF = $0300

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
    m_nmi_flags: .res 1                ; -DIWRPSN
                                       ;  ||||||+- 0: NMI occurred
                                       ;  |||||+-- 1: Safe to enter NMI
                                       ;  ||||+--- 1: Update palettes during NMI
                                       ;  |||+---- 1: Disable rendering during NMI
                                       ;  ||+----- 1: Load new row this frame
                                       ;  |+------ 1: Increment YSCROLL this frame
                                       ;  +------- 1: Decrement YSCROLL this frame

    m_misc_flags: .res 1               ; ------TI
                                       ;       |+- 1: Ignore input this frame
                                       ;       +-- 1: Title graphics currently loaded
    m_nametable: .res 1                ; Current nametable selected
    m_gamemode: .res 1                 ; 0: Title screen
                                       ; 1: Game
    m_xscroll: .res 1
    m_yscroll: .res 1
    m_joypad_1_buttons: .res 1
    m_title_selection: .res 1
    m_row_hi: .res 1
    m_row_lo: .res 1

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

GAME_STATE_INIT:
    lda #$00
    sta m_gamemode

ENABLE_NMI_INIT:
    lda #%10010000                     ; nmi enable
    sta PPU_CTRL

NMI_FLAGS_INIT:
    lda #%00000001                     
    sta m_nmi_flags

RENDER_INIT:
    jsr ENABLE_RENDER                  ; Enable rendering only after startup routine done

MAIN:                                  
    nop
    nop
    nop
    jsr READ_JOYPAD_1

LOGIC_STATE:
    ldx m_gamemode
    beq LOGIC_TITLE
    jmp LOGIC_MAIN_GAME

LOGIC_TITLE:
    lda m_misc_flags                     ; title graphics loaded?
    and #%00000010
    bne TGFX_LOADED

    :   jsr DISABLE_RENDER             ; disable render
        jsr DISABLE_INPUT              ; disable input
        jsr NMI_WAIT_SAFE              ; wait one frame
        jsr LOAD_TGFX_NT               ; load title graphics
        jsr SET_TGFX_LOADED            ; set title graphics loaded flag
        
        lda #$ef                       ; set YSCROLL to 239
        sta m_yscroll

        jsr ENABLE_RENDER              ; enable render
        jsr ENABLE_INPUT               ; enable input

        lda #$00                       ; set selection to 0
        sta m_title_selection  

        jmp LOGIC_TITLE_DONE
    
TGFX_LOADED:
    lda m_yscroll                        ; YSCROLL == 0?
    beq TITLE_ANIM_DONE

    :   lda m_joypad_1_buttons           ; any buttons pressed?
        bne TITLE_SKIP_ANIM

        :   jsr SET_SCROLL_DEC                ; decrease scroll 
            jsr ENABLE_INPUT           ; enable input
            jmp LOGIC_TITLE_DONE
    
    TITLE_SKIP_ANIM:
        lda #$00                       ; set YSCROLL to 0
        sta m_yscroll
        jsr DISABLE_INPUT              ; disable input
        jmp LOGIC_TITLE_DONE

TITLE_ANIM_DONE:
    lda m_misc_flags                     ; input enabled?
    and #%00000001
    beq TITLE_INPUT_ENABLED

    :   lda m_joypad_1_buttons           ; any buttons pressed?
        bne LOGIC_TITLE_DONE

        :   jsr ENABLE_INPUT           ; enable input
            jmp LOGIC_TITLE_DONE       
    
    TITLE_INPUT_ENABLED:
        lda m_joypad_1_buttons           ; select/up/down pressed?
        and #%00101100
        bne TITLE_CHANGE_SELECTION

        :   lda m_joypad_1_buttons       ; start/A pressed?
            and #%10010000
            bne TITLE_START_GAME
            jmp LOGIC_TITLE_DONE

    TITLE_CHANGE_SELECTION:
        jsr DISABLE_INPUT
        lda m_title_selection   ; flip gamemode selection
        eor #%00000001
        sta m_title_selection
        bne TITLE_SELECTION_1
    
    TITLE_SELECTION_0:
        lda #$20                       ; y position 0
        sta SPRITE_PAGE
        jmp LOGIC_TITLE_DONE

    TITLE_SELECTION_1: 
        lda #$28                       ; y position 1
        sta SPRITE_PAGE
        jmp LOGIC_TITLE_DONE
    
TITLE_START_GAME:
    jsr SET_GAMEMODE_MAIN_GAME

    ldx #$00

    :   lda TEST_ROW, X
        sta F_BUF, X
        inx
        cpx #$20
        bne :-
    
    jmp LOGIC_TITLE_DONE

LOGIC_TITLE_DONE:
    jmp WAIT_NEXT_FRAME

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LOGIC_MAIN_GAME:
    jsr SET_SCROLL_INC
    lda m_yscroll
    cmp #$f0
    bne CONTINUE_SCROLL

    :   lda #$00
        sta m_yscroll
        jsr SWAP_NAMETABLE
    
CONTINUE_SCROLL:
    lda m_yscroll
    and #%00000111
    bne NO_GFX_UPDATE
    
    :   jsr SET_ROW_LOAD

NO_GFX_UPDATE:
    jmp WAIT_NEXT_FRAME

WAIT_NEXT_FRAME:
    jsr NMI_WAIT_SAFE                  ; wait for next frame
    jmp MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NMI_WAIT_RESET:
    bit PPU_STATUS                     ; bit 7 of PPU_STATUS
    bpl NMI_WAIT_RESET
    rts
;
NMI_WAIT_SAFE:
    lda m_nmi_flags
    ora #%00000010
    sta m_nmi_flags

    :   lda m_nmi_flags                ; m_nmi_flags == 0 when returning from NMI
        bne :-
    
    inc m_nmi_flags                    ; set unsafe to enter NMI, clear 'NMI occurred'
    rts
;
READ_JOYPAD_1:
    lda #$01
    sta JOYPAD_1                       ; write 1 then 0 to controller port to start serial transfer
    sta m_joypad_1_buttons             ; store 1 in buttons
    lsr A                              ; A: 1 -> 0
    sta JOYPAD_1

    :   lda JOYPAD_1
        lsr A                          ; bit 0 -> C
        rol m_joypad_1_buttons         ; C -> bit 0 in m_joypad_1_buttons, shift all other to left
        bcc :-                         ; if sentinel bit shifted out end loop
    
    rts
;
DISABLE_INPUT:
    lda m_misc_flags
    ora #%00000001
    sta m_misc_flags
    rts
;
ENABLE_INPUT:
    lda m_misc_flags
    and #%11111110
    sta m_misc_flags
    rts
;
DISABLE_RENDER:
    lda m_nmi_flags
    ora #%00001000
    sta m_nmi_flags
    rts
;
ENABLE_RENDER:
    lda m_nmi_flags
    and #%11110111
    sta m_nmi_flags
    rts
;
SET_TGFX_LOADED:
    lda m_misc_flags
    ora #%00000010
    sta m_misc_flags
    rts
;
CLEAR_TGFX_LOADED:
    lda m_misc_flags
    and #%11111101
    sta m_misc_flags
    rts
;
SET_GAMEMODE_MAIN_GAME:
    lda #$01
    sta m_gamemode
    rts
;
SET_ROW_LOAD:
    lda m_nmi_flags
    ora #%00010000
    sta m_nmi_flags
    rts
;
SWAP_NAMETABLE:
    lda m_nametable
    eor #%00000010
    sta m_nametable
    rts 
;
SET_SCROLL_INC:
    lda m_nmi_flags
    ora #%00100000
    sta m_nmi_flags
    rts
;
SET_SCROLL_DEC:
    lda m_nmi_flags
    ora #%01000000
    sta m_nmi_flags
    rts
;
LOAD_TGFX_NT:
    lda PPU_STATUS                     ; Fill upper NT
    lda #$20
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

    lda PPU_STATUS                     ; Fill lower NT
    lda #$28
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

LOAD_TGFX_AT:
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
    lda #$00

    :   sta PPU_DATA
        dex
        bne :-
        rts
;

TEST_ROW:
    .byte $10, $11, $12, $13, $14, $15, $16, $17
    .byte $10, $11, $12, $13, $14, $15, $16, $17
    .byte $10, $11, $12, $13, $14, $15, $16, $17
    .byte $10, $11, $12, $13, $14, $15, $16, $17

SPRITES_DEFAULT:
        ; y    tile attr x
    .byte $20, $00, $00, $20

PALETTES:
    BG_PALETTES:
        .byte $0f, $30, $10, $31       ; black, white, light gray, dark gray
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
    SPRITE_PALETTES:
        .byte $0f, $2a, $1a, $0a       ; black, greens
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty
        .byte $0f, $00, $00, $00       ; empty

.include "nmi.s"

.segment "CHARS"
    .incbin "chars.chr"