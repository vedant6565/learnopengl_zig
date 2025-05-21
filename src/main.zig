const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");
const zm = @import("zm");

const WindowSize = struct {
    pub const width: c_int = 800;
    pub const height: c_int = 600;
};

const vertShader =
    \\ #version 430 core
    \\ layout (location = 0) in vec3 aPos
    \\ void main () {
    \\  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0f);
    \\ }
;

const fragShader =
    \\ #version 430 core
    \\
    \\ out vec4 color;
    \\ 
    \\ void main(void)
    \\ {
    \\     color = vec4(0.0, 0.8, 1.0, 1.0);
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

    const vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertexShader);

    gl.ShaderSource(vertexShader, 1, @ptrCast(&vertShader), null);
    gl.CompileShader(vertexShader);

    var success: c_int = undefined;
    var infolog: [512]u8 = undefined;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success != 0) {
        gl.GetShaderInfoLog(vertexShader, 512, null, &infolog);
        std.debug.print("error compileing vertex shader {s}\n", .{infolog});
    }

    const fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragmentShader);

    gl.ShaderSource(fragmentShader, 1, @ptrCast(&fragShader), null);
    gl.CompileShader(fragmentShader);

    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success != 0) {
        gl.GetShaderInfoLog(fragmentShader, 512, null, &infolog);
        std.debug.print("error compileing fragment shader {s}\n", .{infolog});
    }

    const shaderProgrem = gl.CreateProgram();
    defer gl.DeleteProgram(shaderProgrem);

    gl.AttachShader(shaderProgrem, vertexShader);
    gl.AttachShader(shaderProgrem, fragmentShader);
    gl.LinkProgram(shaderProgrem);

    gl.GetProgramiv(shaderProgrem, gl.LINK_STATUS, &success);
    if (success != 0) {
        gl.GetProgramInfoLog(shaderProgrem, 512, null, &infolog);
        std.debug.print("error linking shader progrem {s}\n", .{infolog});
    }

    const vertices = [_]f32{
        0.5, 0.5, 0.0, // top right
        0.5, -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom left
        -0.5, 0.5, 0.0, // top left
    };

    const indices = [_]u8{
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
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u8) * indices.len, &indices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

    _ = glfw.setFramebufferSizeCallback(window, framebufferSizeCallback);

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.ClearColor(0.2, 0.3, 0.3, 1);

        gl.UseProgram(shaderProgrem);
        gl.BindVertexArray(VAO);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        // gl.DrawArrays(gl.TRIANGLES, 0, 3);
        gl.BindVertexArray(0);

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
