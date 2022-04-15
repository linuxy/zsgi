const std = @import("std");
const j2 = @import("jinja2.zig");
const builtin = @import("builtin");
const target = builtin.target;

pub extern "c" fn uwsgi_response_prepare_headers(wsgi_req: *anyopaque, buf: [*:0]const u8, buf_len: u16) i32;
pub extern "c" fn uwsgi_response_add_header(wsgi_req: *anyopaque, key: [*:0]const u8, key_len: u16, val: [*:0]const u8, val_len: u16) i32;
pub extern "c" fn uwsgi_response_write_body_do(wsgi_req: *anyopaque, buf: [*:0]const u8, buf_len: u64) i32;
pub extern "c" fn uwsgi_zig_build_env(wsgi_req: *anyopaque, env: *u8) i32;
pub extern "c" fn uwsgi_log(log: [*:0]const u8, ...) void;

var allocator = std.heap.c_allocator;
var app: Symbol = undefined;
pub export var j2env: ?*anyopaque = undefined;

pub export fn zig_load_fn(name: [*:0]const u8) i32 {
    var lib = loadLibrary("");
    app = lib.getEntryPoint(name);
    uwsgi_log("[zsgi] found entrypoint symbol: %s\n", name);
    j2env = j2.init_environment("plugins/zsgi/templates/");
    uwsgi_log("[zsgi] jinja2 template engine initialized\n");
    return 0;
}

pub export fn zig_add_env(env: *std.AutoHashMap([*:0]const u8, [*:0]const u8), key: [*:0]const u8, val: [*:0]const u8) i32 {

    env.put(key, val) catch unreachable;

    return 0;
}

pub export fn zig_request_handler(wsgi_req: *anyopaque) i32 {
    var env = std.AutoHashMap([*:0]const u8, [*:0]const u8).init(allocator);
    defer env.deinit();
    
    if(uwsgi_zig_build_env(wsgi_req, @ptrCast(*u8, &env)) != 0) {
        return -1;
    }

    var request = @call(.{}, @ptrCast(fn(*anyopaque) *Request, app), .{@ptrCast(*anyopaque, &env)});

    var status = std.mem.span(request.status);
    var headers = request.headers.*;
    defer headers.deinit();
    var body = std.mem.span(request.body);

    var ret = uwsgi_response_prepare_headers(wsgi_req, status, @intCast(u16, status.len));
    if(ret != 0)
        return ret;

    var it = headers.iterator();
    while (it.next()) |header| {
        var header_0 = std.mem.span(header.key_ptr.*);
        var header_1 = std.mem.span(header.value_ptr.*);
        ret = uwsgi_response_add_header(wsgi_req, header_0, @intCast(u16, header_0.len), header_1, @intCast(u16, header_1.len));
        if(ret != 0)
            return ret;
    }

    ret = uwsgi_response_write_body_do(wsgi_req, body, @intCast(u64, body.len));
    if(ret != 0)
        return ret;

    allocator.destroy(request);
    return 0;
}

const impl = switch (target.os.tag) {
    .linux => struct {
        const Handle = *anyopaque;

        const RTLD_LAZY = 1;
        const RTLD_NOW = 2;

        extern fn dlopen(filename: [*c]const u8, flags: c_int) ?Handle;
        extern fn dlsym(handle: Handle, symbol: [*c]const u8) ?*anyopaque;
        extern fn dlclose(handle: Handle) c_int;

        fn getEntryPoint(handle: Handle, name: [*:0]const u8) Symbol {
            var zstr = std.mem.sliceTo(@ptrCast([*:0]const u8, name), 0);
            return dlsym(handle, zstr.ptr).?;
        }

        fn loadLibrary(name: [*:0]const u8) Handle {
            var zstr = std.mem.sliceTo(@ptrCast([*:0]const u8, name), 0);
            return dlopen(zstr.ptr, RTLD_LAZY).?;
        }
    },
    else => @compileError("OS not supported for shared object."), 
};

pub const LibraryHandle = struct {
    handle: impl.Handle,

    fn getEntryPoint(self: @This(), name: [*:0]const u8) Symbol {
        return impl.getEntryPoint(self.handle, name);
    }
};

pub const Symbol = *anyopaque;

pub fn loadLibrary(name: [*:0]const u8) LibraryHandle {
    return LibraryHandle{
        .handle = impl.loadLibrary(name),
    };
}

const Request = struct {
    headers: *std.AutoHashMap([*:0]const u8, [*:0]const u8),
    body: [*:0]const u8,
    status: [*:0]const u8,
};