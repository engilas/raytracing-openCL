### RayTracing implemented with OpenCL-OpenGL interop

Early implementation of realtime GPU raytracing. See the newer project [raytracing-opengl](https://github.com/engilas/raytracing-opengl)

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
