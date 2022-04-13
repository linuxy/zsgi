const std = @import("std");

var allocator = std.heap.c_allocator;

pub extern "c" fn uwsgi_log(log: [*:0]const u8, ...) void;

pub export fn application(env: *anyopaque) *Request {
    _ = env;

    var headers = std.AutoHashMap([*:0]const u8, [*:0]const u8).init(allocator);
    headers.put("Content-Type", "text/plain") catch unreachable;

    var request = allocator.create(Request) catch unreachable;

    request.headers = &headers;
    request.body = "Hello Zero";
    request.status = "200 OK";

    return request;
}

const Request = struct {
    headers: *std.AutoHashMap([*:0]const u8, [*:0]const u8),
    body: [*:0]const u8,
    status: [*:0]const u8,
};