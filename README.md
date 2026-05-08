<h1 align="center"> struct-env 🌱 </h1>

<p align="center"> 𝒉𝒂𝒏𝒅𝒍𝒊𝒏𝒈 𝒆𝒏𝒗𝒊𝒓𝒐𝒏𝒎𝒆𝒏𝒕 𝒗𝒂𝒓𝒊𝒂𝒃𝒍𝒆𝒔 𝒊𝒏 𝒂 𝒕𝒚𝒑𝒆-𝒔𝒂𝒇𝒆 𝒘𝒂𝒚. </p>

[![CI](https://github.com/Hanaasagi/struct-env/actions/workflows/ci.yaml/badge.svg)](https://github.com/Hanaasagi/struct-env/actions/workflows/ci.yaml)
[![codecov](https://codecov.io/gh/Hanaasagi/struct-env/branch/master/graph/badge.svg?token=DQQZETSCW3)](https://codecov.io/gh/Hanaasagi/struct-env)
![](https://img.shields.io/badge/language-zig-%23ec915c)

**NOTE: Supported Zig Version is 0.16.0**

## What is `struct-env`

`struct-env` provides a way to handle environment variables using struct fields.
Its advantage is the automatic deserialization of environment variables into the specified types.
For example, instead of using `std.mem.eql(u8, foo, "true")` to determine the truth value of an env-var,
`struct-env` allows us to simply use `foo: bool` to deserialize it into a boolean type.

## Quick Start

Below is a basic example:

```zig
const std = @import("std");
const struct_env = @import("struct-env");

const MyEnv = struct {
    home: []const u8,
    foo: ?[]const u8,
    bar: []const u8 = "bar",
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const env = try struct_env.fromEnv(allocator, MyEnv, init.environ_map);
    defer struct_env.free(allocator, env);

    std.debug.print("HOME is {s}\n", .{env.home});
    std.debug.print("FOO  is {any}\n", .{env.foo == null});
    std.debug.print("BAR  is {s}\n", .{env.bar});
}
```

Here are some examples of this program's output.
You can find more examples in the `examples` directory.

```
$ zig run [file]
HOME is /home/username
FOO  is true
BAR  is bar
```

```
$ FOO="foo" BAR="bar" zig run [file]
HOME is /home/username
FOO  is false
BAR  is bar
```

`struct-env` assumes that there is an environment variable corresponding to each struct field, with the same name in all uppercase letters.
For instance, a struct field `foo_bar` would be expected to have an environment variable named `FOO_BAR`.

Structs with fields of type Optional(`?` prefix) can be successfully deserialized even if their associated environment variable is not present.

Of course, if the variable does not exist, you can set a default value.

`struct-env` also supports deserializing slice from comma separated env var values.

## Env-var with common prefix

The common pattern for prefixeing env var names for a specific app is supported using the `fromPrefixedEnv`.
Asumming your env vars are prefixed with `APP_`, the example may look like

```zig
const MyEnv = struct {
    // APP_NAME
    name : []const u8,
};

const env = try struct_env.fromPrefixedEnv(allocator, MyEnv, init.environ_map, "APP_");
defer struct_env.free(allocator, env);
```

Starting with Zig 0.16, environment variables are no longer globally queried by the standard library.
Applications receive environment data through `main(init: std.process.Init)`, and `struct-env` deserializes the `init.environ_map` provided by the application.

## Supported types:

- Built-in types, such as `[]const u8`, `i32`
- Optional types, such as `?u32`
- Slice types, such as `[][]const u8`

## License

MIT

<hr>

Thanks to those who have helped me on Reddit and Stack Overflow.
