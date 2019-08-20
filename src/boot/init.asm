;Name: src/boot/init.asm

bits 32
global init
extern boot_main

MULTIBOOT_CHECK_MAGIC equ 0x36d76289  ; 正常に処理されたのであれば、EAXに代入されている値

init:
  cli              ; 割り込みを禁止
  ; マジック確認
  cmp   eax, MULTIBOOT_CHECK_MAGIC
  jne   error

  mov   esp, stack ; スタック設定

  ; eflags初期化
  push  0
  popfd

  push  0             ; 64bit popのための準備
  push  ebx           ; Multiboot Information アドレス保存

  pushfd
  pop   eax
  mov   ecx,  eax           ; 比較用にとっておく
  xor   eax,  1 << 21       ; IDフラグを反転
  push  eax
  popfd
  pushfd
  pop   eax
  push  ecx
  popfd                     ; 元に戻す
  xor   eax,  ecx           ; 比較
  jz    error               ; cpuid非対応
  mov   eax,  0x80000000    ; cpuid拡張モードは有効か(使用可能なeaxの最大値が返る)
  cpuid
  cmp   eax,  0x80000001
  jb    error
  mov   eax,  0x80000001
  cpuid                     ; cpuid拡張モード非対応
  test  edx,  1 << 29       ; Long Mode Enable Bitをテスト(64bitモードが有効かどうか)
  jz    error

  ; ページング設定
  xor   ecx,  ecx             ; カウンタリセット

.pde_setup:
  ; 2MB単位メモリページング
  ; PML4->PDP->PDで完結

  mov   eax,  0x200000      ; ページ一つが管理する区域(2MB)(掛け算で 0MB~ => 4MB~=>8MB~と増える)
  mul   ecx                 ; eax = eax * ecx
  or    eax,  0b10000011    ; P(物理メモリ上) + r/w(read and write) + huge(PDEでHugeを立てると２MB単位) 0b:二進数
  mov   [pd + ecx * 8], eax ; 64bitごとの配置
  inc   ecx                 ; ecx++
  cmp   ecx,  2048
  jne   .pde_setup          ; ecx != 512 * 4

  xor   ecx, ecx            ; カウンタリセット

.pdpte_setup:
  mov   eax,  4096
  mul   ecx
  add   eax,  pd            ; この３つで eax = 4096 * ecx + pdしてる
  or    eax,  0b11          ; P(物理メモリ上) + r/w(read and write)
  mov   [pdpt + ecx * 8], eax
  inc   ecx
  cmp   ecx,  4
  jne   .pdpte_setup

;pml4_setup:
  mov   eax,  pdpt
  or    eax,  0b11          ; P(物理メモリ上) + r/w(read and write)
  mov   [pml4], eax         ; ページマップレベル4の最初に追加

;setup_64:
  mov   eax,  pml4
  mov   cr3,  eax           ; PML4Eをcr3に設定する
  mov   eax,  cr4
  or    eax,  1 << 5
  mov   cr4,  eax           ; PAEフラグを立てる
  mov   ecx,  0xc0000080    ; rdmsrのための準備(レジスタ指定)
  rdmsr                     ; モデル固有レジスタに記載(intelの場合pentium以降に搭載、cpuidで検査済)
  or    eax,  1 << 8        ; LMEフラグを立てる
  wrmsr
  mov   eax,  cr0
  or    eax,  1 << 31       ; PGフラグを立てる(これは最後に立てる必要がある)
  mov   cr0,  eax           ; これらの初期化で4GBは仮想メモリアドレスと実メモリアドレスが一致しているはず。(ストレートマッピング)
  lgdt  [gdtr0]
  jmp   main_code_segment_descriptor:init_long_mode ; far jmp

error:
  hlt
  jmp error

bits 64

init_long_mode:
  ; セグメントレジスタ初期化、間違ってもCSはいじるな(FS,GSはマルチスレッドで使用する可能性がある...らしい)
  xor   rax,  rax
  mov   es,   ax
  mov   ss,   ax
  mov   ds,   ax
  mov   fs,   ax
  mov   gs,   ax
  pop   rdi             ; RDI=>RSI=>...が引数リスト
  jmp   boot_main       ; Rustで用意する

section .bss

align 4096

pd:
  ; ページングディレクトリ(8byte * 512) * 4
  resb    4096 * 4
pdpt:
  ; ページディレクトリポインタテーブル(8byte * 512)
  resb    4096
pml4:
  ; ページマップレベル4(8byte * 512)
  resb    4096


resb  1024
stack:

section .data

gdt:
  dq    0                         ; Dummy Entry

main_code_segment_descriptor: equ $ - gdt
    ; すべてコードセグメント
    dq    (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)

gdtr0:
  dw    $ - gdt - 1                 ; リミット数(すぐ上がGDTなので計算で求めてる)
  dq    gdt
