; LOGIC_TITLE:
    ; title graphics loaded?
    ;yes -> branch to TGFX_LOADED
    ; no:
        ; disable render
        ; disable input
        ; wait for nmi
        ; load gfx
        ; set loaded flag
        ; set YSCROLL -> $ef
        ; enable render
        ; enable input
        ; mode selection -> 0
        ; jump to done

; TGFX_LOADED:
    ; check if yscroll == 0
    ; yes -> branch to TITLE_ANIM_DONE
    ; no:
        ; check for any button being pressed
        ; yes -> branch to TITLE_SKIP_ANIM
        ; no:
            ; dec YSCROLL
            ; enable input
            ; jump to done
        
        ; TITLE_SKIP_ANIM:
            ; set YSCROLL -> 0
            ; disable input
            ; jump to done

; TITLE_ANIM_DONE:
    ; check input enabled
    ; yes -> branch to TITLE_INPUT_ENABLED
    ; no:
        ; check any button pressed
        ; yes -> branch to done
        ; no:
            ; enable input
            ; jump to done

    ; TITLE_INPUT_ENABLED:
        ; check s/u/d pressed
        ; yes -> branch to TITLE_CHANGE_SELECTION
        ; no: 
            ; check for start/a pressed
            ; yes -> branch to TITLE_START_GAME
            ; no: branch to done
        
        ; TITLE_CHANGE_SELECTION:
            ; eor selection
            ; update arrow position
            ; disable input
            ; branch to done


LOGIC_TITLE:
    lda MISC_FLAGS
    and #%00000010
    bne TGFX_LOADED

    :   jsr DISABLE_RENDER
        jsr DISABLE_INPUT
        jsr NMI_WAIT_SAFE
        jsr LOAD_TGFX_NT
        jsr SET_TGFX_LOADED
        
        lda #$ef
        sta YSCROLL

        jsr ENABLE_RENDER
        jsr ENABLE_INPUT

        lda #$00
        sta TITLE_GAMEMODE_SELECTION

        jmp LOGIC_TITLE_DONE
    
TGFX_LOADED:
    lda YSCROLL
    beq TITLE_ANIM_DONE

    :   lda JOYPAD_1_BUTTONS
        bne TITLE_SKIP_ANIM

        :   dec YSCROLL
            jsr ENABLE_INPUT
            jmp LOGIC_TITLE_DONE
    
    TITLE_SKIP_ANIM:
        lda #$00
        sta YSCROLL
        jsr DISABLE_INPUT
        jmp LOGIC_TITLE_DONE

TITLE_ANIM_DONE:
    lda MISC_FLAGS
    and #%00000001
    beq TITLE_INPUT_ENABLED

    :   lda JOYPAD_1_BUTTONS
        bne LOGIC_TITLE_DONE

        :   jsr ENABLE_INPUT
            jmp LOGIC_TITLE_DONE
    
    TITLE_INPUT_ENABLED:
        lda JOYPAD_1_BUTTONS
        and #%00101100
        bne TITLE_CHANGE_SELECTION

        :   lda JOYPAD_1_BUTTONS
            and #%10010000
            bne TITLE_START_GAME
            jmp LOGIC_TITLE_DONE

    TITLE_CHANGE_SELECTION:
        lda TITLE_GAMEMODE_SELECTION
        eor #%00000001
        sta TITLE_GAMEMODE_SELECTION
        bne TITLE_SELECTION_1
    
    TITLE_SELECTION_0:
        lda #$20
        sta #$0204
        jmp LOGIC_TITLE_DONE

    TITLE_SELECTION_1:
        lda #$28
        sta #$0204
        jmp LOGIC_TITLE_DONE
    
TITLE_START_GAME:
    jmp LOGIC_TITLE_DONE

LOGIC_TITLE_DONE:

; LOGIC_TITLE:
;     lda MISC_FLAGS
;     and #%00000010
;     bne TGFX_LOADED

; LOAD_TGFX:
;     jsr DISABLE_RENDER
;     jsr DISABLE_INPUT
;     jsr NMI_WAIT_SAFE
;     jsr LOAD_TGFX_NT
;     jsr SET_TGFX_LOADED
;     lda #$ef                           ; starting scroll value 239
;     sta YSCROLL
;     jsr ENABLE_RENDER
;     jsr ENABLE_INPUT

;     ; set selection to 0

;     jmp LOGIC_TITLE_DONE

; TGFX_LOADED:
;     lda YSCROLL
;     beq TITLE_ANIM_DONE
;     lda JOYPAD_1_BUTTONS
;     bne TITLE_SKIP_ANIM

; TITLE_ANIM_CONTINUE:
;     dec YSCROLL
;     jsr ENABLE_INPUT
;     jmp LOGIC_TITLE_DONE

; TITLE_SKIP_ANIM:
;     lda #$00
;     sta YSCROLL
;     jsr DISABLE_INPUT
;     jmp LOGIC_TITLE_DONE

; TITLE_ANIM_DONE:
;     lda JOYPAD_1_BUTTONS
;     and #%00101100 ; Select, up, or down pressed
;     bne TITLE_CHANGE_SELECTION

; TITLE_CHECK_START:
;     lda JOYPAD_1_BUTTONS
;     and #%10010000 ; A or Start pressed
;     bne TITLE_START_GAME
;     jsr ENABLE_INPUT
;     jmp LOGIC_TITLE_DONE

; TITLE_CHANGE_SELECTION:
;     lda MISC_FLAGS
;     and #%00000001
;     bne LOGIC_TITLE_DONE
;     lda TITLE_GAMEMODE_SELECTION
;     eor #%00000001
;     sta TITLE_GAMEMODE_SELECTION
;     bne TITLE_SELECTION_1
; TITLE_SELECTION_0:
;     lda #$20 ; change for positions of options
;     sta $0204 ; sprite 1 ypos
;     jmp TITLE_SELECTION_CHANGE_DONE
; TITLE_SELECTION_1:
;     lda #$28
;     sta $0204
; TITLE_SELECTION_CHANGE_DONE:
;     jsr DISABLE_INPUT
;     jmp LOGIC_TITLE_DONE

; TITLE_START_GAME:
;     jmp LOGIC_TITLE_DONE
;     ;;;;

; LOGIC_TITLE_DONE:
; LOGIC_1P_GAME:
; LOGIC_2P_GAME:
; LOGIC_GAME_OVER:
