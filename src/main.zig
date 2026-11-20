const gl = @import("opengl.zig");
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));
const std = @import("std");

const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;

fn ass(result: c_int) void {
    std.debug.assert(result != 0);
}

fn makeDummyWindow() void {
    _ = glfw.glfwInit();

    _ = glfw.glfwInit();

    _ = glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
    _ = glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    _ = glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const WINDOW_WIDTH = 800;
    const WINDOW_HEIGHT = 600;
    // create window object
    const window = glfw.glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "compute shader test", null, null);

    // ensure creation was successful
    if (window == null) {
        glfw.glfwTerminate();
        std.debug.print("window failed\n", .{});
        std.process.exit(1);
    } else {
        std.debug.print("window succeeded\n", .{});
    }

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwHideWindow(window);

    glfw.glViewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
}

const uvec2 = struct {
    x: c_uint = 0,
    y: c_uint = 0,
};

fn readFile(path: []const u8, alloc: Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    const data = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    return data;
}

const Texture = struct {};

const cfalse = 0;
pub fn main() !void {
    var debug_allocator = DebugAllocator(.{}).init;
    const alloc = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    makeDummyWindow();
    ass(gl.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)));

    const path = "src/shader.comp";
    const workSize = uvec2{ .x = 10, .y = 1 };

    const compute_code = try readFile(path, alloc);
    const shader_code = try alloc.allocSentinel(u8, compute_code.len, 0);
    @memcpy(shader_code[0..], compute_code[0..]);

    // compile the shader
    const shader = gl.glCreateShader(gl.GL_COMPUTE_SHADER);
    gl.glShaderSource(shader, 1, &shader_code.ptr, null);
    gl.glCompileShader(shader);

    const id = gl.glCreateProgram();
    gl.glAttachShader(id, shader);
    gl.glLinkProgram(id);

    // create input output texture
    var out_tex: c_uint = 0;
    gl.glGenTextures(1, &out_tex);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    gl.glTextureParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
    gl.glTextureParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);

    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_R32F, workSize.x, workSize.y, 0, gl.GL_RED, gl.GL_FLOAT, null);
    gl.glBindImageTexture(0, out_tex, 0, gl.GL_FALSE, 0, gl.GL_READ_WRITE, gl.GL_R32F);

    //
    // select the shader
    gl.glUseProgram(id);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    // load values into shader
    const values = [10]f32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    std.debug.print("values in {any}\n", .{values});
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_R32F, workSize.x, workSize.y, 0, gl.GL_RED, gl.GL_FLOAT, &values);

    // select the shader
    gl.glUseProgram(id);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    // begin the shader
    gl.glDispatchCompute(workSize.x, workSize.y, 1);

    // wait for completion
    gl.glMemoryBarrier(gl.GL_ALL_BARRIER_BITS);

    var values_out = std.ArrayList(f32).empty;

    try values_out.appendNTimes(alloc, 0, 10);
    gl.glGetTexImage(gl.GL_TEXTURE_2D, 0, gl.GL_RED, gl.GL_FLOAT, values_out.items.ptr);

    std.debug.print("values out {any}\n", .{values_out.items});
}
