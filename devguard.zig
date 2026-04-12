// DevGuard Scanner in Zig
// Secure, low-level memory-safe alternative to Rust.
// Compile with: zig build-exe devguard.zig
// Requires std library.

const std = @import("std");

const Config = struct {
    timeout_secs: i32 = 30,
    search_paths: []const u8 = "/home/sustainableabundance",
};

fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !Config {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Trim BOM if present
    const trimmed = if (content.len > 0 and content[0] == 0xEF and content.len > 1 and content[1] == 0xBB and content.len > 2 and content[2] == 0xBF)
        content[3..]
    else
        content;

    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();

    var tree = try parser.parse(trimmed);
    defer tree.deinit();

    var result: Config = .{};

    if (tree.root.Object.get("timeout_secs")) |v| {
        result.timeout_secs = @intCast(v.Integer);
    }
    if (tree.root.Object.get("search_paths")) |v| {
        if (v.Array.items.len > 0) {
            result.search_paths = v.Array.items[0].String;
        }
    }

    return result;
}

fn scanPackages(allocator: std.mem.Allocator, search_path: []const u8, package_name: []const u8, version: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(search_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (std.mem.eql(u8, entry.basename, "package.json")) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ search_path, entry.path });
            defer allocator.free(full_path);

            var file = try std.fs.openFileAbsolute(full_path, .{});
            defer file.close();

            const content = try file.readToEndAlloc(allocator, 1024 * 1024);
            defer allocator.free(content);

            var parser = std.json.Parser.init(allocator, false);
            defer parser.deinit();

            var tree = try parser.parse(content);
            defer tree.deinit();

            if (tree.root.Object.get("dependencies")) |deps| {
                var it = deps.Object.iterator();
                while (it.next()) |dep| {
                    if (std.mem.eql(u8, dep.key_ptr.*, package_name)) {
                        const ver = dep.value_ptr.*.String;
                        if (std.mem.indexOf(u8, ver, version) != null) {
                            std.debug.print("Found: {s} v{s} in {s}\n", .{ package_name, ver, full_path });
                        }
                    }
                }
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config_path = "/home/sustainableabundance/.devguardrc";
    const cfg = loadConfig(allocator, config_path) catch |err| {
        std.debug.print("Warning: invalid config file, using defaults: {}\n", .{err});
        Config{};
    };

    std.debug.print("🔍 Scanning {s} for packages...\n", .{cfg.search_paths});

    try scanPackages(allocator, cfg.search_paths, "lodash", "4");

    std.debug.print("Scan complete.\n", .{});
}