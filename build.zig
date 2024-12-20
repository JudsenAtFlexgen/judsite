const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const release = b.option(bool, "minify", "Minify Tailwind output") orelse false;

    const tailwind = b.addSystemCommand(&.{"npx"});
    tailwind.has_side_effects = true;
    _ = tailwind.captureStdErr(); // silence tailwind output

    tailwind.addArg("tailwind");
    if (release) {
        tailwind.addArg("--minify");
    }
    tailwind.addArg("--input");
    tailwind.addFileArg(b.path("src/css/style.css"));
    tailwind.addArg("--output");
    const output = tailwind.addOutputFileArg("out.css");

    const install_html = b.addInstallDirectory(.{
        .source_dir = b.path("src/html/"),
        .install_dir = .{ .prefix = {} },
        .install_subdir = "bin/html",
    });

    const install_css = b.addInstallFile(output, "bin/css/out.css");
    install_css.step.dependOn(&tailwind.step);

    b.getInstallStep().dependOn(&install_css.step);
    b.getInstallStep().dependOn(&install_html.step);

    const exe = b.addExecutable(.{
        .name = "judsite",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false, // set to true to enable TLS support
    });
    exe.root_module.addImport("zap", zap.module("zap"));

    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));

    b.installArtifact(exe);
}
