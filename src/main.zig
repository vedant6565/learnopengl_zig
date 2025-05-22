const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");
const zm = @import("zmath");
const zstbi = @import("zstbi");
const Shader = @import("libs/shader.zig");

const WindowSize = struct {
    pub const width: c_int = 800;
    pub const height: c_int = 600;
};

var procs: gl.ProcTable = undefined;

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
    _ = glfw.setFramebufferSizeCallback(window, framebufferSizeCallback);

    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena = arena_allocator_state.allocator();

    const ourShader = Shader.create(
        allocator,
        "shaders/vertex.glsl",
        "shaders/fragment.glsl",
    );
    defer gl.DeleteProgram(ourShader.ID);

    // const vertices = [_]f32{
    //     -0.5, -0.5, 0.0, 1.0, 0.0, 0.0, // bottom right
    //     0.5, -0.5, 0.0, 0.0, 1.0, 0.0, // bottom left
    //     0.0, 0.5, 0.0, 0.0, 0.0, 1.0, // top
    // };

    const vertices = [_]f32{
        // positions          // colors           // texture coords
        0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
        0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
        -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
        -0.5, 0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, // top left
    };

    const indices = [_]c_uint{
        0, 1, 3, // first
        1, 2, 3, // secend
    };

    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;
    var EBO: c_uint = undefined;

    gl.GenVertexArrays(1, (&VAO)[0..1]);
    defer gl.DeleteVertexArrays(1, (&VAO)[0..1]);

    gl.GenBuffers(1, (&VBO)[0..1]);
    defer gl.DeleteBuffers(1, (&VBO)[0..1]);

    gl.GenBuffers(1, (&EBO)[0..1]);
    defer gl.DeleteBuffers(1, (&EBO)[0..1]);

    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(c_uint) * indices.len, &indices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);

    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // var texture: c_uint = undefined;
    // gl.GenTextures(1, (&texture)[0..1]);
    // gl.ActiveTexture(gl.TEXTURE0);
    // gl.BindTexture(gl.TEXTURE_2D, texture);
    //
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    //
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    //
    zstbi.init(allocator);
    defer zstbi.deinit();
    //
    // const image_path = try pathToContent(arena, "texture/container.jpg");
    // var image = try zstbi.Image.loadFromFile(image_path, 0);
    // defer image.deinit();
    //
    // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    // gl.GenerateMipmap(gl.TEXTURE_2D);

    var texture2: c_uint = undefined;
    gl.GenTextures(1, (&texture2)[0..1]);
    gl.ActiveTexture(gl.TEXTURE1);
    gl.BindTexture(gl.TEXTURE_2D, texture2);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    const image_path2 = try pathToContent(arena, "texture/awesomeface.png");
    var image2 = try zstbi.Image.loadFromFile(image_path2, 0);
    defer image2.deinit();

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image2.width), @intCast(image2.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image2.data));

    ourShader.use();
    // ourShader.setInt("texture1", 0);
    ourShader.setInt("texture2", 1);

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.ClearColor(0.2, 0.3, 0.3, 1);

        // gl.ActiveTexture(gl.TEXTURE0);
        // gl.BindTexture(gl.TEXTURE_2D, texture);

        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, texture2);

        ourShader.use();
        gl.BindVertexArray(VAO);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        // gl.DrawArrays(gl.TRIANGLES, 0, 3);

        window.swapBuffers();
        glfw.pollEvents();
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

pub fn pathToContent(arena: std.mem.Allocator, resource_relative_path: []const u8) ![:0]const u8 {
    const exe_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const content_path = std.fs.path.join(arena, &.{ exe_path, resource_relative_path }) catch unreachable;
    const content_path_zero: [:0]const u8 = std.mem.Allocator.dupeZ(arena, u8, content_path) catch unreachable;
    return content_path_zero;
}
