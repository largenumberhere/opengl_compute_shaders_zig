const gl = @import("opengl.zig");
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));
const std = @import("std");

const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;

fn ass(result: c_int) void {
    std.debug.assert(result != 0);
}

fn makeGlfwDummyWindow() void {
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

const Uvec2 = struct {
    x: c_uint = 0,
    y: c_uint = 0,
};

fn readFile(path: []const u8, alloc: Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    const data = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    return data;
}

const Datapoints = std.ArrayList(Datapoint);

const Datapoint = f32;

const cfalse = 0;
pub fn main() !void {
    var debug_allocator = DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(debug_allocator.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    // A window of some kind is required for opengl initialization
    makeGlfwDummyWindow();
    ass(gl.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)));
    gl.glEnable(gl.GL_DEBUG_OUTPUT);
    // gl.glEnable(gl.GL_DEBUG_OUTPUT_SYNCHRONOUS);
    gl.glDebugMessageCallback(gl_message_callback, null);

    const dataCountX = 100;
    const dataCountY = 100;
    const path = "src/shader.comp";
    const workSize = Uvec2{ .x = dataCountX, .y = dataCountY };

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

    // create input/output texture
    var out_tex: c_uint = 0;
    gl.glGenTextures(1, &out_tex);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    gl.glTextureParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
    gl.glTextureParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);

    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_R32F, workSize.x, workSize.y, 0, gl.GL_RED, gl.GL_FLOAT, null);
    gl.glBindImageTexture(0, out_tex, 0, gl.GL_FALSE, 0, gl.GL_READ_WRITE, gl.GL_R32F);

    // select the shader
    gl.glUseProgram(id);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    // load values into shader
    var values = std.ArrayList(Datapoint).empty;
    for (0..dataCountX * dataCountY) |i| {
        const item = @as(Datapoint, @floatFromInt(i));
        try values.append(alloc, item);
    }
    std.debug.print("values in {any}\n", .{values.items});
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_R32F, workSize.x, workSize.y, 0, gl.GL_RED, gl.GL_FLOAT, values.items.ptr);

    // select the shader
    gl.glUseProgram(id);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, out_tex);

    // begin the shader
    gl.glDispatchCompute(workSize.x, workSize.y, 1);

    // wait for completion
    gl.glMemoryBarrier(gl.GL_ALL_BARRIER_BITS);

    var values_out = std.ArrayList(Datapoint).empty;
    try values_out.appendNTimes(alloc, 0, dataCountX * dataCountY);
    gl.glGetTexImage(gl.GL_TEXTURE_2D, 0, gl.GL_RED, gl.GL_FLOAT, values_out.items.ptr);
}

// Based on a public domain solution by  @liam-middlebrook
// https://gist.github.com/liam-middlebrook/c52b069e4be2d87a6d2f?permalink_comment_id=4176537
export fn gl_message_callback(source: gl.GLenum, @"type": gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, msg: [*c]const gl.GLchar, data: ?*const anyopaque) callconv(.c) void {
    _ = id;
    _ = length;
    _ = data;

    const source_string = switch (source) {
        gl.GL_DEBUG_SOURCE_API => "Api",
        gl.GL_DEBUG_SOURCE_WINDOW_SYSTEM => "Window system",
        gl.GL_DEBUG_SOURCE_SHADER_COMPILER => "Shader compiler",
        gl.GL_DEBUG_SOURCE_THIRD_PARTY => "Third party",
        gl.GL_DEBUG_SOURCE_APPLICATION => "Application",
        gl.GL_DEBUG_SOURCE_OTHER => "Other system",
        else => "unknown",
    };

    const type_string = switch (@"type") {
        gl.GL_DEBUG_TYPE_ERROR => "Error",
        gl.GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => "Deprecated behavior",
        gl.GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => "Undefined behavior",
        gl.GL_DEBUG_TYPE_PORTABILITY => "Portability",
        gl.GL_DEBUG_TYPE_PERFORMANCE => "Performance",
        gl.GL_DEBUG_TYPE_OTHER => "Other type",
        gl.GL_DEBUG_TYPE_MARKER => "Marker",
        else => "Unknown type",
    };

    const severity_string = switch (severity) {
        gl.GL_DEBUG_SEVERITY_HIGH => "High",
        gl.GL_DEBUG_SEVERITY_MEDIUM => "Medium",
        gl.GL_DEBUG_SEVERITY_LOW => "Low",
        gl.GL_DEBUG_SEVERITY_NOTIFICATION => "Notification",

        else => "unknown",
    };
    std.debug.print("'{s}' from Opengl: '{s}' severity. In '{s}' Detail: '{s}'\n", .{ type_string, severity_string, source_string, std.mem.span(msg) });
}
