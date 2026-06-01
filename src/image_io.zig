const std = @import("std");

const tinyexr = @cImport(@cInclude("tinyexr.h"));
const stb = @cImport(@cInclude("stb_image.h"));
const zgpu = @import("zgpu");

pub const ImageError = error {
    ImageFormatNotSupported,
    ExrLoadFailed,
    ImageLoadFailed,
};


pub const ImageData = struct {
    pixels: [*]f32,
    width: u32,
    height: u32,
    channels: u32,

    pub fn deinit(self: *ImageData) void {
        std.c.free(self.pixels);
    }

    pub fn readImage(path: []const u8, allocator: std.mem.Allocator) !ImageData {
        const ext = std.fs.path.extension(path);
        const reader = getReader(ext) orelse return ImageError.ImageFormatNotSupported;
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);
        return reader(path_z);
    }

    const ReadFn = *const fn ([*:0]const u8) ImageError!ImageData;
    fn getReader(ext: []const u8) ?ReadFn {
        const map = .{
            .{ ".exr", readExr},
            .{ ".png", readStb},
            .{ ".jpg", readStb},
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, ext, entry[0])) return entry[1];
        }
        return null;
    }

    fn readStb(path: [*:0]const u8) !ImageData {
        var width: c_int  = undefined;
        var height: c_int  = undefined;
        var channels: c_int = undefined;

        const data = stb.stbi_loadf(path, &width, &height, &channels, 4) orelse
            return ImageError.ImageLoadFailed;

        return .{
            .pixels = data,
            .width = @intCast(width),
            .height = @intCast(height),
            .channels = 4,
        };
    }

    fn readExr(path: [*:0]const u8) !ImageData {
        var out_rga: [*]f32 = undefined;
        var width: c_int  = undefined;
        var height: c_int  = undefined;
        var err: [*c]const u8  = null;

        const ret = tinyexr.LoadEXR(&out_rga, &width, &height, path, &err);
        if (ret != tinyexr.TINYEXR_SUCCESS) {
            if (err) |e| tinyexr.FreeEXRErrorMessage(e);
            return ImageError.ExrLoadFailed;
        }

        return .{
            .pixels = out_rga,
            .width = @intCast(width),
            .height = @intCast(height),
            .channels = 4,
        };
    }

};

pub fn uploadImageToGpuTexture(
    gctx: *zgpu.GraphicsContext,
    texture: zgpu.wgpu.Texture,
    pixels: [*]f32,
    width: u32,
    height: u32,
) void {
    const byte_size = width * height * 4 * @sizeOf(f32);
    const pixel_bytes = @as([*]const u8, @ptrCast(pixels))[0..byte_size];
    gctx.queue.writeTexture(
        .{.texture = texture},
        pixel_bytes,
        .{
            .bytes_per_row = width * 4 * @sizeOf(f32),
            .rows_per_image = height,
        },
        .{
            .width = width,
            .height = height,
        }
    );
}
