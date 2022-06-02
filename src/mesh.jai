#import "String";
#import "File";
#import "Math";
#import "Random";

Vector3u32 :: struct {
	x : u32 = 0;
	y : u32 = 0;
	z : u32 = 0;
}

Mesh :: struct {
	vao : u32 = 0;
	vbo : u32 = 0;
	ebo : u32 = 0;

	vertices : [..] Vector3;
	colors   : [..] Vector3;
	faces    : [..] Vector3u32;

	Vertex :: struct {
		pos   : Vector3;
		color : Vector3;
	};
};


load_mesh :: (file: string) -> Mesh {
	data, success := read_entire_file(file);
	if !success return .{};

	mesh : Mesh;


	nvert := 0;
	nface := 0;

	found : bool;
	line : string;
	rest : string = data;
	while true {
		found, line, rest = split_from_left(rest, #char "\n");
		if !found break;

		line = trim(line, " \r\t\n");

		v : Vector3    = ---;
		f : Vector3u32 = ---;
		ft : Vector3u32 = ---;

		     if scan2(line, "v % % %", *v.x, *v.y, *v.z) nvert += 1;
		else if scan2(line, "f % % %", *f.x, *f.y, *f.z) nface += 1;
		else if scan2(line, "f %/% %/% %/%", *ft.x, *ft.y, *ft.z) array_add(*mesh.faces, f);
	}

	array_reserve(*mesh.vertices, nvert);
	array_reserve(*mesh.colors, nvert);
	array_reserve(*mesh.faces, nface);

	rest = data;
	while true {
		found, line, rest = split_from_left(rest, #char "\n");
		if !found break;

		line = trim(line, " \r\t\n");

		v : Vector3    = ---;
		f : Vector3u32 = ---;
		ft : Vector3u32 = ---;

		     if scan2(line, "v % % %", *v.x, *v.y, *v.z) array_add(*mesh.vertices, v);
		else if scan2(line, "f % % %", *f.x, *f.y, *f.z) array_add(*mesh.faces, f);
		else if scan2(line, "f %/% %/% %/%", *f.x, *ft.x, *f.y, *ft.y, *f.z, *ft.z) array_add(*mesh.faces, f);
	}

	for mesh.vertices {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.colors, c);
	}
	for * mesh.faces {
		it.x -= 1;
		it.y -= 1;
		it.z -= 1;
	}

	// OEPNGL
	buffer_vertices : [..] Mesh.Vertex;
	for 0..nvert-1 {
		v : Mesh.Vertex = ---;
		v.pos   = mesh.vertices[it];
		v.color = mesh.colors[it];
		array_add(*buffer_vertices, v);
	}

	glGenVertexArrays(1, *mesh.vao);
	glGenBuffers(1, *mesh.vbo);
	glGenBuffers(1, *mesh.ebo);

	glBindVertexArray(mesh.vao);

	glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
	glBufferData(
		GL_ARRAY_BUFFER,
		size_of(Mesh.Vertex) * buffer_vertices.count,
		buffer_vertices.data,
		GL_STATIC_DRAW
	);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
	glBufferData(
		GL_ELEMENT_ARRAY_BUFFER,
		size_of(Vector3u32) * mesh.faces.count,
		mesh.faces.data,
		GL_STATIC_DRAW
	);

	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 12);

	return mesh;
}

free_mesh :: (mesh : Mesh) {
	array_free(mesh.vertices);
	array_free(mesh.colors);
	array_free(mesh.faces);
}