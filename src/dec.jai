#scope_file
#import "Math";

#scope_export

Form :: struct {
	using vec: Vector3;
}

apply :: (f: Form, v: Vector3) -> float {
	return f.x * v.x + f.y * v.y + f.z * v.z;
}
