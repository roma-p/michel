const std = @import("std");
const zgpu = @import("zgpu");
const zgui = @import("zgui");
const zglfw = @import("zglfw");

const App = @import("app.zig").App;

const window_title = "michel";
const window_width: c_int = 1280;
const window_height: c_int = 720;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Init GLFW
    zglfw.init() catch {
        std.log.err("Failed to initialize GLFW", .{});
        return;
    };
    defer zglfw.terminate();

    // Create window
    const window = zglfw.createWindow(window_width, window_height, window_title, null, null) catch {
        std.log.err("Failed to create GLFW window", .{});
        return;
    };
    defer window.destroy();

    // Init zgpu graphics context
    var gctx = try zgpu.GraphicsContext.create(allocator, .{
        .window = @ptrCast(window),
        .fn_getTime = @ptrCast(&zglfw.getTime),
        .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
        .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
    }, .{});
    defer gctx.destroy(allocator);

    // Init zgui
    zgui.init(allocator);
    defer zgui.deinit();

    zgui.io.setConfigFlags(.{ .dock_enable = true, .viewport_enable = true });

    // HiDPI: scale UI to match framebuffer/window ratio
    const fb_scale = @as(f32, @floatFromInt(window.getFramebufferSize()[0])) / @as(f32, @floatFromInt(window_width));
    zgui.getStyle().font_scale_dpi = fb_scale;
    zgui.getStyle().scaleAllSizes(fb_scale);

    zgui.backend.init(
        @ptrCast(window),
        @ptrCast(gctx.device),
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        @intFromEnum(@as(zgpu.wgpu.TextureFormat, .undef)),
    );
    defer zgui.backend.deinit();

    const texture = gctx.device.createTexture(.{
        .size = .{ .width = @intCast(window_width), .height = @intCast(window_height), .depth_or_array_layers = 1 },
        .format = .rgba32_float,
        .usage = .{ .texture_binding = true, .copy_dst = true },
    });
    defer texture.destroy();

    var app = try App.init(texture, gctx);

    // Main loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const fb_size = window.getFramebufferSize();
        zgui.backend.newFrame(
            @intCast(fb_size[0]),
            @intCast(fb_size[1]),
        );

        app.draw_ui();

        // Skip rendering if swapchain size doesn't match framebuffer (resize in progress)
        if (gctx.swapchain_descriptor.width != @as(u32, @intCast(fb_size[0])) or
            gctx.swapchain_descriptor.height != @as(u32, @intCast(fb_size[1])))
        {
            _ = gctx.present();
            continue;
        }

        // --- Render ---
        const back_buffer_view = gctx.swapchain.getCurrentTextureView();
        defer back_buffer_view.release();

        const encoder = gctx.device.createCommandEncoder(.{});
        defer encoder.release();

        const color_attachment: zgpu.wgpu.RenderPassColorAttachment = .{
            .view = back_buffer_view,
            .load_op = .clear,
            .store_op = .store,
            .clear_value = .{ .r = 0.08, .g = 0.08, .b = 0.08, .a = 1.0 },
        };

        const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{color_attachment};
        const render_pass = encoder.beginRenderPass(.{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
        });

        zgui.backend.draw(@ptrCast(render_pass));

        render_pass.end();
        render_pass.release();

        const command = encoder.finish(.{});
        defer command.release();

        gctx.device.getQueue().submit(&.{command});
        _ = gctx.present();
    }
}
