const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");
const zm = @import("zmath");
const zstbi = @import("zstbi");

const WindowSize = struct {
    pub const width: c_int = 800;
    pub const height: c_int = 600;
};

const vertShader =
    \\ #version 330 core
    \\ layout (location = 0) in vec3 aPos;
    \\ layout (location = 1) in vec3 aColor;
    \\ out vec3 ourColor;
    \\ void main() {
    \\     gl_Position = vec4(aPos, 1.0);
    \\     ourColor = aColor;
    \\ }
;

const fragShader =
    \\ #version 430 core
    \\ out vec4 FragColor;
    \\ in vec3 ourColor;
    \\ void main() {
    \\     FragColor = vec4(ourColor, 1.0);
    \\ }
;

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

    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    // const arena = arena_allocator_state.allocator();

    const vertexShader = createShader(gl.VERTEX_SHADER, vertShader, "vertex");
    defer gl.DeleteShader(vertexShader);

    const fragmentShader = createShader(gl.FRAGMENT_SHADER, fragShader, "fragment");
    defer gl.DeleteShader(fragmentShader);

    const shaderProgrem = gl.CreateProgram();
    defer gl.DeleteProgram(shaderProgrem);

    gl.AttachShader(shaderProgrem, vertexShader);
    gl.AttachShader(shaderProgrem, fragmentShader);
    gl.LinkProgram(shaderProgrem);

    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;
    gl.GetProgramiv(shaderProgrem, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.GetProgramInfoLog(shaderProgrem, 512, null, &infoLog);
        std.debug.print("error linking shader progrem {s}\n", .{infoLog});
    }

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

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

    var texture: c_uint = undefined;
    gl.GenTextures(1, (&texture)[0..1]);
    gl.BindTexture(gl.TEXTURE_2D, texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    zstbi.init(allocator);
    defer zstbi.deinit();

    // const image_path = pathToContent(arena, "texture/wall.jpg") catch unreachable;
    var image = try zstbi.Image.loadFromFile("texture/wall.jpg", 0);
    defer image.deinit();

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image.data));

    _ = glfw.setFramebufferSizeCallback(window, framebufferSizeCallback);

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.ClearColor(0.2, 0.3, 0.3, 1);

        gl.BindTexture(gl.TEXTURE_2D, texture);

        gl.UseProgram(shaderProgrem);
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

fn createShader(shaderType: c_uint, shaderString: [:0]const u8, name: [:0]const u8) c_uint {
    const shader = gl.CreateShader(shaderType);

    gl.ShaderSource(shader, 1, @ptrCast(&shaderString), null);
    gl.CompileShader(shader);

    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.GetShaderInfoLog(shader, 512, null, &infoLog);
        std.debug.print("error compileing {s} shader {s}\n", .{ name, infoLog });
    }

    return shader;
}

pub fn pathToContent(arena: std.mem.Allocator, resource_relative_path: [:0]const u8) ![4096:0]u8 {
    const exe_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const content_path = std.fs.path.join(arena, &.{ exe_path, resource_relative_path }) catch unreachable;
    var content_path_zero: [4096:0]u8 = undefined;
    if (content_path.len >= 4096) return error.NameTooLong;
    std.mem.copyForwards(u8, &content_path_zero, content_path);
    content_path_zero[content_path.len] = 0;
    return content_path_zero;
}
