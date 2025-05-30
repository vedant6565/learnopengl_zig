const std = @import("std");
const zm = @import("zmath");

const Camera = @This();

pub const cameraMovement = enum { FORWARD, BACKWARD, LEFT, RIGHT, UP, DOWN };
const speed: f32 = 25.0;
const sensitivity: f32 = 0.1;

position: zm.F32x4 = zm.f32x4(0, 0, 3, 0),
front: zm.F32x4 = zm.f32x4(0, 0, -1, 0),
up: zm.F32x4 = zm.f32x4(0, 1, 0, 0),
right: zm.F32x4 = undefined,
worldUp: zm.F32x4 = undefined,

yaw: f32 = -90.0,
pitch: f32 = 0.0,
zoom: f32 = 45.0,

const rad_conversion = std.math.pi / 180.0;

pub fn create(pos: zm.F32x4) Camera {
    const _front = zm.loadArr3(.{ 0.0, 0.0, -1.0 });
    const _world_up = zm.loadArr3(.{ 0.0, 1.0, 0.0 });
    const _right = zm.normalize3(zm.cross3(_front, _world_up));
    return Camera{ .position = pos, .right = _right, .worldUp = _world_up };
}

pub fn getViewM(self: *Camera) zm.Mat {
    return zm.lookAtRh(self.position, self.position + self.front, self.up);
}

pub fn scrollCallback(self: *Camera, offset: f32) void {
    self.zoom -= offset;
    if (self.zoom < 1.0)
        self.zoom = 1.0;
    if (self.zoom > 45.0)
        self.zoom = 45.0;
}

pub fn mouseCallback(self: *Camera, xoffset: f32, yoffset: f32) void {
    self.yaw += (xoffset * sensitivity);
    self.pitch += (yoffset * sensitivity);

    if (self.pitch > 89.0) {
        self.pitch = 89.0;
    }
    if (self.pitch < -89.0) {
        self.pitch = -89.0;
    }

    var front: zm.Vec = undefined;
    front[0] = @cos(self.yaw * rad_conversion) * @cos(self.pitch * rad_conversion);
    front[1] = @sin(self.pitch * rad_conversion);
    front[2] = @sin(self.yaw * rad_conversion) * @cos(self.pitch * rad_conversion);

    self.front = zm.normalize4(front);
    self.right = zm.normalize3(zm.cross3(self.front, self.worldUp));
    // self.up = zm.normalize3(zm.cross3(self.right, self.front));
}

pub fn movement(self: *Camera, dir: cameraMovement, daltaTime: f32) void {
    const cameraSpeed = zm.f32x4s(speed * daltaTime);
    switch (dir) {
        .FORWARD => self.position += self.front * cameraSpeed,
        .BACKWARD => self.position -= self.front * cameraSpeed,
        .LEFT => self.position -= self.right * cameraSpeed,
        .RIGHT => self.position += self.right * cameraSpeed,
        .UP => self.position += self.up * cameraSpeed,
        .DOWN => self.position -= self.up * cameraSpeed,
    }
}
