#環境設定
##名前
NAME = rust_hello

##ターゲット
TARGET_ARCH = x86_64
RUST_TARGET = $(TARGET_ARCH)-unknown-none

##ソフトウェア
STRIP= strip
MKDIR = mkdir -p
CP = cp -r
RM = rm -rf
GRUBMKRES = grub-mkrescue
GRUB2MKRES = grub2-mkrescue #Temporary
AR = ar rcs
LD = ld -n --gc-sections -Map tmp/$(NAME).map -nostartfiles -nodefaultlibs -nostdlib -T linkerscript.ld
CARGO = cargo
ASSEMBLER = nasm -f elf64

##ビルドファイル
KERNELFILES = kernel.elf
RUST_OBJ = target/$(RUST_TARGET)/release/lib$(NAME).a
BOOT_SYS_LIST = tmp/multiboot_header.o tmp/init.o $(RUST_OBJ)


#各コマンド
##デフォルト動作
default:
	-$(MKDIR) tmp
	$(MAKE) $(KERNELFILES)
	-$(MKDIR) tmp/grub-iso/boot/grub/ tmp/grub-iso/boot/$(NAME)/
	$(CP) tmp/kernel.elf tmp/grub-iso/boot/$(NAME)/
	$(CP) grub  tmp/grub-iso/boot/
	$(GRUBMKRES) -o boot.iso tmp/grub-iso/ || $(GRUB2MKRES) -o boot.iso tmp/grub-iso/


clean:
	$(RM) tmp
	$(CARGO) clean


# ファイル生成規則
kernel.elf : $(BOOT_SYS_LIST)
	$(LD) -o tmp/kernel.elf $(BOOT_SYS_LIST)

tmp/%.o : src/boot/%.asm
	$(ASSEMBLER) $< -o $@

$(RUST_OBJ) :  .FORCE
	$(CARGO) xbuild --release --target $(RUST_TARGET_FILE_FOLDER) $(RUST_TARGET)

.FORCE:
 
