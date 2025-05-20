// These are the libraries used in the examples,
// you may find the respostories from build.zig.zon
const glfw = @import("zglfw");
const gl = @import("gl");
const std = @import("std");
const shaders = @import("shaders.zig");

// this is used for more complex math calculation, but this is not used in this example,
// but I am going to keep this here so that I will remember such library exists,
// used for my future projects
const zm = @import("zm");

/// In the main function, I will only expose a series of functions such that
/// this shows us the key steps on how to setup and render in OpenGL:
pub fn main() !void {
    std.debug.print("<!--Skri-a Kaark-->", .{});

    // 1. initialize glfw
    try intializeGlfw();
    defer glfw.terminate();

    // 2. create window with glfw, or context in some other examples
    const window = try createWindow();
    defer window.destroy();

    // 3. set the glfw focus on the newly created windows so that
    // the later commands and shaders apply exclusively on this selected windows:
    // reference: https://computergraphics.stackexchange.com/questions/4562/what-does-makecontextcurrent-do-exactly
    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // 4. Manage function pointers
    try initializeProcTable();
    defer gl.makeProcTableCurrent(null);

    // 5. define the callback function when the framebuffer has a rezise
    _ = glfw.Window.setFramebufferSizeCallback(window, framebuffer_size_callback);

    // 6. loading, compiling and verifying shaders
    // variables for verifications
    var success: c_int = undefined;
    var infoLog: [512:0]u8 = undefined;

    // 6.1 vertex shader
    var vertexShader: c_uint = undefined;
    vertexShader = createAndCompileShaders(gl.VERTEX_SHADER, shaders.vertexShaderImpl);
    defer gl.DeleteShader(vertexShader);
    try verifyShader(vertexShader, &success, &infoLog);

    // 6.1 fragment shader
    var fragmentShader: c_uint = undefined;
    fragmentShader = createAndCompileShaders(gl.FRAGMENT_SHADER, shaders.fragmentShaderImpl);
    defer gl.DeleteShader(fragmentShader);
    try verifyShader(fragmentShader, &success, &infoLog);

    // 7. create a program and load all the shaders
    var shaderProgram: c_uint = undefined;
    errdefer gl.DeleteProgram(shaderProgram);

    shaderProgram = try createProgram(.{
        .vertexShader = vertexShader,
        .fragmentShader = fragmentShader,
    });

    try verifyProgram(shaderProgram, &success, &infoLog);

    // 8. define the vao, but since this code is based on the first triangle program of the opengl superbible 7
    // there is nothing in the vao
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    errdefer gl.DeleteVertexArrays(1, (&vao)[0..1]);

    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    // 9. and finally, render the image with the program and the window.
    render(window, shaderProgram);
}

/// Here is code for initialize GLFW window.
/// For the simplest set up, all you need is to call the init function,
/// with providing the OpenGL version and its profile as a hint
fn intializeGlfw() !void {
    // glfw initialization process:
    glfw.init() catch {
        std.log.err("GLFW initialization failed", .{});
        return error.GLFWInitializationFailed;
    };

    // The first two hints are referred to the OpenGL version,
    // which I have used 4.3 in the example
    glfw.windowHint(glfw.WindowHint.context_version_major, 4);
    glfw.windowHint(glfw.WindowHint.context_version_minor, 3);
    glfw.windowHint(glfw.WindowHint.opengl_profile, glfw.OpenGLProfile.opengl_core_profile);
}

// default struct for stating the window size
const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

/// with the glfw defined, we can how create a window by stating the
/// the dimension and the name of the windows.
fn createWindow() !*glfw.Window {
    return glfw.Window.create(
        WindowSize.width,
        WindowSize.height,
        "Opengl Triangle",
        null,
    ) catch {
        std.log.err("GLFW Window creation failed", .{});
        return error.GLFWindowCreationFailed;
    };
}

/// this is the variable used for storing function pointers,
/// used for initializeProcTable()
var procs: gl.ProcTable = undefined;

/// This can be tricky for the first time users because this function
/// initialize a struct for holding the OpenGL function pointers.
/// Because of the size of the initialization process,
/// it should only be done with either a global variable,
/// or on the heap memory. Otherwise, you won't able to use
/// an gl functionalities.
fn initializeProcTable() !void {
    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    gl.makeProcTableCurrent(&procs);
}

/// This is one of the most important step in the pipline because this
/// is used for building and compiling your shader program.
fn createAndCompileShaders(shaderType: comptime_int, shaderSource: [:0]const u8) c_uint {
    var shader: c_uint = undefined;
    shader = gl.CreateShader(shaderType);

    gl.ShaderSource(
        shader,
        1,
        &.{shaderSource.ptr},
        &.{@as(c_int, @intCast(shaderSource.len))},
    );
    gl.CompileShader(shader);

    return shader;
}

/// This function verify the compilation status of your shader code,
/// passing a success indicator to state whather the compilation is
/// successful. Besides, gl also has an info log to provide message
/// what has gone wrong in the process.
fn verifyShader(shader: c_uint, success: *c_int, infoLog: [:0]u8) !void {
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, success);

    if (success.* == gl.FALSE) {
        gl.GetShaderInfoLog(
            shader,
            @as(c_int, @intCast(infoLog.len)),
            null,
            infoLog.ptr,
        );
        std.log.err("{s}", .{std.mem.sliceTo(infoLog.ptr, 0)});
        return error.CompileVertexShaderFailed;
    }
}

/// with all the shaders, we can now create a program and attach all the shaders
/// and make them effective by linking them.
fn createProgram(shaderParts: anytype) !c_uint {
    const shaderProgram = gl.CreateProgram();

    if (shaderProgram == gl.FALSE) {
        return error.ProgramCreationFailed;
    }

    gl.AttachShader(shaderProgram, shaderParts.vertexShader);
    gl.AttachShader(shaderProgram, shaderParts.fragmentShader);
    gl.LinkProgram(shaderProgram);

    return shaderProgram;
}

/// similar to the verifyShader, gl also has a program-wise verification
fn verifyProgram(shaderProgram: c_uint, success: *c_int, infoLog: [:0]u8) !void {
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, success);

    if (success.* == gl.FALSE) {
        gl.GetProgramInfoLog(
            shaderProgram,
            @as(c_int, @intCast(infoLog.len)),
            null,
            infoLog.ptr,
        );
        std.log.err("{s}", .{infoLog});
        return error.LinkProgramFailed;
    }
}

/// The reason why this callback is defined is due to the callback standard
/// in setFramebufferSizeCallback: https://glfw-d.dpldocs.info/~develop/glfw3.api.glfwSetFramebufferSizeCallback.html
/// Since it is mendatory to have window as the callback parameter,
/// we have to ditch all the variable using '_' to comply the zig rules on unused variables.
fn framebuffer_size_callback(window: *glfw.Window, width: c_int, height: c_int) callconv(.c) void {
    _ = window;
    // Viewport used for mapping the screen resolution into a range between -1 and 1
    // Superbible: page 94
    gl.Viewport(0, 0, width, height);
}

/// this is the main event loop take place, filling a green background
/// with a triangle we have build from all those shaders programs.
fn render(window: *glfw.Window, program: c_uint) void {
    // here is the main event loop to stay the window alive
    // and the rendering take place in this loop
    while (!glfw.windowShouldClose(window)) {
        const green: [4]gl.float = .{ 0.0, 0.25, 0.0, 1.0 };
        gl.ClearBufferfv(gl.COLOR, 0, &green);

        gl.UseProgram(program);
        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
