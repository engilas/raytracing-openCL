#define MAX_RECURSION_DEPTH 5

typedef struct {
	float w;
	float4 v;
} __attribute__((packed)) quaternion;

typedef struct {
	float4 center;
	float4 color;
	float radius;
	float reflect;
	int specular;
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
	int reflect_depth;

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

float4 ReflectRay(float4 r, float4 normal) {
	//return normal * (2 * dot(r, normal)) - r; // normal.Multiply(2 * r.DotProduct(normal)).Subtract(r);
	return 2*normal*dot(r, normal) - r;
}

float ComputeLighting(float4 point, float4 normal, int lightCount, __constant rt_light *lights, float4 view, int specular)
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

			if (specular <= 0) continue;

			float4 r = ReflectRay(L, normal);
			float rDotV = dot (r, view);
			if (rDotV > 0)
			{
				sum += light->intensity * pow(rDotV / (length(r) * length(view)), specular);

				//var tmp = light.Intensity * Math.Pow(rDotV / (R.Lenght() * view.Lenght()), specular);
				//i += (double)tmp;
			}
		}
	}
	return sum;
}

void ClosestIntersection(float4 o, float4 d, double tMin, double tMax, __constant rt_scene *scene, float *t, int *sphereIndex) {
	float closest = INFINITY;
	int sphere_index = -1;

	for (int i = 0; i < scene->sphere_count; i++)
	{
		float t = IntersectRaySphere(o, d, tMin, scene->spheres + i);

		if (t >= tMin && t <= tMax && t < closest)
		{
			closest = t;
			sphere_index = i;
		}
	}

	*t = closest;
	*sphereIndex = sphere_index;
}

float4 TraceRay(float4 o, float4 d, float tMin, float tMax,
	__constant rt_scene *scene)
{
	if (scene->reflect_depth == 0) return (float4)(0,0,0,0);

	float closest;
	int sphere_index;

	float4 colors[MAX_RECURSION_DEPTH];
    float reflects[MAX_RECURSION_DEPTH];

	//int recursionCount = 0;
	//float4 recent;

int j = 0;
	for (j = 0; j < scene->reflect_depth; j++)
	{
		// if (i == 1) {
		// 	//ClosestIntersection(o, d, tMin, tMax, scene, &closest, &sphere_index);
		// 	break;
		// } else {
		// 	ClosestIntersection(o, d, tMin, tMax, scene, &closest, &sphere_index);
		// }
		// if (i == 1) break;
		//ClosestIntersection(o, d, tMin, tMax, scene, &closest, &sphere_index);


		
		float closest = INFINITY;
		int sphere_index = -1;

		for (int i = 0; i < scene->sphere_count; i++)
		{
			float t = IntersectRaySphere(o, d, tMin, scene->spheres + i);

			if (t >= tMin && t <= tMax && t < closest)
			{
				closest = t;
				sphere_index = i;
			}
		}
		//if (i == 1) break;
		// *t = closest;
		// *sphereIndex = sphere_index;

		/////////////////////////////////
		
		if (sphere_index == -1)
		{
			colors[j] = scene->bg_color;
			reflects[j] = 0;
		}
		else {
//if (i == 1) break;
		__constant rt_sphere *sphere = scene->spheres+sphere_index;
		float4 p = o + (d * closest);
		float4 normal = normalize(p - sphere->center);

		//good for surfaces, bad for box, sphere
		// if (dot(normal, d) > 0)
		// {
		// 	normal = -normal;
		// }
		float4 view = -d;
		colors[j] = sphere->color * ComputeLighting(p, normal, scene->light_count, scene->lights, view, sphere->specular);
		//colors[i] = (float4)(0,0,1,0);
		reflects[j] = sphere->reflect;
		// if (sphere->reflect <= 0 || scene->reflect_depth == 1)
		// 	break;

		//if (i < scene->reflect_depth - 1) {
			//setup for next iteration
			 o = p;
			 d = ReflectRay(view, normal);
			 tMin = 0.001f;
			 tMax = INFINITY;
		//}
		//break;
		}
		
	}
	return colors[j-1];
	// if (true) {
		//for (int i = 0; i < 10; i++)
	 	//ClosestIntersection(o, d, tMin, tMax, scene, &closest, &sphere_index);
	// }
	//return colors[0];

	//  if (recursionCount <= 1)
	//  	return colors[0];

	// float4 totalColor = colors[recursionCount - 1];
	// //if (i == 1 || scene->reflect_depth == 1)
	// //	return totalColor;

	// for(int i = recursionCount - 2; i >= 0; i--)
	// {
	// 	float reflect = reflects[i];
	// 	float4 prevColor = colors[i];
	// 	totalColor = prevColor * (1 - reflect) + totalColor * reflect;
	// }

	// return totalColor;
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