// -*- fill-column: 64; -*-
//
// This file is part of Wisp.
//
// Wisp is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License
// as published by the Free Software Foundation, either version
// 3 of the License, or (at your option) any later version.
//
// Wisp is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General
// Public License along with Wisp. If not, see
// <https://www.gnu.org/licenses/>.
//

const std = @import("std");

const wisp = @import("./ff-wisp.zig");
const xops = @import("./07-xops.zig");
const Heap = wisp.Heap;

test "print one" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    try list.writer().print("{}", .{1});
    try std.testing.expectEqualStrings("1", list.items);
}

pub fn expect(
    expected: []const u8,
    heap: *Heap,
    x: u32,
) !void {
    var actual = try printAlloc(std.testing.allocator, heap, x);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

pub fn printAlloc(
    allocator: std.mem.Allocator,
    heap: *Heap,
    word: u32,
) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try dump(heap, list.writer(), word);
    return list.toOwnedSlice();
}

pub fn warn(prefix: []const u8, heap: *Heap, word: u32) !void {
    var s = try printAlloc(heap.orb, heap, word);
    std.log.warn("{s} {s}", .{ prefix, s });
    heap.orb.free(s);
}

pub fn dump(heap: *Heap, out: anytype, x: u32) anyerror!void {
    return dump_(heap, out, x);
}

pub fn dump_(
    heap: *Heap,
    out: anytype,
    x: u32,
) anyerror!void {
    switch (wisp.tagOf(x)) {
        .int => try out.print("{d}", .{x}),

        .sys => {
            switch (x) {
                wisp.nil => try out.print("NIL", .{}),
                wisp.t => try out.print("T", .{}),
                wisp.top => try out.print("#<TOP>", .{}),
                wisp.nah => try out.print("#<NAH>", .{}),
                else => unreachable,
            }
        },

        .sym => {
            const sym = try heap.row(.sym, x);
            const name = heap.v08slice(sym.str);
            if (sym.pkg == wisp.nil) {
                try out.print("#:{s}", .{name});
            } else {
                try out.print("{s}", .{name});
            }
        },

        .v08 => {
            const s = heap.v08slice(x);
            try out.print("\"{s}\"", .{s});
        },

        .v32 => {
            try out.print("#<", .{});
            const xs = try heap.v32slice(x);
            for (xs) |y, i| {
                if (i > 0) try out.print(" ", .{});
                try dump(heap, out, y);
            }
            try out.print(">", .{});
        },

        .duo => {
            try out.print("(", .{});
            var cur = x;

            loop: while (cur != wisp.nil) {
                var cons = try heap.row(.duo, cur);
                try dump(heap, out, cons.car);
                switch (wisp.tagOf(cons.cdr)) {
                    .duo => {
                        try out.print(" ", .{});
                        cur = cons.cdr;
                    },
                    else => {
                        if (cons.cdr != wisp.nil) {
                            try out.print(" . ", .{});
                            try dump(heap, out, cons.cdr);
                        }
                        break :loop;
                    },
                }
            }

            try out.print(")", .{});
        },

        .pkg => {
            try out.print("<package>", .{});
        },

        .ktx => {
            const ktx = try heap.row(.ktx, x);
            try out.print("<%ktx", .{});
            inline for (std.meta.fields(@TypeOf(ktx))) |field| {
                try out.print(" {s}=", .{field.name});
                try dump(heap, out, @field(ktx, field.name));
            }
            try out.print(">", .{});
        },

        .fun => {
            // const fun = try heap.row(.fun, x);
            try out.print("<fun", .{});
            // inline for (std.meta.fields(@TypeOf(fun))) |field| {
            //     try out.print(" {s}=", .{field.name});
            //     try dump(heap, out, @field(fun, field.name));
            // }
            try out.print(">", .{});
        },

        .jet => {
            const jet = xops.jets[wisp.Imm.from(x).idx];
            try out.print("<jet {s}>", .{jet.txt});
        },

        .bot => {
            const bot = try heap.row(.bot, x);
            try out.print("<bot", .{});
            inline for (std.meta.fields(@TypeOf(bot))) |field| {
                try out.print(" {s}=", .{field.name});
                try dump(heap, out, @field(bot, field.name));
            }
            try out.print(">", .{});
        },

        else => |t| try out.print("<{any}>", .{t}),
    }
}

fn expectPrintResult(heap: *Heap, expected: []const u8, x: u32) !void {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    const writer = list.writer();

    try dump(heap, &writer, x);
    try std.testing.expectEqualStrings(expected, list.items);
}

test "print fixnum" {
    var heap = try Heap.init(std.testing.allocator, .e0);
    defer heap.deinit();

    try expectPrintResult(&heap, "1", 1);
}

test "print constants" {
    var heap = try Heap.init(std.testing.allocator, .e0);
    defer heap.deinit();

    try expectPrintResult(&heap, "NIL", wisp.nil);
    try expectPrintResult(&heap, "T", wisp.t);
}

test "print lists" {
    var heap = try Heap.init(std.testing.allocator, .e0);
    defer heap.deinit();

    try expectPrintResult(
        &heap,
        "(1 2 3)",
        try wisp.list(&heap, [_]u32{ 1, 2, 3 }),
    );

    try expectPrintResult(
        &heap,
        "(1 . 2)",
        try heap.new(.duo, .{ .car = 1, .cdr = 2 }),
    );
}

test "print symbols" {
    var heap = try Heap.init(std.testing.allocator, .e0);
    defer heap.deinit();

    try expectPrintResult(
        &heap,
        "FOO",
        try heap.intern("FOO", heap.base),
    );
}

test "print uninterned symbols" {
    var heap = try Heap.init(std.testing.allocator, .e0);
    defer heap.deinit();

    try expectPrintResult(
        &heap,
        "#:FOO",
        try heap.newSymbol("FOO", wisp.nil),
    );
}

// test "print structs" {
//     var heap = try Heap.init(std.testing.allocator);
//     defer heap.deinit();

//     try expectPrintResult(
//         &heap,
//         "«instance PACKAGE \"WISP\"»",
//         0,
//     );
// }

test "print strings" {
    var heap = try Heap.init(std.testing.allocator, .e1);
    defer heap.deinit();

    try expectPrintResult(
        &heap,
        "\"hello\"",
        try heap.newv08("hello"),
    );
}
