#scope_file
#import "Basic";
#import "src/mesh";
MKL :: #import "src/mkl";

#scope_export

vertex_star :: (vertex: [] float, mesh: Mesh) -> (edges: [] float, faces: [] float) {
	edges := MKL.mul(mesh.A0, vertex);
	faces := MKL.mul(mesh.A1, edges);
	return (edges, faces);
}

vertex_closure :: (vertex: [] float, mesh: Mesh) -> (
	vertices: [] float, edges: [] float, faces: [] float
)
{
	star_edge, star_faces := vertex_star(vertex, mesh);
	defer {
		array_free(star_edge);
	}

	edges := MKL.mul(star_faces, mesh.A1);
	vertices := MKL.mul(edges, mesh.A0);
	
	return (vertices, edges, star_faces);
}

vertex_link :: (vertex: [] float, mesh: Mesh) -> (vertices: [] float, edges: [] float) {
	star_edges, star_faces := vertex_star(vertex, mesh);
	closure_vertices, closure_edges, closure_faces := vertex_closure(vertex, mesh);

	defer {
		array_free(star_edges);
		array_free(star_faces);
		array_free(closure_vertices);
		array_free(closure_edges);
		array_free(closure_faces);
	};

	vertices := array_copy(closure_vertices);
	edges := array_copy(closure_edges);

	for vertex if it > 0 vertices[it_index] = 0;
	for star_edges if it > 0 edges[it_index] = 0;

	return vertices, edges;
}