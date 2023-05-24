const std = @import("std");
const meta = std.meta;
const trait = meta.trait;
const assert = std.debug.assert;
const utils = @import("./utils.zig");
const Field = std.builtin.Type.StructField;
const testing = std.testing;

/// Error
pub const Error = error{
    /// Env variable is not existed.
    NotExist,
    /// Could not deserialize value.
    InvalidValue,
};

pub const StructEnv = struct {
    /// Process env
    env_map: std.process.EnvMap,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    // --------------------------------------------------------------------------------
    //                                  Public API
    // --------------------------------------------------------------------------------

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .env_map = undefined,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.env_map.deinit();
    }

    pub fn fromEnv(self: *Self, comptime T: type) !T {
        var env_map = try std.process.getEnvMap(self.allocator);
        errdefer env_map.deinit();

        self.env_map = env_map;

        var value: T = undefined;
        try self.deserializeInto(&value, null);

        return value;
    }

    // --------------------------------------------------------------------------------
    //                                  Private API
    // --------------------------------------------------------------------------------

    /// This is for unittest mock!
    fn fromEnvMock(self: *Self, comptime T: type, env_map: std.process.EnvMap) !T {
        self.env_map = env_map;

        var value: T = undefined;
        try self.deserializeInto(&value, null);

        return value;
    }

    /// Get the env value from the key.
    /// If env is not existed, return null.
    fn getEnv(self: Self, key: []const u8) ?[]const u8 {
        var buf = self.allocator.alloc(u8, key.len) catch return "";
        defer self.allocator.free(buf);

        const upper_key = std.ascii.upperString(buf, key);
        var value = self.env_map.get(upper_key);
        if (value == null) {
            value = self.env_map.get(key);
        }

        return value;
    }

    /// Get the default value of a struct field, return null if there is no default value.
    fn getDefault(self: Self, comptime T: type, comptime field: Field) ?T {
        _ = self;
        if (field.default_value) |default_value| {
            const anyopaque_pointer: *anyopaque = @constCast(default_value);
            return @ptrCast(*T, @alignCast(field.alignment, anyopaque_pointer)).*;
        }

        return null;
    }

    /// Deserialize into a value
    fn deserializeInto(self: *Self, ptr: anytype, comptime field: ?Field) !void {
        const T = @TypeOf(ptr);
        comptime assert(trait.is(.Pointer)(T));

        const C = comptime meta.Child(T);

        ptr.* = switch (C) {
            []const u8 => try self.deserializeString(C, field.?),
            // ?[]const u8 => null,
            else => switch (@typeInfo(C)) {
                .Struct => try self.deserializeStruct(C),
                .Enum => try self.deserializeEnum(C, field.?),
                .Optional => try self.deserializeOptional(C, field.?),
                .Bool => try self.deserializeBool(C, field.?),
                // .Int => |info| info.bits,
                .Int => try self.deserializeInt(C, field.?),
                .Float => try self.deserializeFloat(C, field.?),
                // .Array => try self.deserializeArray(C),
                // .Vector => try self.deserializeVector(C),
                .Pointer => try self.deserializePointer(C, field.?),

                // ...
                else => @compileError("Unsupported deserialization type " ++ @typeName(C) ++ "\n"),
            },
        };
    }

    /// Deserialize a string
    fn deserializeString(self: *Self, comptime T: type, comptime field: Field) !T {
        var value = self.getEnv(field.name);
        if (value == null) {
            value = self.getDefault(T, field);
        }
        if (value) |v| {
            const new_v = try self.allocator.dupe(u8, v);
            return new_v;
        }

        return Error.NotExist;
    }

    /// Deserialize a int
    fn deserializeInt(self: *Self, comptime T: type, comptime field: Field) !T {
        const value = self.getEnv(field.name);
        if (value) |v| {
            return try std.fmt.parseInt(T, v, 0);
        }

        return self.getDefault(T, field) orelse Error.NotExist;
    }

    /// Deserialize a float
    fn deserializeFloat(self: *Self, comptime T: type, comptime field: Field) !T {
        const value = self.getEnv(field.name);
        if (value) |v| {
            return try std.fmt.parseFloat(T, v);
        }

        return self.getDefault(T, field) orelse Error.NotExist;
    }

    /// Deserialize a boole
    fn deserializeBool(self: *Self, comptime T: type, comptime field: Field) !T {
        var value = self.getEnv(field.name);
        if (value) |v| {
            return try utils.str2bool(self.allocator, v);
        }

        return self.getDefault(T, field) orelse Error.NotExist;
    }

    /// Deserialize a slice
    fn deserializePointer(self: *Self, comptime T: type, comptime field: Field) !T {
        const value = self.getEnv(field.name);
        if (value) |v| {
            const C = comptime meta.Child(T);
            // TODO: delimiter
            var it = std.mem.split(u8, v, ",");
            var new_value = std.ArrayList(C).init(self.allocator);
            defer new_value.deinit();

            while (it.next()) |s| {
                const item = switch (C) {
                    []const u8 => try self.allocator.dupe(u8, s),
                    // []const u8 => s,
                    else => switch (@typeInfo(C)) {
                        .Bool => try utils.str2bool(self.allocator, s),
                        .Int => try std.fmt.parseInt(C, s, 0),
                        .Float => try std.fmt.parseFloat(C, s, 0),
                        else => @compileError("Unsupported deserialization type" ++ @typeName(C) ++ "\n"),
                    },
                };
                try new_value.append(item);
            }

            return new_value.toOwnedSlice();
        }

        const default_value = self.getDefault(T, field);
        if (default_value) |v| {
            const C = comptime meta.Child(T);
            var new_value = std.ArrayList(C).init(self.allocator);
            defer new_value.deinit();

            for (v) |s| {
                const item = switch (C) {
                    []const u8 => try self.allocator.dupe(u8, s),
                    else => switch (@typeInfo(C)) {
                        .Bool => s,
                        .Int => s,
                        .Float => s,
                        else => @compileError("Unsupported deserialization type" ++ @typeName(C) ++ "\n"),
                    },
                };
                try new_value.append(item);
            }

            return new_value.toOwnedSlice();
        }

        return Error.NotExist;
    }

    /// Deserialize an string enum
    fn deserializeEnum(self: *Self, comptime T: type, comptime field: Field) !T {
        // const I = comptime meta.Tag(T);

        const value = self.getEnv(field.name);
        if (value) |v| {
            if (std.meta.stringToEnum(T, v)) |vv| {
                return vv;
            }
            return Error.InvalidValue;
        }

        return self.getDefault(T, field) orelse Error.NotExist;
    }

    /// Deserialize a struct
    fn deserializeStruct(self: *Self, comptime T: type) !T {
        var value: T = undefined;
        inline for (meta.fields(T)) |struct_field| {
            // std.debug.print("field name is {s}\n", .{struct_field.name});
            // field.name = struct_field.name;
            // self.field_default_value = struct_field.default_value;
            try self.deserializeInto(&@field(value, struct_field.name), struct_field);
        }
        return value;
    }

    /// Deserialize an optional
    fn deserializeOptional(self: *Self, comptime T: type, comptime field: Field) !T {
        const C = comptime meta.Child(T);
        var value: C = undefined;
        self.deserializeInto(&value, field) catch |e| {
            if (e == Error.NotExist) {
                return null;
            }
            return e;
        };

        return value;
    }
};

/// Load env and return a value of the specified type T.
pub fn fromEnv(allocator: std.mem.Allocator, comptime T: type) !T {
    var e = StructEnv.init(allocator);
    defer e.deinit();
    var v = try e.fromEnv(T);
    return v;
}

fn fromEnvMock(allocator: std.mem.Allocator, comptime T: type, env_map: std.process.EnvMap) !T {
    var e = StructEnv.init(allocator);
    defer e.deinit();
    var v = try e.fromEnvMock(T, env_map);
    return v;
}

/// Free a value created by this lib.
pub fn free(allocator: std.mem.Allocator, value: anytype) void {
    const T = @TypeOf(value);

    inline for (meta.fields(T)) |struct_field| {
        switch (struct_field.type) {
            []const u8 => allocator.free(@field(value, struct_field.name)),
            else => {
                switch (@typeInfo(struct_field.type)) {
                    .Pointer => {
                        var need_free = true;
                        // const cur = @field(value, struct_field.name);

                        // if (struct_field.default_value) |default_value| {
                        //     const anyopaque_pointer: *anyopaque = @constCast(default_value);
                        //     var dflt_ptr = @ptrCast(*struct_field.type, @alignCast(struct_field.alignment, anyopaque_pointer));
                        //     // std.debug.print("\r\n{d} {d}\r\n", .{ &cur, dflt_ptr });
                        //     // std.debug.print("\r\n{d} {d}\r\n\r\n", .{ @ptrToInt(@field(value, struct_field.name)), @ptrToInt(default_value) });
                        //     if (&cur != dflt_ptr) {
                        //         need_free = true;
                        //     }
                        // } else {
                        //     need_free = true;
                        // }
                        if (need_free) {
                            for (@field(value, struct_field.name)) |v| {
                                switch (@TypeOf(v)) {
                                    []const u8 => allocator.free(v),
                                    else => {},
                                }
                            }
                            // allocator.destroy(@field(value, struct_field.name));
                            allocator.free(@field(value, struct_field.name));
                        }
                    },
                    else => {},
                }
            },
        }
    }
}

// --------------------------------------------------------------------------------
//                                   Testing
// --------------------------------------------------------------------------------

fn initTestEnv() !std.process.EnvMap {
    var env_map = try std.process.getEnvMap(testing.allocator);
    // For string tests
    try env_map.put("HOME", "/home/mitsuha");

    // For float tests
    try env_map.put("FLOAT", "1.25");

    // For boolean tests
    try env_map.put("TRUE_VALUE", "true");
    try env_map.put("FALSE_VALUE", "false");

    // For int tests
    try env_map.put("int8", "8");
    try env_map.put("int16", "16");
    try env_map.put("int32", "32");
    try env_map.put("uint64", "64");
    try env_map.put("usize", "128");

    // For multi strings tests
    try env_map.put("ANIMES", "KonoSuba,Attack on Titan");

    // For multi int tests
    try env_map.put("INTS", "1,2,3,4");

    // For enum tests
    try env_map.put("en1", "A");
    try env_map.put("en2", "C");

    return env_map;
}

test "test string type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        home: []const u8,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(std.mem.eql(u8, t.home, "/home/mitsuha"));
}

test "test boolean type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        true_value: bool,
        false_value: bool,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.true_value == true);
    try testing.expect(t.false_value == false);
}

test "test int type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        int8: i8,
        int16: i16,
        int32: i32,
        uint64: u64,
        usize: usize,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.int8 == 8);
    try testing.expect(t.int16 == 16);
    try testing.expect(t.int32 == 32);
    try testing.expect(t.uint64 == 64);
    try testing.expect(t.usize == 128);
}

test "test float type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        float: f64,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.float == 1.25);
}

test "test enum type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const E = enum {
        A,
        B,
        C,
    };
    const T = struct {
        en1: E,
        en2: E,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.en1 == .A);
    try testing.expect(t.en2 == .C);
}

test "test optional type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const E = enum {
        A,
        B,
        C,
    };

    const T = struct {
        home: []const u8,
        homex: ?[]const u8,
        int007: ?u32,
        en20: ?E,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(std.mem.eql(u8, t.home, "/home/mitsuha"));
    try testing.expect(t.homex == null);
    try testing.expect(t.int007 == null);
    try testing.expect(t.en20 == null);
}

test "test multi integer type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        ints: []u8,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.ints.len == 4);
}

test "test multi string type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        animes: [][]const u8,
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(t.animes.len == 2);
    try testing.expect(std.mem.eql(u8, t.animes[0], "KonoSuba"));
    try testing.expect(std.mem.eql(u8, t.animes[1], "Attack on Titan"));
}

test "test default type" {
    const allocator = testing.allocator;

    const env_map = try initTestEnv();

    const T = struct {
        home: []const u8 = "/home/milet",
        homex: []const u8 = "/home/milet",
        true_value: bool = false,
        int8: i8 = 0,
        // singers: []const []const u8 = @constCast(&[_][]const u8{"zutomayo"}),
        singers: []const []const u8 = &.{"zutomayo"},
    };

    const t = try fromEnvMock(allocator, T, env_map);
    defer free(allocator, t);

    try testing.expect(std.mem.eql(u8, t.home, "/home/mitsuha"));
    try testing.expect(std.mem.eql(u8, t.homex, "/home/milet"));
    try testing.expect(t.true_value == true);
    try testing.expect(t.int8 == 8);
    try testing.expect(t.singers.len == 1);
    try testing.expect(std.mem.eql(u8, t.singers[0], "zutomayo"));
}

test "test real env in GitHub Action" {
    const allocator = testing.allocator;
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    // Always set to true in GitHub Action
    if (env_map.get("CI")) |v| {
        if (std.mem.eql(u8, v, "true")) {
            // TODO:
            // const T = struct {

            // };
            // const t = try fromEnv(allocator, T);
            // defer free(allocator, t);
        }
    }
}
