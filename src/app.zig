const zgpu = @import("zgpu");
const zgui = @import("zgui");

pub const App = struct {
    viewportTexture: zgpu.wgpu.Texture,
    gctx: *zgpu.GraphicsContext,

    // Timeline
    current_frame: i32 = 1,
    frame_start: i32 = 1,
    frame_end: i32 = 100,
    playing: bool = false,

    // Layout
    frame_count: u32 = 0,

    const Self = @This();

    pub fn init(texture: zgpu.wgpu.Texture, gctx: *zgpu.GraphicsContext) !Self {
        return .{
            .viewportTexture = texture,
            .gctx = gctx,
        };
    }

    pub fn draw_ui(self: *Self) void {
        self.setupDockLayout();
        self.drawMenuBar();
        self.drawEditor();
        self.drawViewport();
        self.drawTimeline();
        self.drawConsole();
    }

    fn setupDockLayout(self: *Self) void {
        const dockspace_id = zgui.dockSpaceOverViewport(0, zgui.getMainViewport(), .{});

        // Only set up layout if the dock node hasn't been configured yet
        const node = zgui.dockBuilderGetNode(dockspace_id);
        self.frame_count += 1;
        if (node == null or self.frame_count == 1) {
            zgui.dockBuilderRemoveNode(dockspace_id);
            _ = zgui.dockBuilderAddNode(dockspace_id, .{ .auto_hide_tab_bar = true });

            const viewport = zgui.getMainViewport();
            const work_size = viewport.getWorkSize();
            const work_pos = viewport.getWorkPos();
            zgui.dockBuilderSetNodePos(dockspace_id, work_pos);
            zgui.dockBuilderSetNodeSize(dockspace_id, work_size);

            // Split left (editor) / right (viewport + console)
            var left: zgui.Ident = undefined;
            var right: zgui.Ident = undefined;
            _ = zgui.dockBuilderSplitNode(dockspace_id, .left, 0.4, &left, &right);

            // Split right into top (viewport) / bottom
            var right_top: zgui.Ident = undefined;
            var right_bottom_area: zgui.Ident = undefined;
            _ = zgui.dockBuilderSplitNode(right, .up, 0.6, &right_top, &right_bottom_area);

            // Split bottom area into timeline (thin) / console
            var timeline: zgui.Ident = undefined;
            var console: zgui.Ident = undefined;
            _ = zgui.dockBuilderSplitNode(right_bottom_area, .up, 0.1, &timeline, &console);

            zgui.dockBuilderDockWindow("Text Editor", left);
            zgui.dockBuilderDockWindow("Viewport", right_top);
            zgui.dockBuilderDockWindow("Timeline", timeline);
            zgui.dockBuilderDockWindow("Console / Curve Editor", console);

            zgui.dockBuilderFinish(dockspace_id);
        }
    }

    fn drawMenuBar(_: *Self) void {
        if (zgui.beginMainMenuBar()) {
            if (zgui.beginMenu("File", true)) {
                if (zgui.menuItem("Open", .{})) {}
                if (zgui.menuItem("Save", .{})) {}
                if (zgui.menuItem("Save As...", .{})) {}
                zgui.separator();
                if (zgui.menuItem("Quit", .{})) {}
                zgui.endMenu();
            }
            zgui.endMainMenuBar();
        }
    }

    const minimal = zgui.WindowFlags{ .no_title_bar = true };

    fn drawEditor(_: *Self) void {
        if (zgui.begin("Text Editor", .{ .flags = minimal })) {
            zgui.text("-- script goes here", .{});
        }
        zgui.end();
    }

    fn drawViewport(_: *Self) void {
        if (zgui.begin("Viewport", .{ .flags = minimal })) {
            zgui.text("viewport", .{});
        }
        zgui.end();
    }

    fn drawTimeline(self: *Self) void {
        if (zgui.begin("Timeline", .{ .flags = minimal })) {
            _ = zgui.sliderInt("Frame", .{
                .v = &self.current_frame,
                .min = self.frame_start,
                .max = self.frame_end,
            });
        }
        zgui.end();
    }

    fn drawConsole(_: *Self) void {
        if (zgui.begin("Console / Curve Editor", .{ .flags = minimal })) {
            zgui.text("console output", .{});
        }
        zgui.end();
    }
};
