const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");
const zm = @import("zmath");
const zstbi = @import("zstbi");
const c = @cImport({
    @cInclude("backends/dcimgui_impl_glfw.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});
const Shader = @import("libs/shader.zig");
const Camera = @import("libs/camera.zig");

const print = std.debug.print;

const WindowSize = struct {
    pub const width: c_int = 800;
    pub const height: c_int = 600;
};

var enableMouse = false;

var firstMouse = true;
var lastX: f32 = 800.0 / 2.0;
var lastY: f32 = 600.0 / 2.0;
var camera = Camera.create(zm.f32x4(0, 0, 20, 0));

var deltaTime: f32 = 0;
var lastFrame: f32 = 0;

var procs: gl.ProcTable = undefined;
const rad_conversion = std.math.pi / 180.0;
const chunck = [3]u32{ 16, 90, 16 };

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
    _ = glfw.setCursorPosCallback(window, mouseCallback);
    _ = glfw.setScrollCallback(window, scrollCallback);

    try glfw.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);

    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    // gl.Enable(gl.CULL_FACE);
    // gl.CullFace(gl.BACK);
    // gl.FrontFace(gl.CW);

    gl.Enable(gl.DEPTH_TEST);

    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    c.ImGui_StyleColorsDark(null);

    _ = c.cImGui_ImplGlfw_InitForOpenGL(@ptrCast(window), true);
    defer c.cImGui_ImplGlfw_Shutdown();

    _ = c.cImGui_ImplOpenGL3_InitEx("#version 430");
    defer c.cImGui_ImplOpenGL3_Shutdown();

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

        -0.5, 0.5,  0.5,  0.25, 0.6666,
        -0.5, 0.5,  -0.5, 0.50, 0.6666,
        -0.5, -0.5, -0.5, 0.50, 0.3333,
        -0.5, -0.5, -0.5, 0.50, 0.3333,
        -0.5, -0.5, 0.5,  0.25, 0.3333,
        -0.5, 0.5,  0.5,  0.25, 0.6666,

        0.5,  0.5,  0.5,  0.25, 0.6666,
        0.5,  0.5,  -0.5, 0.50, 0.6666,
        0.5,  -0.5, -0.5, 0.50, 0.3333,
        0.5,  -0.5, -0.5, 0.50, 0.3333,
        0.5,  -0.5, 0.5,  0.25, 0.3333,
        0.5,  0.5,  0.5,  0.25, 0.6666,

        -0.5, -0.5, -0.5, 0.25, 0.3333,
        0.5,  -0.5, -0.5, 0.50, 0.3333,
        0.5,  -0.5, 0.5,  0.50, 0.0,
        0.5,  -0.5, 0.5,  0.50, 0.0,
        -0.5, -0.5, 0.5,  0.25, 0.0,
        -0.5, -0.5, -0.5, 0.25, 0.3333,
    };

    var indices: [chunck[0] * chunck[1] * chunck[2]][3]f32 = undefined;

    var count: u32 = 0;
    for (0..chunck[0]) |i| {
        for (0..chunck[1]) |j| {
            for (0..chunck[2]) |k| {
                indices[count] = [3]f32{ @as(f32, @floatFromInt(i)), @as(f32, @floatFromInt(j)), @as(f32, @floatFromInt(k)) };
                count += 1;
            }
        }
    }

    // const indices = [_][3]f32{
    //     .{ 0.0, 0.0, 0.0 }, //
    //     .{ 2.0, 5.0, -15.0 }, //
    //     .{ -1.5, -2.2, -2.5 }, //
    //     .{ -3.8, -2.0, -12.3 }, //
    //     .{ 2.4, -0.4, -3.5 }, //
    //     .{ -1.7, 3.0, -7.5 }, //
    //     .{ 1.3, -2.0, -2.5 }, //
    //     .{ 1.5, 2.0, -2.5 }, //
    //     .{ 1.5, 0.2, -1.5 }, //
    //     .{ -1.3, 1.0, -1.5 }, //
    // };

    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;

    gl.GenVertexArrays(1, (&VAO)[0..1]);
    defer gl.DeleteVertexArrays(1, (&VAO)[0..1]);

    gl.GenBuffers(1, (&VBO)[0..1]);
    defer gl.DeleteBuffers(1, (&VBO)[0..1]);

    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);

    zstbi.init(allocator);
    defer zstbi.deinit();
    // zstbi.setFlipVerticallyOnLoad(true);

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

    ourShader.use();
    ourShader.setInt("texture1", 0);

    var projection: [16]f32 = undefined;
    var view: [16]f32 = undefined;
    var model: [16]f32 = undefined;

    while (!glfw.windowShouldClose(window)) {
        const currentFrame = @as(f32, @floatCast(glfw.getTime()));
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        processInput(window);

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplGlfw_NewFrame();
        c.ImGui_NewFrame();

        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.DEPTH_BUFFER_BIT);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture);

        ourShader.use();

        const window_size = window.getSize();
        const aspect = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const prt = zm.perspectiveFovRhGl(camera.zoom * rad_conversion, aspect, 0.1, 100.0);
        zm.storeMat(&projection, prt);

        ourShader.setMat4f("projection", projection);

        const trans2 = camera.getViewM();
        zm.storeMat(&view, trans2);
        ourShader.setMat4f("view", view);

        gl.BindVertexArray(VAO);
        for (indices, 0..) |indice, index| {
            // const angle = 20.0 * @as(f32, @floatFromInt(i + 1));

            _ = 20.0 * @as(f32, @floatFromInt(index + 1));
            const rotate = zm.rotationZ(0);
            const cube = zm.translation(indice[0], indice[1], indice[2]);
            const trans = zm.mul(rotate, cube);
            zm.storeMat(&model, trans);
            ourShader.setMat4f("model", model);
            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }

        _ = c.ImGui_Begin("test", c.true, 1);
        c.ImGui_Text("FPS: %f", 1.0 / deltaTime);
        c.ImGui_End();

        c.ImGui_Render();
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());

        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: c_int, hight: c_int) callconv(.c) void {
    _ = window;
    gl.Viewport(0, 0, width, hight);
}

fn scrollCallback(window: *glfw.Window, xoffsetIn: f64, yoffsetIn: f64) callconv(.c) void {
    _ = window;
    _ = xoffsetIn;

    const yoffset = @as(f32, @floatCast(yoffsetIn));
    camera.scrollCallback(yoffset);
}

fn mouseCallback(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.c) void {
    _ = window;
    const xpos = @as(f32, @floatCast(xposIn));
    const ypos = @as(f32, @floatCast(yposIn));

    if (firstMouse) {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    const xoffset = xpos - lastX;
    const yoffset = lastY - ypos;
    lastX = xpos;
    lastY = ypos;

    camera.mouseCallback(xoffset, yoffset);
}

fn processInput(window: *glfw.Window) void {
    if (glfw.getKey(window, glfw.Key.escape) == glfw.Action.press) {
        glfw.setWindowShouldClose(window, true);
    }

    if (glfw.getKey(window, glfw.Key.w) == .press)
        camera.movement(Camera.cameraMovement.FORWARD, deltaTime);
    if (glfw.getKey(window, glfw.Key.s) == .press)
        camera.movement(Camera.cameraMovement.BACKWARD, deltaTime);
    if (glfw.getKey(window, glfw.Key.a) == .press)
        camera.movement(Camera.cameraMovement.LEFT, deltaTime);
    if (glfw.getKey(window, glfw.Key.d) == .press)
        camera.movement(Camera.cameraMovement.RIGHT, deltaTime);
    if (glfw.getKey(window, glfw.Key.left_shift) == .press)
        camera.movement(Camera.cameraMovement.DOWN, deltaTime);
    if (glfw.getKey(window, glfw.Key.space) == .press)
        camera.movement(Camera.cameraMovement.UP, deltaTime);
}

pub fn pathToContent(arena: std.mem.Allocator, resource_relative_path: []const u8) ![:0]const u8 {
    const exe_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const content_path = std.fs.path.join(arena, &.{ exe_path, resource_relative_path }) catch unreachable;
    const content_path_zero: [:0]const u8 = std.mem.Allocator.dupeZ(arena, u8, content_path) catch unreachable;
    return content_path_zero;
}
