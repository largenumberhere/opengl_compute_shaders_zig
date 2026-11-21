# Compute shaders in opengl 
An example of using compute shader's in the zig programming language. Specifically, opengl 4.6 with raw c bindings. Most of the code is in `src/main.zig`. Everything else is plumbing.


## Run it
There is no standard build.zig file for this one. You will need to use the compile script. This repo ships with a compiler for zig `1.15.2`. 
1. Bootstrap the build script once: `./zig build-exe compile.zig`
2. Use the generated binary`./compile` (or `start compile.exe` on windows)


# Inspired by: 
- Daniel Coady's compute shader article https://medium.com/@daniel.coady/compute-shaders-in-opengl-4-3-d1c741998c03
- liam middlebrook's debug callback example https://gist.github.com/liam-middlebrook/c52b069e4be2d87a6d2f?permalink_comment_id=4176537
- Daniel Coady's aka pondodev's example https://github.com/pondodev/opengl_compute
- Tsoding's nob https://github.com/tsoding/nob.h