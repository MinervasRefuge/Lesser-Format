// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const io = std.io;
const fmt = std.fmt;

data: []const u8,

pub fn from(in: []const u8) @This() {
    return .{ .data = in };
}

pub fn format(data: @This(), writer: *io.Writer) io.Writer.Error!void {
    try writer.writeAll("       x0 x1 x2 x3 x4 x5 x6 x7  x8 x9 xA xB xC xD xE xF\n");
    try writer.writeAll("     ┌");
    try writer.splatBytesAll("─", 49);
    try writer.writeByte('\n');

    var itr = std.mem.window(u8, data.data, 16, 16);
    var idx: usize = 0;
    while (itr.next()) |line| : (idx += 16) {
        try writer.print("{X: >5}│ ", .{idx});

        for (line, 1..) |b, i| { // Write HEX
            try writer.print("{X:0>2}", .{b});
            try if (i % 8 == 0) writer.splatByteAll(' ', 2) else writer.writeByte(' ');
        }

        if (line.len < 16) { // Remaining Spaces on short line
            const rem = 16 - line.len;
            var extra: usize = 0;
            extra += 2 * rem; // hex
            extra += rem; // spaces
            extra += if (rem > 8) 2 else 1; // mid gap

            try writer.splatByteAll(' ', extra);
        }

        for (line, 1..) |b, i| { // Write Text
            try writer.writeByte(if (std.ascii.isPrint(b)) b else '.');
            try if (i % 8 == 0) writer.writeByte(' ');
        }

        try writer.writeByte('\n');
    }
}

//
//
//

const TT = std.testing;

test format {
    const data = [_]u8{
        0xed, 0xcf, 0x07, 0x72, 0xaf, 0x55, 0xa5, 0x78, 0x9c, 0x49, 0xf1, 0xa6, 0x57, 0x27, 0x3e, 0xf0,
        0x4b, 0xd5, 0x0b, 0xc2, 0x29, 0xaf, 0xe1, 0x64, 0xb1, 0xa5, 0xad, 0xfb, 0x00, 0x11, 0x7f, 0x25,
        0x08, 0xda, 0xf3, 0x81, 0x15, 0x0a, 0x95, 0x84, 0x5a, 0x77, 0x89, 0x6a, 0xe5, 0xac, 0xd7, 0xf3,
    };

    const str =
        \\       x0 x1 x2 x3 x4 x5 x6 x7  x8 x9 xA xB xC xD xE xF
        \\     ┌─────────────────────────────────────────────────
        \\    0│ ED CF 07 72 AF 55 A5 78  9C 49 F1 A6 57 27 3E F0  ...r.U.x .I..W'>. 
        \\   10│ 4B D5 0B C2 29 AF E1 64  B1 A5 AD FB 00 11 7F 25  K...)..d .......% 
        \\   20│ 08 DA F3 81 15 0A 95 84  5A 77 89 6A E5 AC D7 F3  ........ Zw.j.... 
        \\
    ;

    var buffer: [512]u8 = undefined;
    try TT.expectEqualStrings(str, try fmt.bufPrint(&buffer, "{f}", .{from(&data)}));

    const str2 =
        \\       x0 x1 x2 x3 x4 x5 x6 x7  x8 x9 xA xB xC xD xE xF
        \\     ┌─────────────────────────────────────────────────
        \\    0│ ED CF 07 72 AF 55 A5 78  9C 49 F1 A6 57 27 3E F0  ...r.U.x .I..W'>. 
        \\   10│ 4B D5 0B C2 29 AF E1 64  B1 A5 AD FB 00 11 7F 25  K...)..d .......% 
        \\   20│ 08 DA F3 81 15 0A 95                              .......
        \\
    ;

    try TT.expectEqualStrings(str2, try fmt.bufPrint(&buffer, "{f}", .{from(data[0..39])}));
}
