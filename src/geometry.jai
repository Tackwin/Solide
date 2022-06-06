#scope_file
#import "Basic";
#import "src/mesh";
MKL :: #import "src/mkl";

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

star :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	star : Simplicial_Complex;
	star.vertices = array_copy(S.vertices);
	star.edges    = MKL.mul(mesh.A0, star.vertices);
	for S.edges if it > 0 star.edges[it_index] = 1;
	star.faces    = MKL.mul(mesh.A1, star.edges);
	for S.faces if it > 0 star.faces[it_index] = 1;
	return star;
}

closure :: (S: Simplicial_Complex, mesh: Mesh) -> Simplicial_Complex {
	closure : Simplicial_Complex;
	closure.faces    = array_copy(S.faces);
	closure.edges    = MKL.mul(closure.faces, mesh.A1);
	for S.edges    if it > 0 closure.edges[it_index] = 1;
	closure.vertices = MKL.mul(closure.edges, mesh.A0);
	for S.vertices if it > 0 closure.vertices[it_index] = 1;
	
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

	for S.vertices  if it > 0 link.vertices[it_index] = 0;
	for star_.edges if it > 0 link.edges[it_index] = 0;

	return link;
}