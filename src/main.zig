const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");
const zm = @import("zm");

const WindowSize = struct {
    pub const width: c_int = 800;
    pub const height: c_int = 600;
};

var procs: gl.ProcTable = undefined;

const vertices = [_]u8{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.WindowHint.context_version_major, 4);
    glfw.windowHint(glfw.WindowHint.context_version_minor, 3);
    glfw.windowHint(glfw.WindowHint.opengl_profile, glfw.OpenGLProfile.opengl_core_profile);
    glfw.windowHint(glfw.WindowHint.resizable, false);

    const window = try glfw.createWindow(WindowSize.width, WindowSize.height, "zig-gamedev: minimal_glfw_gl", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    // _ = glfw.setFramebufferSizeCallback(window, framebufferSizeCallback);

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        glfw.pollEvents();
        window.swapBuffers();
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: c_int, hight: c_int) callconv(.c) void {
    _ = window;
    gl.Viewport(0, 0, width, hight);
}

fn processInput(window: *glfw.Window) void {
    if (glfw.getKey(window, glfw.Key.escape) == glfw.Action.press) {
        glfw.setWindowShouldClose(window, true);
    }
}
