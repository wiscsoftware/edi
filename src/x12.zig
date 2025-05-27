const std = @import("std");
const seg = @import("segment.zig");
const tok = @import("lexer.zig");

const Segment = seg.Segment;
const SegmentType = seg.SegmentType;
const InterchangeControlTrailer = seg.InterchangeControlTrailer;
const InterchangeControlHeader = seg.InterchangeControlHeader;
const FunctionalGroupHeader = seg.FunctionalGroupHeader;
const FunctionalGroupTrailer = seg.FunctionalGroupTrailer;
const TransactionSetHeader = seg.TransactionSetHeader;
const TransactionSetTrailer = seg.TransactionSetTrailer;

const Token = tok.Token;

pub const TransactionSet = struct {
    buffer: std.ArrayList(Segment),
    head: TransactionSetHeader,
    trail: TransactionSetTrailer,

    pub fn init() TransactionSet {
        var buf = std.ArrayList(Segment).init(std.heap.page_allocator);
        return TransactionSet{
            .buffer = buf,
            .head = TransactionSetHeader.init(),
            .trail = TransactionSetTrailer.init(),
        };
    }

    pub fn addSegment(self: *TransactionSet, s: Segment) void {
        self.buffer.append(s) catch @panic("out of memeory");
    }
};

pub const FunctionalGroup = struct {
    buffer: std.ArrayList(TransactionSet),
    head: FunctionalGroupHeader,
    trail: FunctionalGroupTrailer,

    pub fn init() FunctionalGroup {
        var buf = std.ArrayList(TransactionSet).init(std.heap.page_allocator);
        return FunctionalGroup{
            .buffer = buf,
            .head = FunctionalGroupHeader.init(),
            .trail = FunctionalGroupTrailer.init(),
        };
    }

    pub fn addTransactionSet(self: *FunctionalGroup, ts: TransactionSet) void {
        self.buffer.append(ts) catch @panic("out of memory");
    }
};

pub const X12Document = struct {
    // keep track by functional group in order
    buffer: std.ArrayList(FunctionalGroup),
    head: InterchangeControlHeader,
    trail: InterchangeControlTrailer,

    pub fn init(head: InterchangeControlHeader, trail: InterchangeControlTrailer) X12Document {
        var buf = std.ArrayList(FunctionalGroup).init(std.heap.page_allocator);
        return X12Document{ .head = head, .trail = trail, .buffer = buf };
    }

    pub fn header(self: *X12Document) InterchangeControlHeader {
        return self.head;
    }

    pub fn trailer(self: *X12Document) InterchangeControlTrailer {
        return self.trail;
    }

    pub fn addFunctionalGroup(self: *X12Document, fg: FunctionalGroup) void {
        self.buffer.append(fg) catch @panic("out of memory");
    }
};
