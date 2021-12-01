const std = @import("std");
const zCord = @import("zCord");

pub fn main() !void {
    // This is a shared global and should never be reclaimed
    try zCord.root_ca.preload(std.heap.page_allocator);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var auth_buf: [0x100]u8 = undefined;
    const auth = try std.fmt.bufPrint(&auth_buf, "Bot {s}", .{std.os.getenv("DISCORD_AUTH") orelse return error.AuthNotFound});

    const client = zCord.Client{
        .auth_token = auth,
    };

    const gateway = try client.startGateway(.{
        .allocator = &gpa.allocator,
        .intents = .{ .guild_messages = true },
    });
    defer gateway.destroy();

    while (true) {
        processEvent(gateway, try gateway.recvEvent()) catch |err| {
            std.debug.print("{}\n", .{err});
        };
    }
}

fn processEvent(gateway: *zCord.Gateway, event: zCord.Gateway.Event) !void {
    switch (event) {
        .heartbeat_ack => {},
        .dispatch => |dispatch| {
            if (!std.mem.eql(u8, dispatch.name.constSlice(), "MESSAGE_CREATE")) return;
            const paths = try zCord.json.path.match(dispatch.data, struct {
                @"channel_id": zCord.Snowflake(.channel),
                @"content": std.BoundedArray(u8, 0x1000),
            });

            if (std.mem.eql(u8, paths.content.constSlice(), "Hello")) {
                var buf: [0x100]u8 = undefined;
                const path = try std.fmt.bufPrint(&buf, "/api/v6/channels/{d}/messages", .{paths.channel_id});

                var req = try gateway.client.sendRequest(gateway.allocator, .POST, path, .{
                    .content = "World",
                });
                defer req.deinit();
            }
        },
    }
}
