const std = @import("std");
const lib = @import("lib.zig");

const mem = std.mem;
const testing = std.testing;
const expect = testing.expect;
const allocator = std.heap.page_allocator;
const test_allocator = std.testing.allocator;

pub const eof = "-1";
pub const default_segment_sep = '~';
pub const default_segment_sep_as_str: []const u8 = "~";

pub const default_element_sep: u8 = '*';
const default_element_sep_as_str: []const u8 = "*";

pub const TokenType = enum {
    err, // error occured; value is the text of error
    eof,
    identifier, // elemenet identifier
    val, // a value
    seg_separator, // segment seperator
    ele_separator, // element seperator
    new_line, // new line

    fn asstr(self: TokenType) []const u8 {
        if (self == TokenType.err) {
            return "err";
        } else if (self == TokenType.eof) {
            return "eof";
        } else if (self == TokenType.identifier) {
            return "identifier";
        } else if (self == TokenType.val) {
            return "val";
        } else if (self == TokenType.seg_separator) {
            return "segment seperator";
        } else if (self == TokenType.ele_separator) {
            return "element seperator";
        } else if (self == TokenType.new_line) {
            return "new line";
        } else {
            return "uknown";
        }
    }
};

// token represents a token of a text string returned from the scanner
pub const Token = struct {
    typ: TokenType, // the type of this token.
    pos: usize, // the starting position, in bytes, of this item in the input string.
    val: []const u8, // the value of this item.
    line: usize, // the line number at the start of this item.

    pub fn init(typ: TokenType, pos: usize, val: []const u8, line: usize) Token {
        return Token{ .typ = typ, .pos = pos, .val = val, .line = line };
    }

    pub fn print(self: Token) void {
        if (std.mem.eql(u8, self.val, "\n")) {
            std.debug.print("val = \\n,", .{});
        } else {
            std.debug.print("val = {s}, ", .{self.val});
        }
        std.debug.print("type = {s}, ", .{self.typ.asstr()});
        std.debug.print("line = {d}\n", .{self.line});
    }
};

// configuration for the lexer
pub const LexerOptions = struct {
    ele_separator: u8,
    seg_separator: u8,

    pub fn init(ele_separator: u8, seg_separator: u8) LexerOptions {
        return LexerOptions{ .seg_separator = seg_separator, .ele_separator = ele_separator };
    }
};

pub const Lexer = struct {
    input: []const u8,
    start: usize, // start position of the item
    pos: usize, // current position of the input
    at_eof: bool, // we have hit the end of input and returned eof
    options: LexerOptions, // configuration for lexer
    buffer: std.ArrayList(Token), // buffer to hold tokens

    pub fn init(input: []const u8, options: LexerOptions) Lexer {
        const start_at = 0;
        const start_position = 0;
        var buf = std.ArrayList(Token).init(std.heap.page_allocator);
        return Lexer{ .input = input, .start = start_at, .pos = start_position, .at_eof = false, .options = options, .buffer = buf };
    }

    pub fn deinit(self: Lexer) void {
        defer self.buffer.deinit();
    }

    pub fn plexstr(self: Lexer) void {
        std.debug.print("EDI: {s}\n", .{self.input});
    }

    pub fn pbuffer(self: Lexer) void {
        for (self.buffer.items) |item| {
            item.print();
        }
    }

    pub fn size(self: Lexer) usize {
        return self.buffer.items.len;
    }

    // provide access to the token buffer
    pub fn tbuffer(self: Lexer) std.ArrayList(Token) {
        return self.buffer;
    }

    fn peek(self: Lexer) u8 {
        if (self.pos + 1 < self.input.len) {
            return self.input[self.pos + 1];
        }
        return 0;
    }

    fn value(self: Lexer) []const u8 {
        var str: []const u8 = "";
        for (self.buffer.items) |item| {
            if (item.typ == TokenType.eof) {
                continue;
            }
            str = std.fmt.allocPrint(allocator, "{s}{s}", .{ str, item.val }) catch "format failed";
        }
        return str;
    }

    fn lines(self: Lexer) u8 {
        var n: u8 = 0;
        for (self.buffer.items) |item| {
            if (item.typ == TokenType.new_line) {
                n += 1;
            }
        }
        return n;
    }

    // return the next token, loop ends when the token is TokenType.eof
    fn next(self: *Lexer) Token {
        var line: u8 = 0;

        const ele_separator = std.fmt.allocPrint(std.heap.page_allocator, "{c}", .{self.options.ele_separator}) catch default_element_sep_as_str;

        const seg_separator = std.fmt.allocPrint(std.heap.page_allocator, "{c}", .{self.options.seg_separator}) catch default_segment_sep_as_str;

        while (true) : (self.pos += 1) {
            if (self.pos == self.input.len) {
                self.at_eof = true;
                return Token.init(TokenType.eof, self.pos, eof, line);
            }
            const char = self.input[self.pos];
            if (char == '\n') {
                line += 1;
                self.pos += 1;
                self.start = self.pos;
                return Token.init(TokenType.new_line, self.pos, "\n", line);
            } else if (char == self.options.seg_separator) {
                self.pos += 1;
                self.start = self.pos;
                return Token.init(TokenType.seg_separator, self.pos, seg_separator, line);
            } else if (char == self.options.ele_separator) {
                self.pos += 1;
                self.start = self.pos;
                return Token.init(TokenType.ele_separator, self.pos, ele_separator, line);
            } else if (self.pos + 1 < self.input.len) {
                const next_char: u8 = self.peek();
                if (next_char == self.options.ele_separator or next_char == self.options.seg_separator) {
                    const tv: []const u8 = self.input[self.start .. self.pos + 1];
                    self.pos += 1;
                    self.start = self.pos;
                    return Token.init(TokenType.identifier, self.pos, tv, line);
                } else {
                    continue;
                }
            } else {
                const tv: []const u8 = self.input[self.start .. self.pos + 1];
                self.pos += 1;
                self.start = self.pos;
                return Token.init(TokenType.identifier, self.pos, tv, line);
            }
        }
    }

    pub fn tokens(self: *Lexer) void {
        while (true) {
            const token: Token = self.next();
            self.buffer.append(token) catch @panic("out of memory occured");
            if (token.typ == TokenType.eof) {
                break;
            }
        }
    }
};

test "lexer.segment" {
    const s = "DXS*9251230013*DX*004010UCS*1*9254850000";
    const options = LexerOptions.init('*', '~');
    var lexer = Lexer.init(s, options);
    lexer.tokens();

    try expect(11 == lexer.size() - 1);
    try expect(std.mem.eql(u8, s, lexer.value()) == true);
}

test "lexer.segments" {
    const result = struct {
        len: u8,
    };

    const input = struct {
        s: []const u8,
        default_sep: bool,
    };

    const tst = struct {
        input: input,
        expected: result,
    };

    const tests = [_]tst{
        tst{ .input = input{ .s = "X*004060*\n", .default_sep = true }, .expected = result{ .len = 5 } },
        tst{ .input = input{ .s = "ST*\n", .default_sep = true }, .expected = result{ .len = 3 } },
        tst{ .input = input{ .s = "ST*\nST", .default_sep = true }, .expected = result{ .len = 4 } },
        tst{ .input = input{ .s = "AS*ST", .default_sep = true }, .expected = result{ .len = 3 } },
        tst{ .input = input{ .s = "ST*", .default_sep = true }, .expected = result{ .len = 2 } },
        tst{ .input = input{ .s = "ST*AAA*0001", .default_sep = true }, .expected = result{ .len = 5 } },
        tst{ .input = input{ .s = "TST", .default_sep = true }, .expected = result{ .len = 1 } },
        tst{ .input = input{ .s = "TST~", .default_sep = true }, .expected = result{ .len = 2 } },
        tst{ .input = input{ .s = "TST*123", .default_sep = true }, .expected = result{ .len = 3 } },
        tst{ .input = input{ .s = "TST*123~", .default_sep = true }, .expected = result{ .len = 4 } },
        tst{ .input = input{ .s = "DXS*9251230013*DX*004010UCS*1*9254850000", .default_sep = true }, .expected = result{ .len = 11 } },
        tst{ .input = input{ .s = "DXS_9251230013_DX_004010UCS_1_9254850000", .default_sep = false }, .expected = result{ .len = 11 } },
    };

    for (tests) |t| {
        var ele_sep: u8 = '_';

        if (t.input.default_sep) {
            ele_sep = default_element_sep;
        }
        var options = LexerOptions.init(default_segment_sep, ele_sep);
        var lexer = Lexer.init(t.input.s, options);
        lexer.tokens();

        try expect(t.expected.len == lexer.size() - 1);
        try expect(std.mem.eql(u8, t.input.s, lexer.value()) == true);
    }
}

test "lexer.large.segments" {
    const input = struct {
        file: []const u8,
        default_sep: bool,
    };

    const result = struct {
        lines: u8,
    };

    const tst = struct {
        input: input,
        expected: result,
    };

    const tests = [_]tst{
        tst{ .input = input{ .file = "../assets/x12.base.no.line.breaks.txt", .default_sep = true }, .expected = result{ .lines = 0 } },
        tst{ .input = input{ .file = "../assets/x12.base.loop-1.txt", .default_sep = true }, .expected = result{ .lines = 1 } },
        tst{ .input = input{ .file = "../assets/x12.base.loop.txt", .default_sep = true }, .expected = result{ .lines = 24 } },
        tst{ .input = input{ .file = "../assets/x12.base.no.line.breaks.empty.line.txt", .default_sep = true }, .expected = result{ .lines = 0 } },
        tst{ .input = input{ .file = "../assets/x12.base.no.line.breaks.odd.char.txt", .default_sep = true }, .expected = result{ .lines = 0 } },
        tst{ .input = input{ .file = "../assets/x12.base.one.txt", .default_sep = true }, .expected = result{ .lines = 6 } },
        tst{ .input = input{ .file = "../assets/x12.missing.ISA.txt", .default_sep = true }, .expected = result{ .lines = 13 } },
        tst{ .input = input{ .file = "../assets/x12.no.line.break.no.delim.txt", .default_sep = true }, .expected = result{ .lines = 0 } },
        tst{ .input = input{ .file = "../assets/x12.wrong.GS.txt", .default_sep = true }, .expected = result{ .lines = 14 } },
        tst{ .input = input{ .file = "../assets/x12.wrong.ISA.txt", .default_sep = true }, .expected = result{ .lines = 14 } },
    };

    for (tests) |t| {
        var ele_sep: u8 = '_';
        if (t.input.default_sep) {
            ele_sep = default_element_sep;
        }
        const content = try lib.readfile(t.input.file, test_allocator);
        defer test_allocator.free(content);
        var options = LexerOptions.init(default_segment_sep, ele_sep);
        var lexer = Lexer.init(content, options);
        lexer.tokens();

        try expect(t.expected.lines == lexer.lines());
    }
}
