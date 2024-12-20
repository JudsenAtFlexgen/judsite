const std = @import("std");
// fetches
const zap = @import("zap");
const sqlite = @import("sqlite");
// user
const handlers = @import("handlers.zig");

var base = std.heap.GeneralPurposeAllocator(.{}){};
const base_allocator = base.allocator();
var submission_info = std.StringHashMap([]const u8).init(base_allocator);

var db: sqlite.Db = undefined;

fn on_request(r: zap.Request) void {
    // create an arena
    // arena is culled after every request finishes. Thus memory leaks are essentially not possible
    // assuming nothing strange occurs and the request runs to completion.
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // var html_response = std.ArrayList(u8).init(arena_allocator);

    switch (r.methodAsEnum()) {
        zap.Method.GET => blk: {
            if (std.mem.eql(u8, "/css/out.css", r.path.?)) {
                const install_dir = std.fs.selfExeDirPathAlloc(arena_allocator) catch unreachable;
                var css_file = std.ArrayList(u8).fromOwnedSlice(arena_allocator, install_dir);
                defer css_file.deinit();
                css_file.appendSlice("/css/out.css") catch unreachable;
                const file = std.fs.cwd().createFile(
                    css_file.items,
                    .{ .read = true, .truncate = false },
                ) catch unreachable;
                defer file.close();

                const contents = file.readToEndAlloc(arena_allocator, 200 * 1000) catch unreachable;
                r.sendBody(contents) catch return;
            } else if (std.mem.eql(u8, "/", r.path.?)) {
                const install_dir = std.fs.selfExeDirPathAlloc(arena_allocator) catch unreachable;
                var html = std.ArrayList(u8).fromOwnedSlice(arena_allocator, install_dir);
                defer html.deinit();
                html.appendSlice("/html/site_home.html") catch unreachable;
                const file = std.fs.cwd().createFile(
                    html.items,
                    .{ .read = true, .truncate = false },
                ) catch unreachable;
                defer file.close();

                const contents = file.readToEndAlloc(arena_allocator, 200 * 1000) catch unreachable;
                r.sendBody(contents) catch return;
            }
            break :blk;
        },
        zap.Method.POST => blk: {
            break :blk;
        },
        zap.Method.DELETE => blk: {
            break :blk;
        },
        else => blk: {
            std.debug.print("Method: {any}", .{r.methodAsEnum()});
            break :blk;
        },
    }
}

pub fn main() !void {
    defer {
        const check = base.deinit();
        switch (check) {
            std.heap.Check.leak => blk: {
                std.debug.print("There are leaks present.", .{});
                _ = base.detectLeaks();
                break :blk;
            },
            std.heap.Check.ok => blk: {
                break :blk;
            },
        }
    }

    { // setup db
        db = try sqlite.Db.init(.{
            .mode = sqlite.Db.Mode{ .File = "/home/jud/code/judsite/db/data.db" },
            .open_flags = .{
                .write = true,
                .create = true,
            },
            .threading_mode = .MultiThread,
        });

        try db.exec(
            "CREATE TABLE IF NOT EXISTS submission_data(showname text UNIQUE, user text)",
            .{},
            .{},
        );
    }

    { // enter request handler hot loop
        var listener = zap.HttpListener.init(.{
            .port = 3000,
            .on_request = on_request,
            .log = false,
        });
        try listener.listen();

        std.debug.print("Listening on 0.0.0.0:3000\n", .{});

        // start worker threads
        zap.start(.{
            .threads = 2,
            .workers = 1,
        });
    }
}
