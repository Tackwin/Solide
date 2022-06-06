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