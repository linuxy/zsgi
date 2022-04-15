const std = @import("std");
const j2 = @import("jinja2.zig");

var allocator = std.heap.c_allocator;

pub extern "c" fn uwsgi_log(log: [*:0]const u8, ...) void;
pub extern var j2env: ?*anyopaque;

pub export fn application(env: *anyopaque) *Request {
    _ = env;

    var template = j2.get_template(j2env, "index.html");
    var vars = [_][*:0]const u8{"name", "Zero"};

    var rendered = j2.render(@ptrCast(?*anyopaque, template), @as(c_int, 2), @ptrCast([*c][*:0]const u8, &vars));

    var headers = std.AutoHashMap([*:0]const u8, [*:0]const u8).init(allocator);
    headers.put("Content-Type", "text/plain") catch unreachable;

    var request = allocator.create(Request) catch unreachable;

    request.headers = &headers;
    request.body = j2.PyUnicode_AsUTF8(rendered);
    request.status = "200 OK";

    return request;
}

const Request = struct {
    headers: *std.AutoHashMap([*:0]const u8, [*:0]const u8),
    body: [*:0]const u8,
    status: [*:0]const u8,
};