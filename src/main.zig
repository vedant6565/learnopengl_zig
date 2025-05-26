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

var cameraPos = zm.f32x4(0, 0, 3, 0);
const cameraFront = zm.f32x4(0, 0, -1, 0);
const cameraUp = zm.f32x4(0, 1, 0, 0);

const firstMouse = true;
var yaw: f32 = -90.0;
var pitch: f32 = 0.0;
var lastX: f32 = 800.0 / 2.0;
var lastY: f32 = 600.0 / 2.0;
var fov: f32 = 45.0;

var deltaTime: f32 = 0;
var lastFrame: f32 = 0;

var procs: gl.ProcTable = undefined;
const rad_conversion = std.math.pi / 180.0;

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
    //     // positions      // colors        // texture coords
    //     0.5, 0.5, 0.0, 0.3333, 0.50, // top right
    //     0.5, -0.5, 0.0, 0.3333, 0.25, // bottom right
    //     -0.5, -0.5, 0.0, 0.0, 0.25, // bottom left
    //     -0.5, 0.5, 0.0, 0.0, 0.50, // top left
    // };
    //
    // const indices = [_]c_uint{
    //     // note that we start from 0!
    //     0, 1, 3, // first triangle
    //     1, 2, 3, // second triangle
    // };

    const vertices = [_]f32{
        // positions          // texture coords
        -0.5, 0.5,  -0.5, 0.25, 0.6666,
        0.5,  0.5,  -0.5, 0.50, 0.6666,
        0.5,  0.5,  0.5,  0.50, 1.0,
        0.5,  0.5,  0.5,  0.50, 1.0,
        -0.5, 0.5,  0.5,  0.25, 1.0,
        -0.5, 0.5,  -0.5, 0.25, 0.6666,

        -0.5, -0.5, 0.5,  0.0,  0.3333,
        0.5,  -0.5, 0.5,  0.25, 0.3333,
        0.5,  0.5,  0.5,  0.25, 0.6666,
        0.5,  0.5,  0.5,  0.25, 0.6666,
        -0.5, 0.5,  0.5,  0.0,  0.6666,
        -0.5, -0.5, 0.5,  0.0,  0.3333,

        -0.5, -0.5, -0.5, 0.25, 0.3333,
        0.5,  -0.5, -0.5, 0.50, 0.3333,
        0.5,  0.5,  -0.5, 0.50, 0.6666,
        0.5,  0.5,  -0.5, 0.50, 0.6666,
        -0.5, 0.5,  -0.5, 0.25, 0.6666,
        -0.5, -0.5, -0.5, 0.25, 0.3333,

        -0.5, 0.5,  0.5,  0.25, 0.3333,
        -0.5, 0.5,  -0.5, 0.25, 0.6666,
        -0.5, -0.5, -0.5, 0.0,  0.6666,
        -0.5, -0.5, -0.5, 0.0,  0.6666,
        -0.5, -0.5, 0.5,  0.0,  0.3333,
        -0.5, 0.5,  0.5,  0.25, 0.3333,

        0.5,  0.5,  0.5,  1.0,  0.3333,
        0.5,  0.5,  -0.5, 1.0,  0.6666,
        0.5,  -0.5, -0.5, 0.75, 0.6666,
        0.5,  -0.5, -0.5, 0.75, 0.6666,
        0.5,  -0.5, 0.5,  0.75, 0.3333,
        0.5,  0.5,  0.5,  1.0,  0.3333,

        -0.5, -0.5, -0.5, 0.25, 0.3333,
        0.5,  -0.5, -0.5, 0.50, 0.3333,
        0.5,  -0.5, 0.5,  0.50, 0.0,
        0.5,  -0.5, 0.5,  0.50, 0.0,
        -0.5, -0.5, 0.5,  0.25, 0.0,
        -0.5, -0.5, -0.5, 0.25, 0.3333,
    };

    const indices = [_][3]f32{
        .{ 0.0, 0.0, 0.0 }, //
        .{ 2.0, 5.0, -15.0 }, //
        .{ -1.5, -2.2, -2.5 }, //
        .{ -3.8, -2.0, -12.3 }, //
        .{ 2.4, -0.4, -3.5 }, //
        .{ -1.7, 3.0, -7.5 }, //
        .{ 1.3, -2.0, -2.5 }, //
        .{ 1.5, 2.0, -2.5 }, //
        .{ 1.5, 0.2, -1.5 }, //
        .{ -1.3, 1.0, -1.5 }, //
    };

    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;
    // var EBO: c_uint = undefined;

    gl.GenVertexArrays(1, (&VAO)[0..1]);
    defer gl.DeleteVertexArrays(1, (&VAO)[0..1]);

    gl.GenBuffers(1, (&VBO)[0..1]);
    defer gl.DeleteBuffers(1, (&VBO)[0..1]);

    // gl.GenBuffers(1, (&EBO)[0..1]);
    // defer gl.DeleteBuffers(1, (&EBO)[0..1]);

    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    // gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    // gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(c_uint) * indices.len, &indices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    // gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    // gl.EnableVertexAttribArray(1);

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);

    zstbi.init(allocator);
    defer zstbi.deinit();
    // zstbi.setFlipVerticallyOnLoad(true);

    // gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    // gl.BindVertexArray(0);
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

    var texture: c_uint = undefined;
    gl.GenTextures(1, (&texture)[0..1]);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    const image_path = try pathToContent(arena, "texture/gress.jpg");
    var image = try zstbi.Image.loadFromFile(image_path, 0);
    defer image.deinit();

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image.data));
    gl.GenerateMipmap(gl.TEXTURE_2D);

    // var texture2: c_uint = undefined;
    // gl.GenTextures(1, (&texture2)[0..1]);
    // gl.ActiveTexture(gl.TEXTURE1);
    // gl.BindTexture(gl.TEXTURE_2D, texture2);
    //
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    //
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // const image_path2 = try pathToContent(arena, "texture/awesomeface.png");
    // var image2 = try zstbi.Image.loadFromFile(image_path2, 0);
    // defer image2.deinit();
    //
    // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image2.width), @intCast(image2.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(image2.data));

    gl.Enable(gl.DEPTH_TEST);

    ourShader.use();
    ourShader.setInt("texture1", 0);
    // ourShader.setInt("texture2", 1);

    var projection: [16]f32 = undefined;
    var view: [16]f32 = undefined;
    var model: [16]f32 = undefined;

    while (!glfw.windowShouldClose(window)) {
        const currentFrame = @as(f32, @floatCast(glfw.getTime()));
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        processInput(window);

        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.DEPTH_BUFFER_BIT);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture);

        // gl.ActiveTexture(gl.TEXTURE1);
        // gl.BindTexture(gl.TEXTURE_2D, texture2);

        ourShader.use();

        gl.BindVertexArray(VAO);
        // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        const window_size = window.getSize();
        const aspect = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const prt = zm.perspectiveFovRhGl(fov * rad_conversion, aspect, 0.1, 100.0);
        zm.storeMat(&projection, prt);

        ourShader.setMat4f("projection", projection);

        const trans2 = zm.lookAtRh(cameraPos, cameraPos + cameraFront, cameraUp);
        zm.storeMat(&view, trans2);
        ourShader.setMat4f("view", view);

        for (indices, 0..) |indice, i| {
            // const angle = (((@mod(@as(f32, @floatFromInt(i + 1)), 2.0)) * 2.0) - 1.0);
            _ = (((@mod(@as(f32, @floatFromInt(i + 1)), 2.0)) * 2.0) - 1.0);
            // const rotate = zm.matFromAxisAngle(zm.f32x4(1.0, 0.3, 0.5, 1.0), @as(f32, @floatCast(glfw.getTime())) * 55.0 * angle * rad_conversion);
            const rotate = zm.rotationZ(0);
            const cube = zm.translation(indice[0], indice[1], indice[2]);
            const trans = zm.mul(rotate, cube);
            zm.storeMat(&model, trans);
            ourShader.setMat4f("model", model);
            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }

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

    const cameraSpeed = zm.f32x4s(2.5 * deltaTime);
    if (glfw.getKey(window, glfw.Key.w) == glfw.Action.press)
        cameraPos += cameraFront * cameraSpeed;
    if (glfw.getKey(window, glfw.Key.s) == glfw.Action.press)
        cameraPos -= cameraFront * cameraSpeed;
    if (glfw.getKey(window, glfw.Key.a) == glfw.Action.press)
        cameraPos -= zm.normalize4(zm.cross3(cameraFront, cameraUp)) * cameraSpeed;
    if (glfw.getKey(window, glfw.Key.d) == glfw.Action.press)
        cameraPos += zm.normalize4(zm.cross3(cameraFront, cameraUp)) * cameraSpeed;
}

pub fn pathToContent(arena: std.mem.Allocator, resource_relative_path: []const u8) ![:0]const u8 {
    const exe_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const content_path = std.fs.path.join(arena, &.{ exe_path, resource_relative_path }) catch unreachable;
    const content_path_zero: [:0]const u8 = std.mem.Allocator.dupeZ(arena, u8, content_path) catch unreachable;
    return content_path_zero;
}
