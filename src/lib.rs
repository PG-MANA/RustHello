#![no_std]
#![feature(asm)]
#![feature(panic_info_message)]
#![feature(core_panic_info)]

mod framebuffer_manager;

use core::fmt;
use core::panic;
use framebuffer_manager::FramebufferManager;

static mut FRAMEBUFFER: FramebufferManager = FramebufferManager::static_new();

#[no_mangle]
extern "C" fn boot_main(mbi_address: usize /*マルチブートヘッダのアドレス*/) {
    if mbi_address & 7 != 0 {
        //アドレスのアライメントチェック
        hlt_loop();
    }
    if unsafe { *(mbi_address as *mut u32) } == 0 {
        //MultiBootInformationのサイズ確認
        hlt_loop();
    }
    set_framebuffer_manager(mbi_address);
    println!(
        "Hello,world!!\nMultiBootInformation's address:{}",
        mbi_address
    );
    hlt_loop();
}

fn hlt_loop() -> ! {
    loop {
        unsafe {
            asm!("hlt");
        }
    }
}

//構造体
#[repr(C)] //Rustではstructが記述通りに並んでない
struct MultibootTag {
    s_type: u32,
    size: u32,
}

fn set_framebuffer_manager(mbi_address: usize) {
    //const TAG_ALIGN: u32 = 8;
    const TAG_TYPE_END: u32 = 0;
    //const TAG_TYPE_CMDLINE: u32 = 1;
    //const TAG_TYPE_BOOT_LOADER_NAME: u32 = 2;
    //const TAG_TYPE_MODULE: u32 = 3;
    //const TAG_TYPE_BASIC_MEMINFO: u32 = 4;
    //const TAG_TYPE_BOOTDEV: u32 = 5;
    //const TAG_TYPE_MMAP: u32 = 6;
    //const TAG_TYPE_VBE: u32 = 7;
    const TAG_TYPE_FRAMEBUFFER: u32 = 8;
    //const TAG_TYPE_ELF_SECTIONS: u32 = 9;
    //const TAG_TYPE_APM: u32 = 10;
    //const TAG_TYPE_EFI32: u32 = 11;
    //const TAG_TYPE_EFI64: u32 = 12;
    //const TAG_TYPE_SMBIOS: u32 = 13;
    //const TAG_TYPE_ACPI_OLD: u32 = 14;
    //const TAG_TYPE_ACPI_NEW: u32 = 15;
    //const TAG_TYPE_NETWORK: u32 = 16;
    //const TAG_TYPE_EFI_MMAP: u32 = 17;
    //const TAG_TYPE_EFI_BS: u32 = 18;
    //const TAG_TYPE_EFI32_IH: u32 = 19;
    //const TAG_TYPE_EFI64_IH: u32 = 20;
    //const TAG_TYPE_BASE_ADDR: u32 = 21;

    let mut multiboot_information_tag = mbi_address + 8;

    loop {
        let tag_type: u32 =
            unsafe { (&*(multiboot_information_tag as *const MultibootTag)).s_type };
        match tag_type {
            TAG_TYPE_END => {
                break;
            }
            TAG_TYPE_FRAMEBUFFER => {
                unsafe {
                    FRAMEBUFFER =
                        FramebufferManager::new(&*(multiboot_information_tag as *const _));
                }
                break;
            }
            _ => {}
        }
        multiboot_information_tag +=
            ((unsafe { (&*(multiboot_information_tag as *const MultibootTag)).size } as usize) + 7)
                & !7;
    }
}

fn put_to_framebuffer(args: fmt::Arguments) -> bool {
    use core::fmt::Write;
    if unsafe { FRAMEBUFFER.write_fmt(args).is_ok() } {
        true
    } else {
        false
    }
}

#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => {
        $crate::put_to_framebuffer(format_args!($($arg)*));
    };
}

#[macro_export]
macro_rules! println {
    ($fmt:expr) => (print!(concat!($fmt,"\n")));
    ($fmt:expr, $($arg:tt)*) => (print!(concat!($fmt, "\n"),$($arg)*)); //\nをつける
}

#[panic_handler]
#[no_mangle]
pub fn panic(info: &panic::PanicInfo) -> ! {
    let location = info.location();
    let message = info.message();

    println!("Panic Info");
    if location.is_some() && message.is_some() {
        println!(
            "Line {} in {}\nMessage: {}",
            location.unwrap().line(),
            location.unwrap().file(),
            message.unwrap()
        );
    } else {
        println!("Not provided.");
    }
    hlt_loop();
}
