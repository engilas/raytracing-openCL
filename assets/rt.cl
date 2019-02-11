typedef struct {
	float w;
	float4 v;
} __attribute__((packed)) quaternion;

typedef struct {
	float4 center;
	float4 color;
	float radius;
} __attribute__((packed)) rt_sphere;

typedef enum { Ambient, Point, Direct } lightType;

typedef struct {
	lightType type;
	float intensity;
	float4 position;
	float4 direction;
} __attribute__((packed)) rt_light;

typedef struct {
	float4 camera_pos;
	float4 bg_color;
	float canvas_width;
	float canvas_height;
	float viewport_width;
	float viewport_height;
	float viewport_dist;

	int sphere_count;
	int light_count;

	quaternion camera_rotation;

	rt_sphere spheres[32];
	rt_light lights[32];
} rt_scene;

quaternion multiplyQuaternion(quaternion *q1, quaternion *q2) {
	quaternion result;

	result.w =   q1->w*q2->w - q1->v.x * q2->v.x - q1->v.y * q2->v.y - q1->v.z * q2->v.z;
	result.v.x = q1->w*q2->v.x + q1->v.x * q2->w + q1->v.y * q2->v.z - q1->v.z * q2->v.y;
	result.v.y = q1->w*q2->v.y + q1->v.y * q2->w + q1->v.z * q2->v.x - q1->v.x * q2->v.z;
	result.v.z = q1->w*q2->v.z + q1->v.z * q2->w + q1->v.x * q2->v.y - q1->v.y * q2->v.x;

	return result;
}

float4 Rotate(__constant quaternion *q, float4 *v)
{
	quaternion qv;
	qv.w = 0;
	qv.v = *v;

	quaternion tmp = *q;
	quaternion mult = multiplyQuaternion(&tmp, &qv);
	quaternion inverse;
	float scale = 1 / (q->w*q->w + dot(q->v, q->v));
	inverse.w = scale * q->w;
	inverse.v = - scale * q->v;
	quaternion result = multiplyQuaternion(&mult, &inverse);

	return result.v;
}

float4 CanvasToViewport(float x, float y, __constant rt_scene* scene)
{
	float4 result = (float4) (x * scene->viewport_width / scene->canvas_width,
		y * scene->viewport_height / scene->canvas_height,
		scene->viewport_dist,
		0);



	return Rotate(&scene->camera_rotation, &result);
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

float ComputeLighting(float4 point, float4 normal, int lightCount, __constant rt_light *lights)
{
	float sum = 0;
	float4 L;

	for (int i = 0; i < lightCount; i++)
	{
		__constant rt_light *light = lights + i;
		if (light->type == Ambient) {
			sum += light->intensity;
		}
		else {
			if (light->type == Point)
				L = light->position - point;
			if (light->type == Direct)
				L = light->direction;

			float nDotL = dot(normal, L);
			if (nDotL > 0) {
				sum += light->intensity * nDotL / (length(normal) * length(L));
			}
		}
	}
	return sum;
}


float4 TraceRay(float4 o, float4 d, float tMin, float tMax,
	__constant rt_scene *scene)
{
	float closest_t = INFINITY;
	int sphere_index = -1;

	for (int i = 0; i < scene->sphere_count; i++)
	{
		float t = IntersectRaySphere(o, d, tMin, scene->spheres + i);

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

	float4 P = o + (d * closest_t);
	float4 normal = P - scene->spheres[sphere_index].center;
	normal = normal / length(normal);

	if (dot(normal, d) > 0)
	{
		normal = -normal;
	}

	return scene->spheres[sphere_index].color * ComputeLighting(P, normal, scene->light_count, scene->lights);
}

__kernel void rt(
	__constant rt_scene *scene,
	__write_only image2d_t output)
{
	const int xEdge = (int)round(scene->canvas_width / 2.0);
	const int yEdge = (int)round(scene->canvas_height / 2.0);
	const int x = get_global_id(0);
	const int y = get_global_id(1);
	const int xCartesian = x - xEdge;
	const int yCartesian = yEdge - y;

	const float4 d = CanvasToViewport(xCartesian, yCartesian, scene);

	float4 color = TraceRay(scene->camera_pos, d, 1, INFINITY, scene);

	write_imagef(output, (int2)(x, y), color);
}