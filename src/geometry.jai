#scope_file
#import "Basic";
#import "src/mesh";
#import "Math";
MKL :: #import "src/mkl";

#import "src/std";
#scope_export


Simplicial_Complex :: struct {
	vertices : [] float;
	edges    : [] float;
	faces    : [] float;
};

make_simplicial :: (v: [] float, e: [] float, f: [] float) -> Simplicial_Complex {
	S: Simplicial_Complex = ---;
	S.vertices = v;
	S.edges = e;
	S.faces = f;
	return S;
}

free :: (S: Simplicial_Complex) {
	array_free(S.vertices);
	array_free(S.edges);
	array_free(S.faces);
}

clear :: (S: Simplicial_Complex) {
	for * S.vertices { <<it = 0; }
	for * S.edges    { <<it = 0; }
	for * S.faces    { <<it = 0; }
}

swap :: (a: *Simplicial_Complex, b: *Simplicial_Complex) {
	Swap(*a.vertices, *b.vertices);
	Swap(*a.edges, *b.edges);
	Swap(*a.faces, *b.faces);
}

star :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	star : Simplicial_Complex;
	star.vertices = array_copy(S.vertices);
	star.edges    = MKL.mul(mesh.A0, star.vertices);
	for S.edges if it > 0 star.edges[it_index] = 1;
	star.faces    = MKL.mul(mesh.A1, star.edges);
	for S.faces if it > 0 star.faces[it_index] = 1;
	max_1(star);
	return star;
}

closure :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	closure : Simplicial_Complex;
	closure.faces    = array_copy(S.faces);
	closure.edges    = MKL.mul(closure.faces, mesh.A1);
	for S.edges    if it > 0 closure.edges[it_index] = 1;
	closure.vertices = MKL.mul(closure.edges, mesh.A0);
	for S.vertices if it > 0 closure.vertices[it_index] = 1;
	max_1(closure);
	return closure;
}

link :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	star_ := star(S, mesh);
	defer free(star_);

	closure_ := closure(star_, mesh);
	defer free(closure_);

	link : Simplicial_Complex;
	link.vertices = array_copy(closure_.vertices);
	link.edges    = array_copy(closure_.edges);
	array_resize(*link.faces, mesh.nface);
	for * link.faces { <<it = 0; }

	for S.vertices  if it > 0 link.vertices[it_index] = 0;
	for star_.edges if it > 0 link.edges[it_index] = 0;

	max_1(link);
	return link;
}

is_complex :: (S: Simplicial_Complex, mesh: Mesh) -> bool {
	// If any of the connected vertex from S.edges are not in S.vertex then S is not simplicial.
	subset_vertex := MKL.mul(S.edges, mesh.A0);
	defer array_free(subset_vertex);
	for subset_vertex if it > 0 && S.vertices[it_index] == 0 return false;
	
	// Samesies for faces and edges
	subset_edge := MKL.mul(S.faces, mesh.A1);
	defer array_free(subset_edge);
	for subset_edge if it > 0 && S.edges[it_index] == 0 return false;
	
	return true;
}

is_pure_complex :: (S: Simplicial_Complex, mesh: Mesh) -> int {
	edge_from_face := MKL.mul(S.faces, mesh.A1);
	defer array_free(edge_from_face);
	for edge_from_face if (it > 0) != (S.edges[it_index] > 0) return -1;

	vertex_from_edge := MKL.mul(S.edges, mesh.A0);
	defer array_free(vertex_from_edge);
	for vertex_from_edge if (it > 0) != (S.vertices[it_index] > 0) return -1;

	if S.faces.count > 0 return 2;
	if S.edges.count > 0 return 1;
	return 0;
}

boundary :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	assert(is_pure_complex(S, mesh) >= 0);
	boundary : Simplicial_Complex;
	
	array_resize(*boundary.faces, mesh.nface);
	for * boundary.faces { <<it = 0; };
	boundary.edges = MKL.mul(S.faces, mesh.A1);
	for * boundary.edges if <<it > 1 then <<it = 0;
	boundary.vertices = MKL.mul(boundary.edges, mesh.A0);

	max_1(boundary);
	return boundary;
}

max_1 :: (S: Simplicial_Complex) {
	for * S.vertices if <<it > 0 then <<it = 1;
	for * S.edges    if <<it > 0 then <<it = 1;
	for * S.faces    if <<it > 0 then <<it = 1;
}

angle :: (half_edge: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	curr := half_mesh.half_edges[half_edge];
	next := half_mesh.half_edges[curr.next];
	next_next := half_mesh.half_edges[next.next];
	
	a := mesh.vertices[curr.vertex];
	b := mesh.vertices[next.vertex];
	c := mesh.vertices[next_next.vertex];

	cos := dot(normalize(a - c), normalize(b - c));
	sin := length(cross(normalize(a - c), normalize(b - c)));

	return atan2(sin, cos);
}

dihedral_angle :: (half_edge: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	he := half_mesh.half_edges[half_edge];

	eij := mesh.vertices[he.vertex] - mesh.vertices[half_mesh.half_edges[he.next].vertex];
	eij = normalize(eij);

	face_a := he.face;
	face_b := half_mesh.half_edges[he.twin].face;

	na := normal(face_a, mesh);
	nb := normal(face_b, mesh);

	return atan2(dot(eij, cross(na, nb)), dot(na, nb));
}

vertex_normal_angle_weighted :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> Vector3 {
	N : Vector3 = .{0, 0, 0};

	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		phi := angle(it.out_half_edge, half_mesh, mesh);
		Nijk := normal(it.face, mesh);
		N += phi * Nijk;
	}

	return normalize(N);
}

vertex_normal_sphere_inscribed :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> Vector3 {
	N : Vector3 = .{0, 0, 0};

	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		i, j  := end_points(half_mesh.half_edges[it.out_half_edge], half_mesh, mesh);
		k, ii := end_points(half_mesh.half_edges[it.in_half_edge], half_mesh, mesh);
		assert(i == ii);

		add := cross(j - i, k - i);
		N += add / (length_squared(j - i) * length_squared(k - i));
	}

	return normalize(N);
}

vertex_normal_area_weighted :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> Vector3 {
	N : Vector3 = .{0, 0, 0};

	for iterate_adjacent_faces(vertex, *half_mesh, *mesh)
		N += normal(it.face, mesh) * area(it.face, mesh);

	return normalize(N);
}

vertex_normal_gaussian_curvature :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> Vector3 {
	N : Vector3 = .{0, 0, 0};
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		i, j := end_points(half_mesh.half_edges[it.out_half_edge], half_mesh, mesh);
		N += dihedral_angle(it.out_half_edge, half_mesh, mesh) * normalize(j - i);
	}
	return normalize(N);
}

vertex_normal_mean_curvature :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> Vector3 {
	N : Vector3 = .{0, 0, 0};
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		a := cotan(it.out_half_edge, half_mesh, mesh);
		b := cotan(half_mesh.half_edges[it.in_half_edge].twin, half_mesh, mesh);
		i, j := end_points(half_mesh.half_edges[it.out_half_edge], half_mesh, mesh);

		N += (a + b) * (j - i);
	}
	return normalize(N);
}

angle_defect :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	sum := 2 * PI;
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		sum -= angle(half_mesh.half_edges[it.out_half_edge].next, half_mesh, mesh);
	}
	return sum;
}

scalar_mean_curvature :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	sum := 0.0;// Vector3 = .{0, 0, 0};
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		i, j := end_points(half_mesh.half_edges[it.out_half_edge], half_mesh, mesh);
		k, ii := end_points(half_mesh.half_edges[it.in_half_edge], half_mesh, mesh);
		assert(i == ii);

		sum += cotan(it.out_half_edge, half_mesh, mesh) * length(j - i);
		sum += cotan(it.in\_half_edge, half_mesh, mesh) * length(k - i);
	}
	return sum / 2;
}

circumcentric_dual_area :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	sum := 0.0;
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) {
		i, j := end_points(half_mesh.half_edges[it.out_half_edge], half_mesh, mesh);
		k, ii := end_points(half_mesh.half_edges[it.in_half_edge], half_mesh, mesh);
		assert(i == ii);

		lij := length_squared(j - i);
		lik := length_squared(k - i);

		sum += lij * cotan(it.out_half_edge, half_mesh, mesh);
		sum += lik * cotan(it.in\_half_edge, half_mesh, mesh);
	}
	return sum / 8;
}

principal_curvatures :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> (k1: float, k2: float) {
	A := circumcentric_dual_area(vertex, half_mesh, mesh);
	H := scalar_mean_curvature(vertex, half_mesh, mesh) / A;
	K := angle_defect(vertex, half_mesh, mesh) / A;

	det := H*H - K;
	det = max(det, 0);

	k1 := H + sqrt(det);
	k2 := H - sqrt(det);

	return k1, k2;
}

mass :: (mesh: Mesh) -> MKL.Sparse_Matrix {
	return mesh.d0;
}

Scalar_Problem :: struct {
	A : MKL.Sparse_Matrix;
	M : MKL.Sparse_Matrix;
	sum : float;
};

scalar_problem :: (mesh: Mesh) -> Scalar_Problem {
	problem : Scalar_Problem;
	problem.A = mesh.laplace;
	problem.M = mesh.hodge_star_0;
	problem.sum = total_area(mesh);
	return problem;
}

solve :: (u: [] float, problem: Scalar_Problem) -> [] float {
	sum := 0.0;
	u_bar_vec := MKL.mul(problem.M, u);
	defer array_free(u_bar_vec);

	for * u_bar_vec { <<it /= problem.sum; };
	for u_bar_vec { sum += it; };

	for * u_bar_vec { <<it = u[it_index] - <<it; }
	b := MKL.mul(problem.M, u_bar_vec);
	defer array_free(b);

	for * b { <<it *= -1; }
	return MKL.solve(problem.A, b);
}

heat_method :: (u0: [] float, mesh: Mesh) -> [] float {
	t := 1.0;
	for mesh.edges {
		t += distance(mesh.vertices[it.a], mesh.vertices[it.b]);
	}
	t /= mesh.nedge;

	id := MKL.identity(mesh.nvert);
	// defer MKL.free(id);
	A := MKL.fmadd(t, mesh.laplace, id);
	// defer MKL.free(A);

	return MKL.solve(A, u0);
}

grad :: (x: [] float, mesh: Mesh) -> [] Vector3 {
	// res := NewArray(mesh.nface, Vector3);
	// for * res {
	// 	f := mesh.faces[it_index];

	// 	<<it = cross(mesh.vertices[f.y] - mesh.vertices[f.x], mesh.vertices[f.z] - mesh.vertices[f.x]);
	// 	<<it = normalize(<<it);
	// }

	y := MKL.mul(mesh.grad, x);
	res : [] Vector3;
	res.data = cast(*Vector3) y.data;
	res.count = y.count / 3;
	return res;
}