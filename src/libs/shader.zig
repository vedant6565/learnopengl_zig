const std = @import("std");
const gl = @import("gl");
const Shader = @This();

ID: c_uint,

pub fn create(arena: std.mem.Allocator, vertShader: []const u8, fragShader: []const u8) Shader {
    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;

    const vertexshader = createShader(arena, gl.VERTEX_SHADER, vertShader, "vertex");
    defer gl.DeleteShader(vertexshader);

    const fragmentShader = createShader(arena, gl.FRAGMENT_SHADER, fragShader, "fragment");
    defer gl.DeleteShader(fragmentShader);

    const shaderProgrem = gl.CreateProgram();
    // defer gl.DeleteProgram(shaderProgrem);

    gl.AttachShader(shaderProgrem, vertexshader);
    gl.AttachShader(shaderProgrem, fragmentShader);
    gl.LinkProgram(shaderProgrem);

    gl.GetProgramiv(shaderProgrem, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.GetProgramInfoLog(shaderProgrem, 512, null, &infoLog);
        std.debug.print("error linking shader progrem {s}\n", .{infoLog});
    }

    return Shader{ .ID = shaderProgrem };
}

pub fn use(self: Shader) void {
    gl.UseProgram(self.ID);
}

pub fn setBool(self: Shader, name: [*c]const u8, value: bool) void {
    gl.Uniform1i(gl.GetUniformLocation(self.ID, name), @intFromBool(value));
}

pub fn setInt(self: Shader, name: [*c]const u8, value: u32) void {
    gl.Uniform1i(gl.GetUniformLocation(self.ID, name), @as(c_int, @intCast(value)));
}

pub fn setFloat(self: Shader, name: [*c]const u8, value: f32) void {
    gl.Uniform1f(gl.GetUniformLocation(self.ID, name), value);
}

pub fn setVec3f(self: Shader, name: [*c]const u8, value: [3]f32) void {
    gl.Uniform3f(gl.GetUniformLocation(self.ID, name), value[0], value[1], value[2]);
}

pub fn setMat4f(self: Shader, name: [*c]const u8, value: [16]f32) void {
    const matLoc = gl.GetUniformLocation(self.ID, name);
    gl.UniformMatrix4fv(matLoc, 1, gl.FALSE, &value);
}

fn createShader(arena: std.mem.Allocator, shaderType: c_uint, shaderPath: []const u8, name: []const u8) c_uint {
    const shader = gl.CreateShader(shaderType);

    const vertShaderPath = std.fs.path.join(arena, &.{
        std.fs.selfExeDirPathAlloc(arena) catch unreachable,
        shaderPath,
    }) catch unreachable;

    const shaderFile = std.fs.openFileAbsolute(vertShaderPath, .{}) catch unreachable;
    const shaderCde = shaderFile.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0) catch unreachable;

    gl.ShaderSource(shader, 1, @ptrCast(&shaderCde), null);
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
