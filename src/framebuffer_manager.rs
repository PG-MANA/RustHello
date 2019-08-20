use core::fmt;

pub struct FramebufferManager {
    address: usize,
    height: u32,
    width: u32,
    pointer: usize,
}

#[repr(C)]
#[allow(dead_code)]
pub struct MultibootFrameBufferInfo {
    s_type: u32,
    size: u32,
    framebuffer_addr: u64,
    framebuffer_pitch: u32,
    framebuffer_width: u32,
    framebuffer_height: u32,
    framebuffer_bpp: u8,
    framebuffer_type: u8, //https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html 3.6.12 Framebuffer info 参照
    reserved: u8,
    /*color_infoは無視してる*/
}

impl FramebufferManager {
    pub const fn static_new() -> FramebufferManager {
        FramebufferManager {
            address: 0,
            height: 0,
            width: 0,
            pointer: 0,
        }
    }

    pub fn new(info: &MultibootFrameBufferInfo) -> FramebufferManager {
        if info.framebuffer_type != 2 {
            Self::static_new()
        } else {
            FramebufferManager {
                address: info.framebuffer_addr as usize,
                height: info.framebuffer_height,
                width: info.framebuffer_width,
                pointer: 0,
            }
        }
    }

    pub fn puts(&mut self, string: &str) -> bool {
        if self.address == 0 {
            return false;
        }
        for c in string.bytes() {
            if self.pointer >= (self.width * self.height) as usize {
                return false;
            }
            if c == b'\n' {
                self.pointer += self.width as usize - self.pointer % self.width as usize;//あんまり剰余は使いたくないけど...
                continue;
            }
            unsafe {
                *((self.address + self.pointer * 2) as *mut u16) = ((0x00 & 0x07) << 0x0C) as u16/*背景色*/
                    | ((0x0b & 0x0F) << 0x08) as u16/*文字色*/ | c as u16; //http://oswiki.osask.jp/?VGA%2Ftext を参照
            }
            self.pointer += 1;
        }
        true
    }
}

impl fmt::Write for FramebufferManager {
    fn write_str(&mut self, string: &str) -> fmt::Result {
        if self.puts(string) {
            return Ok(());
        } else {
            return Err(fmt::Error {});
        }
    }
}
