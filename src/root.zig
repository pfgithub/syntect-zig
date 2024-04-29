const std = @import("std");

pub extern fn add(a: i32, b: i32) i32;

pub const SyntaxSetBuilder = opaque {
    pub const create = syntaxsetbuilder_create;
    pub const deallocate = syntaxsetbuilder_deallocate;
    pub fn add(ssb: *SyntaxSetBuilder, tmlanguage: []const u8) !void {
        if (!syntaxsetbuilder_add(ssb, tmlanguage.ptr, tmlanguage.len)) return error.TmlParseFailed;
    }
    pub const buildAndDeinit = syntaxsetbuilder_build_and_deinit;
};

pub const SyntaxSet = opaque {
    pub const allocate = syntaxset_allocate;
    pub const initDefaults = syntaxset_init_defaults;
    pub const deinit = syntaxset_deinit;
    pub const deallocate = syntaxset_deallocate;
};

pub const ParseIter = opaque {
    pub fn create(syntax_set: *SyntaxSet, lang: []const u8) !*ParseIter {
        return syntect_create(syntax_set, lang.ptr, lang.len) orelse return error.InvalidLanguage;
    }
    pub const destroy = syntect_destroy;

    pub fn addLine(parse_iter: *ParseIter, line: []const u8) !void {
        if (!syntect_add_line(parse_iter, line.ptr, line.len)) return error.InvalidUtf8;
    }
    pub const wantsNextLine = syntect_wants_next_line;
    pub const next = syntect_next;
};
pub const ParseChar = opaque {
    pub const allocate = parsechar_allocate;
    pub const deinit = parsechar_deinit;
    pub const deallocate = parsechar_deallocate;
    pub const print = parsechar_print;
    pub const getChar = parsechar_get_char;
    pub fn getScopes(char: *ParseChar, buf: []u8) usize {
        return parsechar_get_scopes(char, buf.ptr, buf.len);
    }
};

extern fn syntaxsetbuilder_create() *SyntaxSetBuilder;
extern fn syntaxsetbuilder_deallocate(ssb: *SyntaxSetBuilder) void;
extern fn syntaxsetbuilder_add(builder: *SyntaxSetBuilder, tmlanguage_ptr: [*]const u8, tmlanguage_len: usize) bool;
extern fn syntaxsetbuilder_build_and_deinit(builder: *SyntaxSetBuilder, output_set: *SyntaxSet) void;

extern fn syntaxset_allocate() *SyntaxSet;
extern fn syntaxset_init_defaults(syntax_set: *SyntaxSet) void;
extern fn syntaxset_deinit(syntax_set: *SyntaxSet) void;
extern fn syntaxset_deallocate(syntax_set: *SyntaxSet) void;

extern fn syntect_create(syntax_set: *SyntaxSet, lang_ptr: [*]const u8, lang_len: usize) ?*ParseIter;
extern fn syntect_destroy(value_ptr: *ParseIter) void;

extern fn syntect_add_line(syntect: *ParseIter, line_ptr: [*]const u8, line_len: usize) bool;
extern fn syntect_wants_next_line(syntect: *ParseIter) bool;
extern fn syntect_next(syntect: *ParseIter, out_char: *ParseChar) bool;

extern fn parsechar_allocate() *ParseChar;
extern fn parsechar_deinit(char: *ParseChar) void;
extern fn parsechar_deallocate(char: *ParseChar) void;
extern fn parsechar_print(char: *ParseChar) void;
extern fn parsechar_get_char(char: *ParseChar) u8;
extern fn parsechar_get_scopes(char: *ParseChar, buf_ptr: [*]u8, buf_len: usize) usize;
