typedef struct _rt_sphere {
    double4 center;
    uint4 color;
    double radius;
} __attribute__ ((aligned (128))) rt_sphere;

typedef struct _rt_scene {
    double4 camera_pos;
    uint4 bg_color;
    double canvas_width;
    double canvas_height;
    double viewport_width;
    double viewport_height;
    double viewport_dist;

    int sphere_count;
} __attribute__ ((aligned (128))) rt_scene;

double4 CanvasToViewport(double x, double y, const rt_scene* scene) 
{
    double4 result = (double4) (x * scene->viewport_width / scene->canvas_width,
				                y * scene->viewport_height / scene->canvas_height, 
                                scene->viewport_dist,
                                0);
    return result;
}

double IntersectRaySphere(double4 o, double4 d, double tMin, __constant rt_sphere* sphere)
{ 
    double t1, t2;

    double4 c = sphere->center;
	double r = sphere->radius;
	double4 oc = o - c;

	double k1 = dot(d, d);
	double k2 = 2 * dot(oc, d);
	double k3 = dot(oc, oc) - r * r;
	double discr = k2 * k2 - 4 * k1 * k3;

	if (discr < 0)
	{
		return INFINITY;
	}
    else 
    {
        t1 = (-k2 + sqrt(discr)) / (2 * k1);
		t2 = (-k2 - sqrt(discr)) / (2 * k1);
    }

    double t = INFINITY;
    if (t1 < t && t1 >= tMin)
    {
        t = t1;
    }
    if (t2 < t && t2 >= tMin)
    {
        t = t2;
    }

    return t;
}

uint4 TraceRay(double4 o, double4 d, double tMin, double tMax, __constant rt_sphere *spheres, const rt_scene *scene)
{ 
    double closest_t = INFINITY;
    int sphere_index = -1;
    
    for (int i = 0; i < scene->sphere_count; i++)
    {
        double t = IntersectRaySphere(o, d, tMin, spheres + i);

        if (t >= tMin && t <= tMax && t < closest_t)
	    {
	        closest_t = t;
            sphere_index = i;
	    }
    }

    if (sphere_index == -1)
    {
        return scene->bg_color;
    }
    else 
    {
        return spheres[sphere_index].color;
    }
}

__kernel void SAXPY (rt_scene scene, __constant rt_sphere *spheres, __write_only image2d_t output)
{
    const int xEdge = (int) round(scene.canvas_width / 2.0);
    const int yEdge = (int) round(scene.canvas_height / 2.0);
    const int x = get_global_id (0);
    const int y = get_global_id (1);
    const int xCartesian = x - xEdge;
    const int yCartesian = yEdge - y;
    
    const double4 d = CanvasToViewport(xCartesian, yCartesian, &scene);

    uint4 color = TraceRay(scene.camera_pos, d, 1, INFINITY, spheres, &scene);
    
    write_imageui (output, (int2)(x, y), (color));
}