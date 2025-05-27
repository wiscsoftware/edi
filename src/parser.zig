const std = @import("std");

const lex = @import("lexer.zig");
const seg = @import("segment.zig");
const lib = @import("lib.zig");
const x12 = @import("x12.zig");

const Token = lex.Token;
const TokenType = lex.TokenType;
const LexerOptions = lex.LexerOptions;
const Lexer = lex.Lexer;

const Spec = seg.Spec;
const Element = seg.Element;
const Segment = seg.Segment;
const SegmentType = seg.SegmentType;
const InterchangeControlTrailer = seg.InterchangeControlTrailer;
const InterchangeControlHeader = seg.InterchangeControlHeader;

const TransactionSet = x12.TransactionSet;
const FunctionalGroup = x12.FunctionalGroup;
const X12Document = x12.X12Document;
const testing = std.testing;
const expect = testing.expect;
const allocator = std.heap.page_allocator;

// parse and produce an x12 document from an EDI stream
pub const Parser = struct {
    s: []const u8,
    ele_separator: u8,
    seg_separator: u8,

    pub fn init(s: []const u8, ele_separator: u8, seg_separator: u8) Parser {
        return Parser{ .s = s, .ele_separator = ele_separator, .seg_separator = seg_separator };
    }

    pub fn parse(self: Parser) X12Document {
        var options = LexerOptions.init(self.ele_separator, self.seg_separator);
        var lexer = Lexer.init(self.s, options);
        lexer.tokens();

        var segbuf = std.ArrayList(Segment).init(std.heap.page_allocator);
        defer segbuf.deinit();

        var elebuf = std.ArrayList(Element).init(std.heap.page_allocator);
        defer elebuf.deinit();

        const spec = Spec.init();

        for (lexer.tbuffer().items) |token| {
            if (token.typ == TokenType.ele_separator) {
                continue;
            } else if (token.typ == TokenType.eof or token.typ == TokenType.seg_separator or token.typ == TokenType.new_line) {
                const s = Segment.fromElements(spec, elebuf);
                segbuf.append(s) catch @panic("out of memory");
                elebuf.clearAndFree();
            } else {
                elebuf.append(Element.fromToken(token)) catch @panic("out of memory");
            }
        }

        var ts = TransactionSet.init();
        var isabuf = std.ArrayList(InterchangeControlHeader).init(std.heap.page_allocator);
        defer isabuf.deinit();

        var isebuf = std.ArrayList(InterchangeControlTrailer).init(std.heap.page_allocator);
        defer isebuf.deinit();

        for (segbuf.items) |s| {
            ts.addSegment(s);

            if (s.ty == SegmentType.ISA) {
                const cn = std.fmt.parseInt(usize, s.getElement(2).val, 10) catch @panic("parsing error");
                var interchange_ctrl_header = InterchangeControlHeader.init(s.getElement(1).val, s.getElement(2).val, s.getElement(3).val, s.getElement(4).val, s.getElement(5).val, s.getElement(6).val, s.getElement(7).val, s.getElement(8).val, s.getElement(9).val, s.getElement(10).val, s.getElement(11).val, s.getElement(12).val, cn, s.getElement(14).val, s.getElement(16).val, s.getElement(15).val);
                isabuf.append(interchange_ctrl_header) catch @panic("out of memory");
            } else if (s.ty == SegmentType.IEA) {
                const n = std.fmt.parseInt(usize, s.getElement(1).val, 10) catch @panic("parsing error");
                const cn = std.fmt.parseInt(usize, s.getElement(2).val, 10) catch @panic("parsing error");

                var interchange_ctrl_trailer = InterchangeControlTrailer.init(n, cn);
                isebuf.append(interchange_ctrl_trailer) catch @panic("out of memory");
            }
        }

        var fg = FunctionalGroup.init();
        fg.addTransactionSet(ts);

        var doc = X12Document.init(isabuf.pop(), isebuf.pop());
        doc.addFunctionalGroup(fg);

        return doc;
    }
};

test "parser.string" {
    const s = "ISA*01*0000000000*01*0000000000*ZZ*ABCDEFGHIJKLMNO~ZZ*123456789012345*101127*1719*U*00400*000000049*0*P*>~IEA*2*000000049";
    const p = Parser.init(s, '*', '~');
    const r = p.parse();
    _ = r;
}

test "parser.strings" {
    const s = "ISA*01*0000000000*01*0000000000*ZZ*ABCDEFGHIJKLMNO~ZZ*123456789012345*101127*1719*U*00400*000000049*0*P*>~IEA*2*000000049";
    const p = Parser.init(s, '*', '~');
    const r = p.parse();
    _ = r;
}
