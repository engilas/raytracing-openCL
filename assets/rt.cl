typedef struct _rt_sphere {
    float4 center;
    float4 color;
    float radius;
} __attribute__ ((aligned (128))) rt_sphere;

typedef struct _rt_scene {
    float4 camera_pos;
    float4 bg_color;
    float canvas_width;
    float canvas_height;
    float viewport_width;
    float viewport_height;
    float viewport_dist;

    int sphere_count;
} __attribute__ ((aligned (128))) rt_scene;

float4 CanvasToViewport(float x, float y, const rt_scene* scene) 
{
    float4 result = (float4) (x * scene->viewport_width / scene->canvas_width,
				                y * scene->viewport_height / scene->canvas_height, 
                                scene->viewport_dist,
                                0);
    return result;
}

float IntersectRaySphere(float4 o, float4 d, float tMin, __constant rt_sphere* sphere)
{ 
    float t1, t2;

    float4 c = sphere->center;
	float r = sphere->radius;
	float4 oc = o - c;

	float k1 = dot(d, d);
	float k2 = 2 * dot(oc, d);
	float k3 = dot(oc, oc) - r * r;
	float discr = k2 * k2 - 4 * k1 * k3;

	if (discr < 0)
	{
		return INFINITY;
	}
    else 
    {
        t1 = (-k2 + sqrt(discr)) / (2 * k1);
		t2 = (-k2 - sqrt(discr)) / (2 * k1);
    }

    float t = INFINITY;
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

float ComputeLighting(float4 point, float4 normal) 
{
    float sum = 0.0;
    float4 L = (float4) (1,2,3,4);
    
    sum += 0.2;

    for (int i = 0; i < 2; i++) 
    {
        float intensity = 0.6;
        if (i == 0) 
        {
            intensity = 0.6;
            float4 position = (float4) (2,1,0,0);
            L = position - point;
        }
        if (i == 1) {
            intensity = 0.2;
            L = (float4) (1,4,4,0);
        }

        float nDotL = dot(normal, L);
        if (nDotL > 0) {
            sum += intensity * nDotL / (length(normal) * length(L));
        }
    }
    return sum;
}


float4 TraceRay(float4 o, float4 d, float tMin, float tMax, __constant rt_sphere *spheres, const rt_scene *scene)
{ 
    float closest_t = INFINITY;
    int sphere_index = -1;
    
    for (int i = 0; i < scene->sphere_count; i++)
    {
        float t = IntersectRaySphere(o, d, tMin, spheres + i);

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

    float4 P =  o + (d * closest_t);
    float4 normal = P - spheres[sphere_index].center;
    normal = normal / length(normal);
    
    if (dot(normal, d) > 0)
    {
        normal = - normal;
    }

    return spheres[sphere_index].color * ComputeLighting(P, normal);
}

__kernel void rt (rt_scene scene, __constant rt_sphere *spheres, __write_only image2d_t output)
{
    const int xEdge = (int) round(scene.canvas_width / 2.0);
    const int yEdge = (int) round(scene.canvas_height / 2.0);
    const int x = get_global_id (0);
    const int y = get_global_id (1);
    const int xCartesian = x - xEdge;
    const int yCartesian = yEdge - y;
    
    const float4 d = CanvasToViewport(xCartesian, yCartesian, &scene);

    float4 color = TraceRay(scene.camera_pos, d, 1, INFINITY, spheres, &scene);
    
    write_imagef (output, (int2)(x, y), color);
}