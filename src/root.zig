const std = @import("std");

pub const SyntaxSetBuilder = opaque {
    pub const allocate = zsb_SyntaxSetBuilder_allocate;
    pub const deinit = zsb_SyntaxSetBuilder_deinit;
    pub const deallocate = zsb_SyntaxSetBuilder_deallocate;

    pub const init = zsb_SyntaxSetBuilder_init;
    pub fn add(ssb: *SyntaxSetBuilder, tmlanguage: []const u8) !void {
        if (!zsb_SyntaxSetBuilder_add(ssb, tmlanguage.ptr, tmlanguage.len)) return error.TmlParseFailed;
    }
    pub const buildAndDeinit = zsb_SyntaxSetBuilder_buildAndDeinit;
};

pub const SyntaxSet = opaque {
    pub const allocate = zsb_SyntaxSet_allocate;
    pub const deinit = zsb_SyntaxSet_deinit;
    pub const deallocate = zsb_SyntaxSet_deallocate;

    pub const initDefaults = zsb_SyntaxSet_initDefaults;
};

pub const ParseState = opaque {
    pub const allocate = zsb_ParseState_allocate;
    pub const deinit = zsb_ParseState_deinit;
    pub const deallocate = zsb_ParseState_deallocate;

    pub fn init(ps: *ParseState, ss: *SyntaxSet, lang: []const u8) !void {
        if(!zsb_ParseState_init(ps, ss, lang.ptr, lang.len)) return error.InvalidLanguage;
    }
};

pub const ParseIter = opaque {
    pub const allocate = zsb_ParseIter_allocate;
    pub const deinit = zsb_ParseIter_deinit;
    pub const deallocate = zsb_ParseIter_deallocate;

    pub fn init(self: *ParseIter, ss: *SyntaxSet, ps: *ParseState) !void {
        if(!zsb_ParseIter_init(self, ss, ps)) return error.ParseIterInitFail;
    }

    pub fn addLine(parse_iter: *ParseIter, line: []const u8) !void {
        if (!zsb_ParseIter_addLine(parse_iter, line.ptr, line.len)) return error.InvalidUtf8;
    }
    pub const wantsNextLine = zsb_ParseIter_wantsNextLine;
    pub fn next(syntect: *ParseIter, out_char: *ParseChar) !void {
        if(!zsb_ParseIter_next(syntect, out_char)) return error.NextFail;
    }
};
pub const ParseChar = opaque {
    pub const allocate = zsb_ParseChar_allocate;
    pub const deinit = zsb_ParseChar_deinit;
    pub const deallocate = zsb_ParseChar_deallocate;

    pub const print = zsb_ParseChar_print;
    pub const getChar = zsb_ParseChar_getChar;
    pub fn getScopes(char: *ParseChar, buf: []u8) usize {
        return zsb_ParseChar_getScopes(char, buf.ptr, buf.len);
    }
};

extern fn zsb_SyntaxSetBuilder_allocate() *SyntaxSetBuilder;
extern fn zsb_SyntaxSetBuilder_deinit(ssb: *SyntaxSetBuilder) void;
extern fn zsb_SyntaxSetBuilder_deallocate(ssb: *SyntaxSetBuilder) void;
extern fn zsb_SyntaxSetBuilder_init(ssb: *SyntaxSetBuilder) void;
extern fn zsb_SyntaxSetBuilder_add(ssb: *SyntaxSetBuilder, tmlanguage_ptr: [*]const u8, tmlanguage_len: usize) bool;
extern fn zsb_SyntaxSetBuilder_buildAndDeinit(ssb: *SyntaxSetBuilder, output_set: *SyntaxSet) void;

extern fn zsb_SyntaxSet_allocate() *SyntaxSet;
extern fn zsb_SyntaxSet_deinit(syntax_set: *SyntaxSet) void;
extern fn zsb_SyntaxSet_deallocate(syntax_set: *SyntaxSet) void;
extern fn zsb_SyntaxSet_initDefaults(syntax_set: *SyntaxSet) void;

extern fn zsb_ParseState_allocate() *ParseState;
extern fn zsb_ParseState_deinit(item: *ParseState) void;
extern fn zsb_ParseState_deallocate(item: *ParseState) void;
extern fn zsb_ParseState_init(item: *ParseState, ss: *SyntaxSet, lang_ptr: [*]const u8, lang_len: usize) bool;

extern fn zsb_ParseIter_allocate() *ParseIter;
extern fn zsb_ParseIter_deinit(item: *ParseIter) void;
extern fn zsb_ParseIter_deallocate(item: *ParseIter) void;
extern fn zsb_ParseIter_init(syntect: *ParseIter, ss: *SyntaxSet, ps: *ParseState) bool;
extern fn zsb_ParseIter_addLine(syntect: *ParseIter, line_ptr: [*]const u8, line_len: usize) bool;
extern fn zsb_ParseIter_wantsNextLine(syntect: *ParseIter) bool;
extern fn zsb_ParseIter_next(syntect: *ParseIter, out_char: *ParseChar) bool;

extern fn zsb_ParseChar_allocate() *ParseChar;
extern fn zsb_ParseChar_deinit(char: *ParseChar) void;
extern fn zsb_ParseChar_deallocate(char: *ParseChar) void;
extern fn zsb_ParseChar_print(char: *ParseChar) void;
extern fn zsb_ParseChar_getChar(char: *ParseChar) u8;
extern fn zsb_ParseChar_getScopes(char: *ParseChar, buf_ptr: [*]u8, buf_len: usize) usize;
