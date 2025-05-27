const std = @import("std");
const lex = @import("lexer.zig");
const seg = @import("segment.zig");
const lib = @import("lib.zig");
const parser = @import("parser.zig");
const x12 = @import("x12.zig");

const allocator = std.heap.page_allocator;

const SegmentType = seg.SegmentType;

const LexerOptions = lex.LexerOptions;
const Lexer = lex.Lexer;
const Token = lex.Token;

const X12Document = x12.X12Document;

pub fn main() !void {
    const ele_separator: u8 = '*';
    const seg_separator: u8 = '~';

    const s = "ISA*01*0000000000*01*0000000000*ZZ*ABCDEFGHIJKLMNO~ZZ*123456789012345*101127*1719*U*00400*000000049*0*P*>~IEA*2*000000049";

    const Parser = parser.Parser;
    const p = Parser.init(s, ele_separator, seg_separator);
    _ = p.parse();
}
