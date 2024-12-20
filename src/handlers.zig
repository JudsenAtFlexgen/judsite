const std = @import("std");
const zap = @import("zap");
const sqlite = @import("sqlite");

fn compareStrings(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs).compare(std.math.CompareOperator.lt);
}

fn add_entry(showname: []const u8, user: []const u8, html_response: *std.ArrayList(u8)) !void {
    const begin_row =
        \\<tr>
    ;
    const end_row =
        \\</tr>
    ;
    const begin_item =
        \\<td>
    ;
    const end_item =
        \\</td>
    ;

    _ = try html_response.appendSlice(begin_row);

    _ = try html_response.appendSlice(begin_item);
    _ = html_response.pop();
    _ = try html_response.appendSlice(" class=\"showcell\" name=\"filename\">");
    _ = try html_response.appendSlice(showname);
    _ = try html_response.appendSlice(end_item);

    _ = try html_response.appendSlice(begin_item);
    _ = try html_response.appendSlice(user);
    _ = try html_response.appendSlice(end_item);

    _ = try html_response.appendSlice(begin_item);
    _ = try html_response.appendSlice("<button hx-post=\"/play_show\" hx-vals='js:{\"filename\": event.target.closest(\"tr\").querySelector(\".showcell\").textContent}'>Play This");
    _ = try html_response.appendSlice(end_item);

    _ = try html_response.appendSlice(begin_item);
    _ = try html_response.appendSlice("<button hx-delete=\"/delete_show\" hx-target=\"closest tr\" hx-vals='js:{\"filename\": event.target.closest(\"tr\").querySelector(\".showcell\").textContent}'\">Delete This");
    _ = try html_response.appendSlice(end_item);

    _ = try html_response.appendSlice(end_row);
}

pub fn handle_get_all_lightshows(html_response: *std.ArrayList(u8), db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    const begin =
        \\ <table>
        \\     <thead>
        \\         <tr>
        \\             <th>Submitted Shows</th>
        \\             <th>By User</th>
        \\             <th>Start</th>
        \\             <th>Delete</th>
        \\         </tr>
    ;

    const end =
        \\    </thead>
        \\    <tbody></tbody>
        \\</div>
    ;

    var shows = std.ArrayList([]const u8).init(allocator);

    var iter_dir = try std.fs.cwd().openDir(
        "/home/jud/code/projects/christmas/shows",
        .{ .iterate = true },
    );

    defer {
        iter_dir.close();
    }

    var iter = iter_dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".py")) {
            try shows.append(entry.name[0 .. entry.name.len - 3]);
        }
    }

    std.mem.sort([]const u8, shows.items, {}, compareStrings);

    _ = try html_response.appendSlice(begin);

    for (shows.items) |show| {
        try db.exec("INSERT OR IGNORE INTO submission_data(showname, user) VALUES($showname{[]const u8}, $user{[]const u8})", .{}, .{ show, @as([]const u8, "???") });
        const query =
            \\SELECT user FROM submission_data WHERE showname = ?
        ;

        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const row = try stmt.one(
            struct {
                user: [128:0]u8,
            },
            .{},
            .{ .showname = show },
        );
        if (row) |r| {
            try add_entry(show, std.mem.span((&r.user).ptr), html_response);
        } else unreachable;
    }

    _ = try html_response.appendSlice(end);
}

pub fn handle_get_current_lightshow(html_response: *std.ArrayList(u8)) void {
    var read_n: usize = 0;
    var show: [1024]u8 = undefined;
    {
        const file = std.fs.cwd().createFile(
            "/tmp/current_show.txt",
            .{ .read = true, .truncate = false },
        ) catch |err| {
            std.debug.print("Error writing file: {}", .{err});
            return;
        };
        defer file.close();

        read_n = file.readAll(&show) catch |err| {
            std.debug.print("Error writing file: {}", .{err});
            return;
        };
    }

    _ = html_response.appendSlice("<p>Current Lightshow: <strong>") catch |err| {
        std.debug.print("Error generating html: {}", .{err});
        return;
    };

    _ = html_response.appendSlice(show[0..read_n]) catch |err| {
        std.debug.print("Error generating html: {}", .{err});
        return;
    };

    _ = html_response.appendSlice("</strong></p>") catch |err| {
        std.debug.print("Error generating html: {}", .{err});
        return;
    };
}

pub fn handle_delete(r: zap.Request, db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    try r.parseBody();
    r.parseQuery();

    const kvlist = try r.parametersToOwnedList(allocator, false);
    defer kvlist.deinit();

    var fileeee = std.ArrayList(u8).init(allocator);
    defer fileeee.deinit();

    try fileeee.appendSlice("/home/jud/code/projects/christmas/shows/");

    for (kvlist.items) |item| {
        if (std.mem.eql(u8, item.key.str, "filename")) {
            if (item.value) |value| {
                switch (value) {
                    zap.Request.HttpParamValueType.String => blk: {
                        try fileeee.appendSlice(item.value.?.String.str);
                        try fileeee.appendSlice(".py");
                        try std.fs.deleteFileAbsolute(fileeee.items);
                        break :blk;
                    },
                    else => {},
                }
            }
        }
    }

    // delete the entry from the db
    try db.exec("DELETE FROM submission_data WHERE showname = $showname{[]const u8};", .{}, .{@as(
        []const u8,
        fileeee.items[40 .. fileeee.items.len - 3],
    )});
}

pub fn handle_start(r: zap.Request, allocator: std.mem.Allocator) !void {
    try r.parseBody();
    r.parseQuery();

    const kvlist = try r.parametersToOwnedList(allocator, false);
    defer kvlist.deinit();

    var fileeee = std.ArrayList(u8).init(allocator);
    defer fileeee.deinit();

    try fileeee.appendSlice("/home/jud/code/projects/christmas/shows/");

    for (kvlist.items) |item| {
        if (std.mem.eql(u8, item.key.str, "filename")) {
            if (item.value) |value| {
                switch (value) {
                    zap.Request.HttpParamValueType.String => blk: {
                        try fileeee.appendSlice(item.value.?.String.str);
                        try fileeee.appendSlice(".py");
                        break :blk;
                    },
                    else => {},
                }
            }
        }
    }

    { // read file
        var file = try std.fs.cwd().createFile(
            fileeee.items,
            .{ .read = true, .truncate = false },
        );
        const contents = try file.readToEndAlloc(allocator, 1e7);
        file.close();

        // delete the file
        try std.fs.deleteFileAbsolute(fileeee.items);

        // re-add the file
        file = try std.fs.cwd().createFile(
            fileeee.items,
            .{},
        );

        try file.writeAll(contents);
    }
}

pub fn handle_upload(r: zap.Request, html_response: *std.ArrayList(u8), db: *sqlite.Db, allocator: std.mem.Allocator) !void {
    try r.parseBody();
    r.parseQuery();

    var fname = std.ArrayList(u8).init(allocator);
    defer fname.deinit();
    const kvlist = try r.parametersToOwnedList(allocator, false);
    defer kvlist.deinit();

    try fname.appendSlice("/home/jud/code/projects/christmas/shows/");

    var user = std.ArrayList(u8).init(allocator);

    for (kvlist.items) |item| {
        if (std.mem.eql(u8, item.key.str, "file")) {
            if (item.value) |value| {
                switch (value) {
                    zap.Request.HttpParamValueType.Hash_Binfile => blk: {
                        if (value.Hash_Binfile.filename) |ff| {
                            try fname.appendSlice(ff);
                            {
                                const file = try std.fs.cwd().createFile(
                                    fname.items,
                                    .{ .truncate = true },
                                );
                                defer file.close();

                                if (value.Hash_Binfile.data) |dd| {
                                    _ = try file.writeAll(dd);
                                }
                            }
                        }
                        break :blk;
                    },
                    else => {},
                }
            }
        } else if (std.mem.eql(u8, item.key.str, "username")) {
            if (item.value) |value| {
                switch (value) {
                    zap.Request.HttpParamValueType.String => blk: {
                        try user.appendSlice(value.String.str);
                        break :blk;
                    },
                    else => {
                        try user.appendSlice("???");
                    },
                }
            }
        } else {
            std.log.warn("Unexpected request params included in upload form.", .{});
        }
    }

    if (fname.items.len > 40) {
        _ = try html_response.appendSlice("<p>Whoa you participated. Very cool. You just submitted: ");
        _ = try html_response.appendSlice(fname.items[40..]);
        try db.exec("INSERT OR IGNORE INTO submission_data(showname, user) VALUES($showname{[]const u8}, $user{[]const u8})", .{}, .{
            @as(
                []const u8,
                fname.items[40 .. fname.items.len - 3], // filename without extension
            ),
            @as(
                []const u8,
                user.items, // username
            ),
        });
    } else {
        _ = try html_response.appendSlice("<p>Something strange occured");
    }
    _ = try html_response.appendSlice("... Anywho Merrrrry Christmas.</p>");
}
