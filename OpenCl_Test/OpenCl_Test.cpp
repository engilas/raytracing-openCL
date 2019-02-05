// OpenCl_Test.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include "pch.h"
#include <iostream>
#include <CL/cl.h>
#include <vector>
#include <chrono>
#include <fstream>

#define DEVICE_ID 0

typedef struct __declspec(align(128)) _rt_sphere {
    cl_double4 center;
    cl_uint4 color;
    cl_double radius;
} rt_sphere;

typedef struct __declspec(align(128)) _rt_scene {
    cl_double4 camera_pos;
    cl_uint4 bg_color;
    cl_double canvas_width;
    cl_double canvas_height;
    cl_double viewport_width;
    cl_double viewport_height;
    cl_double viewport_dist;

    cl_int sphere_count;
} rt_scene;

struct Image
{
	std::vector<char> pixel;
	int width, height;
};

std::string LoadKernel (const char* name)
{
	std::ifstream in (name);
	std::string result (
		(std::istreambuf_iterator<char> (in)),
		std::istreambuf_iterator<char> ());
	return result;
}

void CheckError (cl_int error)
{
	if (error != CL_SUCCESS) {
		std::cerr << "OpenCL call failed with error " << error << std::endl;
		std::exit (1);
	}
}

void CheckBuildError (cl_int error, cl_program program, cl_device_id device)
{
	if (error != CL_SUCCESS) {
        if (error == CL_BUILD_PROGRAM_FAILURE)
        {
            std::cerr << "OpenCL build error" << std::endl;

            size_t size;
            clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, nullptr, &size);
            std::string result;
	        result.resize (size);
            clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, size, const_cast<char*> (result.data ()), nullptr);

            std::cerr << result.c_str() << std::endl;

        }

		std::cerr << "OpenCL call failed with error " << error << std::endl;
		std::exit (1);
	}
}

rt_scene create_scene(int width, int height, cl_double4 camera_pos, cl_uint4 bg_color, int sphere_count)
{
    rt_scene result;
    memset(&result, 0, sizeof(rt_scene));
    result.camera_pos = camera_pos;
    result.canvas_height = height;
    result.canvas_width = width;
    result.viewport_dist = 1;
    result.viewport_height = 1;
    result.viewport_width = 1;
    result.bg_color = bg_color;
    result.sphere_count = sphere_count;

    return result;
}

rt_sphere create_spheres(cl_double4 center, cl_uint4 color, int radius)
{
    rt_sphere sphere;
    memset(&sphere, 0, sizeof(rt_sphere));
    sphere.center = center;
    sphere.color = color;
    sphere.radius = radius;

    return sphere;
}

std::string GetPlatformProp(cl_platform_id id, cl_platform_info prop)
{
    size_t size = 0;
	clGetPlatformInfo (id, prop, 0, nullptr, &size);

	std::string result;
	result.resize (size);
	clGetPlatformInfo (id, prop, size,
		const_cast<char*> (result.data ()), nullptr);

    return result;
}

void PrintPlatformName (cl_platform_id id)
{
	auto name = GetPlatformProp(id, CL_PLATFORM_NAME);

    std::cout << name.c_str() << std::endl;
}

std::string GetDeviceName (cl_device_id id)
{
    int* a=new int;
    delete a;

	size_t size = 0;
	clGetDeviceInfo (id, CL_DEVICE_NAME, 0, nullptr, &size);

	std::string result;
	result.resize (size);
	clGetDeviceInfo (id, CL_DEVICE_NAME, size,
		const_cast<char*> (result.data ()), nullptr);

	return result;
}

void SaveImage (const Image& img, const char* path)
{
	std::ofstream out (path, std::ios::binary);

	out << "P6\n";
	out << img.width << " " << img.height << "\n";
	out << "255\n";

    char* ptr = const_cast<char*>(img.pixel.data());
    for (int i = 0; i < img.width * img.height; i++)
    {
        out.write(ptr, 3);
        ptr += 4;
    }
}

Image RGBAtoRGB (const Image& input)
{
	Image result;
	result.width = input.width;
	result.height = input.height;

	for (std::size_t i = 0; i < input.pixel.size (); i += 4) {
		result.pixel.push_back (input.pixel [i + 0]);
		result.pixel.push_back (input.pixel [i + 1]);
		result.pixel.push_back (input.pixel [i + 2]);
	}

	return result;
}
int main()
{
    cl_uint platform_id_count = 0;
    clGetPlatformIDs(0, nullptr, &platform_id_count);

    std::cout << "Platform count: " << platform_id_count << std::endl;

    std::vector<cl_platform_id> platform_ids(platform_id_count);
    clGetPlatformIDs(platform_id_count, platform_ids.data(), nullptr);

    for (auto platform_id : platform_ids)
    {
        PrintPlatformName(platform_id);
    }

    cl_platform_id platform = platform_ids[1];

    cl_uint device_id_count = 0;
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, nullptr, &device_id_count);

    std::vector<cl_device_id> device_ids(device_id_count);
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, device_id_count, device_ids.data(), nullptr);

    for (int i = 0; i < device_ids.size(); i++)
    {
        auto device_id = device_ids[i];
        std::cout << "Device #" << i << " " << GetDeviceName(device_id).c_str() << std::endl;
    }

    cl_device_id device = device_ids[DEVICE_ID];
    std::cout << "Using device #" << DEVICE_ID << std::endl;

    const cl_context_properties context_properties [] = 
    {
        CL_CONTEXT_PLATFORM,
        reinterpret_cast<cl_context_properties> (platform),
        0, 0
    };

    cl_int error;

    cl_context context = clCreateContext(context_properties, 1, &device, nullptr, nullptr, &error);
    CheckError(error);

    const int width = 1920;
    const int height = 1080;

    static const cl_image_format format = { CL_RGBA, CL_UNSIGNED_INT8 };

    cl_image_desc img_desc;
    memset(&img_desc, 0, sizeof (cl_image_desc));
    img_desc.image_width = width;
    img_desc.image_height = height;
    img_desc.image_type = CL_MEM_OBJECT_IMAGE2D;

    cl_mem output_image_mem = clCreateImage (context, CL_MEM_WRITE_ONLY, &format,
		&img_desc,
		nullptr, &error);
	CheckError (error);

    int spheres_count = 3;
    std::vector<rt_sphere> spheres;
    spheres.push_back(create_spheres({2,0,4}, {0,255,0}, 1));
    spheres.push_back(create_spheres({-2,0,4}, {0,0,255}, 1));
    spheres.push_back(create_spheres({0,-1,3}, {255,0,0}, 1));

    const static auto scene = create_scene(width, height, {0}, {0}, spheres_count);

    cl_mem spheres_mem = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, sizeof(rt_sphere) * spheres_count, spheres.data(), &error);
    CheckError (error);

    size_t source_length[] = {0};

    auto program_source = LoadKernel("kernel.cl");
    const char* sources[] = {program_source.c_str()};

    cl_program program = clCreateProgramWithSource(context, 1, sources, source_length, &error);
    CheckError(error);

    CheckBuildError(clBuildProgram(program, 1, &device, nullptr, nullptr, nullptr), program, device);

    cl_kernel kernel = clCreateKernel(program, "SAXPY", &error);
    CheckError(error);

    cl_command_queue queue = clCreateCommandQueueWithProperties(context, device,
		nullptr, &error);
	CheckError (error);
    clSetKernelArg(kernel, 0, sizeof(rt_scene), &scene);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &spheres_mem);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), &output_image_mem);
    
    const size_t global_work_size [] = { width, height, 1 };
    std::size_t offset [3] = { 0 };

    std::vector<char> image_data (width * height * 4);
        Image output_image {image_data, width, height};

    const auto start = std::chrono::steady_clock::now( );

    int frames_count = 1000;

    for (int i = 0; i < frames_count; i++)
    {
        CheckError(clEnqueueNDRangeKernel(queue, kernel, 2, offset, global_work_size, nullptr, 0, nullptr, nullptr));

        std::size_t origin [3] = { 0 };
	    std::size_t region [3] = { width, height, 1 };
        CheckError (clEnqueueReadImage (queue, output_image_mem, CL_TRUE,
		    origin, region, 0, 0,
		    output_image.pixel.data(), 0, nullptr, nullptr));
    }

    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>( std::chrono::steady_clock::now( ) - start );
    std::cout << "Total elapsed: " << elapsed.count() << std::endl;
    std::cout << "Total frames: " << frames_count << std::endl;

    double fps = frames_count / (elapsed.count() / 1000.0);

    std::cout << "FPS: " << fps << std::endl;

    clReleaseCommandQueue(queue);
    clReleaseKernel(kernel);
    clReleaseMemObject(output_image_mem);
    clReleaseMemObject(spheres_mem);
    clReleaseProgram(program);
    clReleaseContext(context);

    SaveImage(output_image, "output.ppm");
}
