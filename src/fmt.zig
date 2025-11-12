// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;

/// Prints a hex dump of the provided slice.
pub const HexDump = @import("HexDump.zig");

/// A custom formater (for structs) with the ability to hint how to render the field.
/// ```zig
/// const ex = struct {
///     a: u8,
///     b: u16,
///     c: bool,
///     d: []u8, // str
///
///     pub const format = formatWithHint(@This(), .{ .b = "0x{X}", .d = .str, .c = .skip});
/// };
/// ```
///
/// `options` => `.{K:V, ...}` where the `K` is the field of the object (enum literal) and `V` is one of the following...
/// - `<fn>`         :: calls the fn like a format procedure for that field.
/// - `<ptr>`        :: assumption is a format string, concat and use.
/// - `.skip`        :: skips and doesn't print the field.
/// - `.skip_noted`  :: skips printing out the value but still notes the existence of the field. E.g. `.field_name = ⋯`.
/// - `.str`         :: Anything string like gets formatted with `"{s}"`.
/// - `.fixed_c_str` :: C-like string that can be passed to `std.mem.sliceTo(str, 0)` prior to `"{s}"`.
/// - `.unix_time`   :: An int that is convertible into a `std.posix.time_t`, producing an 8601 like date-time str. E.g. `[2025-11-12T17:51:05]`.
///                     `libc` needs to be enabled for this field.
pub fn formatWithHint(T: type, comptime options: anytype) fn (T, *io.Writer) io.Writer.Error!void {
    return switch (@typeInfo(T)) {
        .@"struct" => fmtStruct(T, options),
        else => @compileError(fmt.comptimePrint("Unsuported type: {s}", .{@typeName(T)})),
    };
}

fn fmtStruct(T: type, comptime options: anytype) fn (T, *io.Writer) io.Writer.Error!void {
    return struct {
        fn format(self: T, w: *io.Writer) io.Writer.Error!void {
            const ti = @typeInfo(T).@"struct";

            try w.writeAll(".{ ");
            inline for (ti.fields, 0..) |field, idx| {
                if (@hasField(@TypeOf(options), field.name)) {
                    const opt = @field(options, field.name);

                    switch (@typeInfo(@TypeOf(opt))) {
                        .@"fn" => {
                            try w.writeAll("." ++ field.name ++ " = ");
                            try opt(@field(self, field.name), w);
                        },
                        .pointer => try w.print("." ++ field.name ++ " = " ++ opt, .{@field(self, field.name)}),
                        .enum_literal => switch (opt) {
                            .skip => continue,
                            .skip_noted => try w.writeAll("." ++ field.name ++ " = ⋯"),
                            .str => try w.print("." ++ field.name ++ " = \"{s}\"", .{@field(self, field.name)}),
                            .fixed_c_str => try w.print("." ++ field.name ++ " = \"{s}\"", .{mem.sliceTo(&@field(self, field.name), 0)}),
                            .flags => {
                                try w.writeAll("." ++ field.name ++ " = ");
                                try flagsFormat(@field(self, field.name), w);
                            },
                            .unix_time => try time8601Format(@intCast(@field(self, field.name)), w),
                            else => @compileError("Unimplemented"),
                        },
                        else => @compileError("Unimplemented"),
                    }
                } else {
                    try w.print(".{s} = {}", .{ field.name, @field(self, field.name) });
                }
                if (idx != ti.fields.len - 1) {
                    try w.writeAll(", ");
                }
            }
            try w.writeAll(" }");
        }
    }.format;
}

/// Prints a list of only enabled fields, skipping any non-bool types. E.g. `(berries citrus stone)`
pub fn flagsFormat(self: anytype, w: *io.Writer) io.Writer.Error!void {
    const T = @TypeOf(self);
    const ti = switch (@typeInfo(T)) {
        .@"struct" => |s| s,
        .pointer => |p| switch (@typeInfo(p.child)) {
            .@"struct" => |s| s,
            else => @compileError("Unsupported type"),
        },
        else => @compileError("Unsupported type"),
    };

    var space = false;
    try w.writeAll("(");
    inline for (ti.fields) |f| {
        if (f.type == bool and @field(self, f.name)) {
            if (space) try w.writeByte(' ');
            try w.writeAll(f.name);
            space = true;
        }
    }
    try w.writeAll(")");
}

/// Prints an 8601 style time from `time_t` without timezone marker. E.g. `[2025-11-12T17:51:05]`
pub fn time8601Format(t: std.posix.time_t, w: *io.Writer) io.Writer.Error!void {
    if (@import("builtin").link_libc) {
        const Time = @cImport({
            @cInclude("time.h");
        });

        var tm: Time.struct_tm = undefined;
        _ = Time.gmtime_r(&t, &tm);

        var ut_buf: ["[2025-11-12T17:51:05]".len + 1]u8 = undefined;
        const ut_len = Time.strftime(&ut_buf, ut_buf.len, "[%FT%T]", &tm);
        try w.writeAll(ut_buf[0..ut_len]);
    } else {
        @compileError("Missing libc for time conversion support");
    }
}

//
//
//

const TT = std.testing;

test formatWithHint {}

test flagsFormat {
    const FruitDish = struct {
        berries: bool,
        citrus: bool,
        tropical: bool,
        stone: bool,
        other: bool,
        cake: u3,

        // pub const format = withFmtType(@This(), flagsFormat);
        pub const format = flagsFormat;
    };

    const dish: FruitDish = .{
        .berries = true,
        .citrus = true,
        .tropical = false,
        .stone = true,
        .other = false,
        .cake = 3,
    };

    var buffer: [50]u8 = undefined;
    const salad = try fmt.bufPrint(&buffer, "{f}", .{dish});
    try TT.expectEqualStrings("(berries citrus stone)", salad);
}

test time8601Format {
    const t: std.posix.time_t = 1762935250;
    const str = "[2025-11-12T08:14:10]";

    var buffer: [50]u8 = undefined;
    var w = io.Writer.fixed(&buffer);
    try time8601Format(t, &w);

    try TT.expectEqualStrings(str, w.buffered());
}

test {
    TT.refAllDeclsRecursive(@This());
}
