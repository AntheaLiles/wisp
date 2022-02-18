const std = @import("std");

const wisp = @import("./base.zig");
const W = wisp.W;

test "print one" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    try list.writer().print("{}", .{1});
    try std.testing.expectEqualStrings("1", list.items);
}

pub fn printAlloc(
    allocator: std.mem.Allocator,
    ctx: *wisp.Wisp,
    word: W,
) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try print(ctx, list.writer(), word);
    return list.toOwnedSlice();
}

pub fn dump(prefix: []const u8, ctx: *wisp.Wisp, word: W) !void {
    var s = try printAlloc(ctx.heap.allocator, ctx, word);
    std.log.warn("{s} {s}", .{ prefix, s });
    ctx.heap.allocator.free(s);
}

pub fn print(ctx: *wisp.Wisp, writer: anytype, word: W) anyerror!void {
    if (word.isFixnum()) {
        try writer.print("{d}", .{word.fixnum()});
    } else if (word.isNil()) {
        try writer.print("NIL", .{});
    } else if (word.isListPointer()) {
        try writer.print("(", .{});

        var cur = word;
        while (!cur.isNil()) {
            var cons = try ctx.heap.derefCons(cur);
            try print(ctx, writer, cons.car);
            if (cons.cdr.isNil()) {
                break;
            } else if (cons.cdr.isListPointer()) {
                try writer.print(" ", .{});
                cur = cons.cdr;
            } else {
                try writer.print(" . ", .{});
                try print(ctx, writer, cons.cdr);
                break;
            }
        }

        try writer.print(")", .{});
    } else if (word.isOtherPointer()) {
        const data = try ctx.heap.deref(word);
        if (data[0].raw == wisp.symbolHeader.raw) {
            const symbol = try ctx.getSymbolData(word);
            try writer.print(
                "{s}",
                .{try ctx.stringBufferAsSlice(symbol.name)},
            );
        } else if (data[0].lowtag() == .otherptr) {
            try writer.print("«fwd {d}»", .{data[0].raw});
        } else if (data[0].widetag() == .string) {
            try writer.print(
                "\"{s}\"",
                .{try ctx.stringBufferAsSlice(word)},
            );
        } else {
            try writer.print("[otherptr {}]", .{word.raw});
        }
    } else if (word.lowtag() == .structptr) {
        const data = try ctx.heap.deref(word);
        try writer.print("«instance ", .{});
        const n = data[0].immediate();
        for (data[1..n]) |x, i| {
            try print(ctx, writer, x);
            if (i < n - 2) {
                try writer.print(" ", .{});
            }
        }
        try writer.print("»", .{});
    } else {
        try writer.print("[unknown {}]", .{word.raw});
    }
}

fn expectPrintResult(ctx: *wisp.Wisp, expected: []const u8, x: W) !void {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    const writer = list.writer();

    try print(ctx, &writer, x);
    try std.testing.expectEqualStrings(expected, list.items);
}

test "print fixnum" {
    var ctx = try wisp.testWisp();
    defer ctx.heap.free();

    try expectPrintResult(&ctx, "1", wisp.fixnum(1));
}

test "print lists" {
    var ctx = try wisp.testWisp();
    defer ctx.heap.free();

    try expectPrintResult(
        &ctx,
        "(1 2 3)",
        try ctx.list(
            [_]W{
                wisp.fixnum(1),
                wisp.fixnum(2),
                wisp.fixnum(3),
            },
        ),
    );

    try expectPrintResult(
        &ctx,
        "(1 . 2)",
        try ctx.cons(wisp.fixnum(1), wisp.fixnum(2)),
    );

    try expectPrintResult(
        &ctx,
        "(1 . 2)",
        try ctx.cons(wisp.fixnum(1), wisp.fixnum(2)),
    );
}

test "print symbols" {
    var ctx = try wisp.testWisp();
    defer ctx.heap.free();

    try expectPrintResult(
        &ctx,
        "FOO",
        try wisp.internSymbol(
            &ctx,
            try wisp.makeString(&ctx.heap, "FOO"),
            ctx.basePackage,
        ),
    );
}

test "print structs" {
    var ctx = try wisp.testWisp();
    defer ctx.heap.free();

    try expectPrintResult(
        &ctx,
        "«instance PACKAGE \"WISP\"»",
        ctx.basePackage,
    );
}

test "print strings" {
    var ctx = try wisp.testWisp();
    defer ctx.heap.free();

    try expectPrintResult(
        &ctx,
        "\"hello\"",
        try wisp.makeString(&ctx.heap, "hello"),
    );
}
