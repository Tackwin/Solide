#scope_file
#import "Basic";
#import "src/mesh";
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