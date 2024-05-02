use std::{alloc::Layout, cmp::min};
use std::mem;

use syntect::parsing::{ParseState, Scope, ScopeStack, ScopeStackOp, SyntaxDefinition, SyntaxSet, SyntaxSetBuilder};

// consider cbindgen:
// https://github.com/mozilla/cbindgen

#[derive(Clone, Copy)]
pub struct ParseChar {
    char: u8,
    scope: Option<Scope>,
}

pub struct ParseIter {
    ps: *mut SyntaxSet,
    parse_state: ParseState,
    wants_next_line: bool,
    state: ScopeStack,

    current_line_str: Option<String>,
    current_line_idx: usize,
    next_line_option_idx: usize,
    current_line: Option<Vec<(usize, ScopeStackOp)>>,
}
impl ParseIter {
    pub fn init(ps: *mut SyntaxSet, parse_state: ParseState) -> Option<ParseIter> {
        Some(ParseIter {
            ps,
            parse_state,
            wants_next_line: true,
            state: ScopeStack::new(),

            current_line_str: None,
            current_line_idx: 0,
            next_line_option_idx: 0,
            current_line: None,
        })
    }

    pub fn add_line(&mut self, line: &str) -> bool {
        if !self.wants_next_line {panic!("not wants next line")}
        self.wants_next_line = false;
        self.current_line_str = Some(line.into());
        self.current_line = Some(match self.parse_state.parse_line(line, unsafe{&*self.ps}) {
            Ok(v) => v,
            Err(_) => return false,
        });
        self.current_line_idx = 0;
        self.next_line_option_idx = 0;
        return true;
    }

    pub fn next(&mut self) -> Option<ParseChar> {
        if self.wants_next_line {panic!("wants next line")}
        
        // positions in the line are relative to the line
        let line_str: &str = self.current_line_str.as_ref().unwrap();
        let line = self.current_line.as_ref().unwrap();

        let res_chars = line_str.as_bytes();
        if self.current_line_idx >= res_chars.len() {
            // oops! should have posted a line
            panic!("should have posted a line");
        };
        
        let res_byte = res_chars[self.current_line_idx];
        
        while self.next_line_option_idx < line.len() && self.current_line_idx >= line[self.next_line_option_idx].0 {
            // can't make this a function because not allowed to have &mut self and a & reference to a thing in self
            // even though that's completely fine and ok? rust just doesn't allow it.
            // state would need to be extracted out into a seperate struct and then
            // applyOp could probably be called on that, maybe.
            let op = &line[self.next_line_option_idx].1;
            _ = self.state.apply(op);
            self.next_line_option_idx += 1;
        }
        self.current_line_idx += 1;
        
        if res_byte == b'\n' {
            self.wants_next_line = true;
        };

        Some(ParseChar {
            char: res_byte,
            scope: self.state.scopes.last().copied(),
        })
    }
}

macro_rules! zsb_baseset {
    ($name:tt, $Type:tt) => {
        #[export_name = concat!("zsb_", $name, "_allocate")]
        extern "C" fn allocate() -> *mut $Type {
            let layout = Layout::from_size_align(
                mem::size_of::<$Type>(),
                mem::align_of::<$Type>(),
            ).expect("Bad layout");
            unsafe { std::alloc::alloc(layout) as *mut $Type }
        }
        #[export_name = concat!("zsb_", $name, "_deallocate")]
        extern "C" fn deallocate(item: *mut $Type) -> () {
            let layout = Layout::from_size_align(
                mem::size_of::<$Type>(),
                mem::align_of::<$Type>(),
            ).expect("Bad layout");
            unsafe { std::alloc::dealloc(item as *mut u8, layout); }
        }
        #[export_name = concat!("zsb_", $name, "_deinit")]
        extern "C" fn deinit(item: *mut $Type) -> () {
            unsafe { std::ptr::drop_in_place(item); }
        }
    };
}

// if we export the layouts, we could have zig do the allocation if we were so inclined
// or even stack allocate stuff with a bindings generator

mod ffi_syntaxsetbuilder {
    use crate::*;
    zsb_baseset!("SyntaxSetBuilder", SyntaxSetBuilder);

    #[export_name = "zsb_SyntaxSetBuilder_init"]
    pub extern "C" fn init(ssb: *mut SyntaxSetBuilder) -> () {
        unsafe{
            ssb.write(SyntaxSetBuilder::new());
        }
    }
    #[export_name = "zsb_SyntaxSetBuilder_add"]
    pub extern "C" fn add(ssb: &mut SyntaxSetBuilder, definition_ptr: *const u8, definition_len: usize) -> bool {
        let lang = unsafe {
            std::slice::from_raw_parts(definition_ptr, definition_len)
        };
    
        // Convert the byte slice to a string slice
        let lang_str = match std::str::from_utf8(lang) {
            Ok(str) => str,
            Err(emsg) => {
                println!("Error utf-8: {}", emsg);
                return false;
            }
        };
    
        let syntax_definition = match SyntaxDefinition::load_from_str(lang_str, true, None) {
            Ok(v) => v,
            Err(emsg) => {
                println!("Error parsing syntax file: {}", emsg);
                return false;
            }
        };
    
        ssb.add(syntax_definition);
    
        true
    }
    #[export_name = "zsb_SyntaxSetBuilder_buildAndDeinit"]
    pub extern "C" fn build_and_deinit(ssb: *mut SyntaxSetBuilder, syntax_set: *mut SyntaxSet) -> () {
        unsafe {
            syntax_set.write(ssb.read().build());
        }
    }
}

mod ffi_syntaxset {
    use crate::*;

    zsb_baseset!("SyntaxSet", SyntaxSet);

    #[export_name="zsb_SyntaxSet_initDefaults"]
    pub extern "C" fn syntaxset_init_defaults(syntax_set: *mut SyntaxSet) -> () {
        unsafe {
            syntax_set.write(SyntaxSet::load_defaults_newlines());
        }
    }
}

mod ffi_parse_state {
    use crate::*;
zsb_baseset!("ParseState", ParseState);
#[export_name="zsb_ParseState_init"]
extern "C" fn init(ps: *mut ParseState, ss: &mut SyntaxSet, lang_ptr: *const u8, lang_len: usize) -> bool {
    let lang = unsafe {
        std::slice::from_raw_parts(lang_ptr, lang_len)
    };
    let lang_str = match std::str::from_utf8(lang) {
        Ok(str) => str,
        Err(_) => return false,
    };

    let syntax = match ss.find_syntax_by_extension(lang_str) {
        Some(v) => v,
        None => return false,
    };
    unsafe {
        ps.write(ParseState::new(syntax))
    }
    return true;
}
}

mod ffi_parse_iter {
    use crate::*;
    zsb_baseset!("ParseIter", ParseIter);
#[export_name="zsb_ParseIter_init"]
extern "C" fn init(res: *mut ParseIter, ss: *mut SyntaxSet, ps: &mut ParseState) -> bool {
    unsafe {
        res.write(match ParseIter::init(ss, ps.clone()) {
            Some(v) => v,
            None => return false,
        })
    }
    return true;
}

#[export_name="zsb_ParseIter_addLine"]
pub extern "C" fn add_line(syntect: &mut ParseIter, line_ptr: *const u8, line_len: usize) -> bool {
    let line = unsafe {
        std::slice::from_raw_parts(line_ptr, line_len)
    };
    let line_str = match std::str::from_utf8(line) {
        Ok(str) => str,
        Err(_) => return false,
    };

    return syntect.add_line(line_str);
}

#[export_name="zsb_ParseIter_wantsNextLine"]
pub extern "C" fn syntect_wants_next_line(syntect: &mut ParseIter) -> bool {
    syntect.wants_next_line
}

#[export_name="zsb_ParseIter_next"]
pub extern "C" fn syntect_next(syntect: &mut ParseIter, out_char: *mut ParseChar) -> bool {
    match syntect.next() {
        Some(value) => {
            unsafe {
                out_char.write(value);
            }
            true
        },
        None => {
            false
        },
    }
}
}

mod ffi_parse_char {
    use crate::*;
    zsb_baseset!("ParseChar", ParseChar);

#[export_name="zsb_ParseChar_print"]
pub extern "C" fn parsechar_print(value: &mut ParseChar) -> () {
    println!("value: '{:#?}' {:#?}", value.char as char, value.scope);
}
#[export_name="zsb_ParseChar_getChar"]
pub extern "C" fn parsechar_get_char(value: &mut ParseChar) -> u8 {
    value.char
}
#[export_name="zsb_ParseChar_getScopes"]
pub extern "C" fn parsechar_get_scopes(value: &mut ParseChar, buf_ptr: *mut u8, buf_len: usize) -> usize {
    let buf = unsafe {
        std::slice::from_raw_parts_mut(buf_ptr, buf_len)
    };

    match value.scope {
        Some(v) => {
            let string = v.build_string();
            let str_bytes = string.as_bytes();
            let min_len = min(string.len(), buf.len());
            buf[0..min_len].copy_from_slice(&str_bytes[0..min_len]);
            string.len()
        },
        None => {
            0
        },
    }
}
}
