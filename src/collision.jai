#scope_file
#import "Math";
#import "Basic";

#scope_export

Triangle :: struct {
	a: Vector3;
	b: Vector3;
	c: Vector3;

	#place a;
	vertices: [3]Vector3;
}

Ray :: struct {
	o: Vector3;
	d: Vector3;
}
ray :: (o: Vector3, d: Vector3) -> Ray {
	r: Ray = ---;
	r.o = o;
	r.d = d;
	return r;
}

Sphere :: struct {
	p: Vector3;
	r: float;
}

Capsule :: struct {
	a: Vector3;
	b: Vector3;
	r: float;
}

triangle_ray :: (tri: Triangle, ray: Ray) -> bool {
	t, hit := triangle_ray_t(tri, ray);
	return hit;
}
triangle_ray_t :: (tri: Triangle, ray: Ray) -> float, bool {
	EPSILON :: 0.0000001;
	vertex0 := tri.a;
	vertex1 := tri.b;
	vertex2 := tri.c;
	edge1 := vertex1 - vertex0;
	edge2 := vertex2 - vertex0;

	h := cross(ray.d, edge2);
	a := dot(edge1, h);
	if (a > -EPSILON && a < EPSILON)
		return 0, false;    // Le rayon est parallèle au triangle.

	f := 1.0/a;
	s := ray.o - vertex0;
	u := f * dot(s, h);
	if (u < 0.0 || u > 1.0)
		return 0, false;

	q := cross(s, edge1);
	v := f * dot(ray.d, q);
	if (v < 0.0 || u + v > 1.0)
		return 0, false;

	// On calcule t pour savoir ou le point d'intersection se situe sur la ligne.
	t := f * dot(edge2, q);
	return t, true;
}


sphere_ray :: (s: Sphere, r: Ray) -> bool {
	t, success := sphere_ray_t(s, r);
	return success;
}
sphere_ray_t :: (s: Sphere, r: Ray) -> float, bool {
	CO := r.o - s.p;

	a := dot(r.d, r.d);
	b := 2.0 * dot(CO, r.d);
	c := dot(CO, CO) - (s.r * s.r);

	discriminant := b * b - 4.0 * a * c;
	if discriminant < 0.0 return 0, false;

	tmin := (-b - sqrt(discriminant)) / (2.0 * a);
	tmax := (-b + sqrt(discriminant)) / (2.0 * a);

	return min(tmin, tmax), true;
}

capsule_ray :: (c: Capsule, r: Ray) -> bool {
	t, success := capsule_ray_t(c, r);
}
capsule_ray_t :: (C: Capsule, r: Ray) -> float, bool {
	// http://pastebin.com/2XrrNcxb

	// Substituting equ. (1) - (6) to equ. (I) and solving for t' gives:
	//
	// t' = (t * dot(AB, d) + dot(AB, AO)) / dot(AB, AB); (7) or
	// t' = t * m + n where 
	// m = dot(AB, d) / dot(AB, AB) and 
	// n = dot(AB, AO) / dot(AB, AB)
	//
	AB := C.b - C.a;
	AO := r.o - C.a;

	AB_dot_d := dot(AB, r.d);
	AB_dot_AO := dot(AB, AO);
	AB_dot_AB := dot(AB, AB);
	
	m := AB_dot_d / AB_dot_AB;
	n := AB_dot_AO / AB_dot_AB;

	// Substituting (7) into (II) and solving for t gives:
	//
	// dot(Q, Q)*t^2 + 2*dot(Q, R)*t + (dot(R, R) - r^2) = 0
	// where
	// Q = d - AB * m
	// R = AO - AB * n
	Q := r.d - (AB * m);
	R := AO - (AB * n);

	a := dot(Q, Q);
	b := 2.0 * dot(Q, R);
	c := dot(R, R) - (C.r * C.r);

	if a == 0.0
	{
		// Special case: AB and ray direction are parallel. If there is an intersection it will be on the end spheres...
		// NOTE: Why is that?
		// Q = d - AB * m =>
		// Q = d - AB * (|AB|*|d|*cos(AB,d) / |AB|^2) => |d| == 1.0
		// Q = d - AB * (|AB|*cos(AB,d)/|AB|^2) =>
		// Q = d - AB * cos(AB, d) / |AB| =>
		// Q = d - unit(AB) * cos(AB, d)
		//
		// |Q| == 0 means Q = (0, 0, 0) or d = unit(AB) * cos(AB,d)
		// both d and unit(AB) are unit vectors, so cos(AB, d) = 1 => AB and d are parallel.
		// 
		sphereA: Sphere;
		sphereB: Sphere;
		sphereA.p = C.a;
		sphereA.r = C.r;
		sphereB.p = C.b;
		sphereB.r = C.r;

		at, hita := sphere_ray_t(sphereA, r);
		bt, hitb := sphere_ray_t(sphereB, r);
		if !hita || !hitb return 0, false;

		return min(at, bt), true;
	}

	discriminant := b * b - 4.0 * a * c;
	if discriminant < 0.0 return 0, false;

	tmin := (-b - sqrt(discriminant)) / (2.0 * a);
	tmax := (-b + sqrt(discriminant)) / (2.0 * a);
	temp_ := tmin;
	temp_ = min(tmin, tmax);
	tmax = max(tmin, tmax);
	tmin = temp_;

	// Now check to see if K1 and K2 are inside the line segment defined by A,B
	t_k1 := tmin * m + n;
	if t_k1 < 0.0
	{
		// On sphere (A, r)...
		s: Sphere;
		s.p = C.a;
		s.r = C.r;

		t, hit := sphere_ray_t(s, r);
		return t, hit;
	}
	if t_k1 > 1.0
	{
		// On sphere (B, r)...
		s: Sphere;
		s.p = C.b;
		s.r = C.r;

		t, hit := sphere_ray_t(s, r);
		return t, hit;
	}

	t_k2 := tmax * m + n;
	if t_k2 > 1.0
	{
		s: Sphere;
		s.p = C.b;
		s.r = C.r;

		t, hit := sphere_ray_t(s, r);
		return t, hit;
	}

	return tmin, true;
}