const std = @import("std");

pub extern fn add(a: i32, b: i32) i32;

pub const ParseIter = opaque {
    pub fn create(lang: []const u8) !*ParseIter {
        return syntect_create(lang.ptr, lang.len) orelse return error.InvalidLanguage;
    }
    pub const destroy = syntect_destroy;

    pub fn addLine(parse_iter: *ParseIter, line: []const u8) !void {
        if (!syntect_add_line(parse_iter, line.ptr, line.len)) return error.InvalidUtf8;
    }
    pub const wantsNextLine = syntect_wants_next_line;
    pub const next = syntect_next;
};
pub const ParseChar = opaque {
    pub const create = parsechar_create;
    pub const deinit = parsechar_deinit;
    pub const destroy = parsechar_destroy;
    pub const print = parsechar_print;
    pub const getChar = parsechar_get_char;
    pub fn getScopes(char: *ParseChar, buf: []u8) usize {
        return parsechar_get_scopes(char, buf.ptr, buf.len);
    }
};

extern fn syntect_create(lang_ptr: [*]const u8, lang_len: usize) ?*ParseIter;
extern fn syntect_destroy(value_ptr: *ParseIter) void;

extern fn syntect_add_line(syntect: *ParseIter, line_ptr: [*]const u8, line_len: usize) bool;
extern fn syntect_wants_next_line(syntect: *ParseIter) bool;
extern fn syntect_next(syntect: *ParseIter, out_char: *ParseChar) bool;

extern fn parsechar_create() *ParseChar;
extern fn parsechar_deinit(char: *ParseChar) void;
extern fn parsechar_destroy(char: *ParseChar) void;
extern fn parsechar_print(char: *ParseChar) void;
extern fn parsechar_get_char(char: *ParseChar) u8;
extern fn parsechar_get_scopes(char: *ParseChar, buf_ptr: [*]u8, buf_len: usize) usize;
