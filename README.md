### RayTracing implemented with OpenCL-OpenGL interop

Early implementation of realtime GPU raytracing. See the newer project [raytracing-opengl](https://github.com/engilas/raytracing-opengl)

### Render scenario:

- OpenCL memory object is created from the OpenGL texture.
- For every frame, the OpenCL memory object is acquired, then updated with an OpenCL kernel, and finally released to provide the updated texture data back to OpenGL.
- For every frame, OpenGL renders textured Screen-Quad to display the results

Scene setup in rt.cpp file, create_scene function.

#### Controls:
Rotate camera with mouse

Movement: 
- WASD
- Space - up
- Ctrl - down
- Shift (hold) - boost

#### Requirements

* CMake (>= 3.0.2)
* OpenCL Libraries (should be located by CMake automatically if they are installed using package
  managers)
* GLFW, Both should be automatically found by CMake.
