use std::{alloc::Layout, cmp::min};
use std::mem;

use syntect::parsing::{ParseState, Scope, ScopeStack, ScopeStackOp, SyntaxSet};

#[derive(Clone, Copy)]
pub struct ParseChar {
    char: u8,
    scope: Option<Scope>,
}

pub struct ParseIter {
    ps: SyntaxSet,
    parse_state: ParseState,
    wants_next_line: bool,
    state: ScopeStack,

    current_line_str: Option<String>,
    current_line_idx: usize,
    next_line_option_idx: usize,
    current_line: Option<Vec<(usize, ScopeStackOp)>>,
}
impl ParseIter {
    pub fn init(language: &str) -> Option<ParseIter> {
        let ps = SyntaxSet::load_defaults_newlines();
        let syntax = match ps.find_syntax_by_extension(language) {
            Some(v) => v,
            None => return None,
        };

        let parse_state = ParseState::new(syntax);

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

    pub fn add_line(&mut self, line: &str) -> () {
        if !self.wants_next_line {panic!("not wants next line")}
        self.wants_next_line = false;
        self.current_line_str = Some(line.into());
        self.current_line = Some(self.parse_state.parse_line(line, &self.ps).unwrap());
        self.current_line_idx = 0;
        self.next_line_option_idx = 0;
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

        while self.next_line_option_idx < line.len() && line[self.next_line_option_idx].0 < self.current_line_idx {
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

#[no_mangle]
pub extern "C" fn syntect_create(lang_ptr: *const u8, lang_len: usize) -> *mut ParseIter {
    let lang = unsafe {
        std::slice::from_raw_parts(lang_ptr, lang_len)
    };

    // Convert the byte slice to a string slice
    let lang_str = match std::str::from_utf8(lang) {
        Ok(str) => str,
        Err(_) => return core::ptr::null::<ParseIter>() as *mut ParseIter,
    };

    // Allocate memory for ParseIter
    let layout = Layout::from_size_align(
        mem::size_of::<ParseIter>(),
        mem::align_of::<ParseIter>(),
    ).expect("Bad layout");

    let res = unsafe { std::alloc::alloc(layout) as *mut ParseIter };
    
    unsafe {
        res.write(match ParseIter::init(lang_str) {
            Some(v) => v,
            None => return core::ptr::null::<ParseIter>() as *mut ParseIter,
        });
    }
    res
}

#[no_mangle]
pub extern "C" fn syntect_destroy(value_ptr: *mut ParseIter) -> () {
    unsafe {
        std::ptr::drop_in_place(value_ptr); // Explicitly call destructor
        let layout = Layout::from_size_align(
            mem::size_of::<ParseIter>(),
            mem::align_of::<ParseIter>(),
        ).expect("Bad layout");
        std::alloc::dealloc(value_ptr as *mut u8, layout); // Free the memory
    }
}

/// false indicates utf-8 error
#[no_mangle]
pub extern "C" fn syntect_add_line(syntect: *mut ParseIter, line_ptr: *const u8, line_len: usize) -> bool {
    let line = unsafe {
        std::slice::from_raw_parts(line_ptr, line_len)
    };

    // Convert the byte slice to a string slice
    let line_str = match std::str::from_utf8(line) {
        Ok(str) => str,
        Err(_) => return false,
    };

    unsafe {
        (*syntect).add_line(line_str);
    }
    return true;
}

#[no_mangle]
pub extern "C" fn syntect_wants_next_line(syntect: *mut ParseIter) -> bool {
    unsafe {
        (*syntect).wants_next_line
    }
}

#[no_mangle]
pub extern "C" fn syntect_next(syntect: *mut ParseIter, out_char: *mut ParseChar) -> bool {
    let result = unsafe {
        (*syntect).next()
    };
    match result {
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

#[no_mangle]
pub extern "C" fn parsechar_create() -> *mut ParseChar {
    let layout = Layout::from_size_align(
        mem::size_of::<ParseChar>(),
        mem::align_of::<ParseChar>(),
    ).expect("Bad layout");

    let res = unsafe { std::alloc::alloc(layout) as *mut ParseChar };
    
    res
}
#[no_mangle]
pub extern "C" fn parsechar_deinit(value_ptr: *mut ParseChar) {
    unsafe {
        std::ptr::drop_in_place(value_ptr);
    }
}
#[no_mangle]
pub extern "C" fn parsechar_destroy(value_ptr: *mut ParseChar) {
    unsafe {
        let layout = Layout::from_size_align(
            mem::size_of::<ParseChar>(),
            mem::align_of::<ParseChar>(),
        ).expect("Bad layout");
        std::alloc::dealloc(value_ptr as *mut u8, layout);
    }
}
#[no_mangle]
pub extern "C" fn parsechar_print(value_ptr: *mut ParseChar) -> () {
    let value = unsafe { *value_ptr };

    println!("value: '{:#?}' {:#?}", value.char as char, value.scope);
}
#[no_mangle]
pub extern "C" fn parsechar_get_char(value_ptr: *mut ParseChar) -> u8 {
    let value = unsafe { *value_ptr };

    value.char
}
#[no_mangle]
pub extern "C" fn parsechar_get_scopes(value_ptr: *mut ParseChar, buf_ptr: *mut u8, buf_len: usize) -> usize {
    let buf = unsafe {
        std::slice::from_raw_parts_mut(buf_ptr, buf_len)
    };

    let value = unsafe { *value_ptr };

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

#[no_mangle]
pub extern "C" fn add(n1: i32, n2: i32) -> i32 {
    return n1 + n2;
}
