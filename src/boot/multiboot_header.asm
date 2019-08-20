;Name: src/boot/multiboot_header.asm
bits    32

global  boot_entry
extern  init

;========================================
MULTIBOOT_HEADER_MAGIC    equ 0xe85250d6  ; 合言葉
MULTIBOOT_HEADER_ARCH     equ 0           ; 4ならmips
MULTIBOOT_HEADER_LEN      equ multiboot_end - multiboot_start
MULTIBOOT_HEADER_CHECKSUM equ \
  -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_ARCH + \
    MULTIBOOT_HEADER_LEN)
MULTIBOOT_HEADER_FLAG     equ 1           ; タグで使うフラグ
MULTIBOOT_HEADER_TAG_END  equ 0
;========================================

; マルチブート用ヘッダー
section .multiboot_header  ; 特殊な扱いのセクションにする(配置固定 & 最適化無効)

jmp     boot_entry    ; 下を実行されたらまずいのでjmp

align   8

multiboot_start:
 dd      MULTIBOOT_HEADER_MAGIC
 dd      MULTIBOOT_HEADER_ARCH
 dd      MULTIBOOT_HEADER_LEN
 dd      MULTIBOOT_HEADER_CHECKSUM

; ここに追加のタグを書く
multiboot_tags_start:
 align   8                       ; タグは8バイト間隔で並ぶ必要がある
 dw      MULTIBOOT_HEADER_TAG_END
 dw      MULTIBOOT_HEADER_FLAG
 dd      8
multiboot_tags_end:
multiboot_end:
; マルチブート用ヘッダー実体記述終了
;========================================

section .text

boot_entry:
  jmp init 
