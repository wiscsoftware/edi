const std = @import("std");
const test_allocator = std.testing.allocator;

pub fn readfile(file_name: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();
    const stat = try file.stat();
    const size = stat.size;
    return try file.reader().readAllAlloc(alloc, size);
}

test "fread" {
    const s = "../assets/x12.base.no.line.breaks.txt";
    const content = try readfile(s, test_allocator);
    defer test_allocator.free(content);
    //std.debug.print("{s}\n", .{content});
}
