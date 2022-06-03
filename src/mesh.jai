#import "String";
#import "File";
#import "Math";
#import "Random";
#import "Hash_Table";

Vector2u32 :: struct {
	a : u32 = 0;
	b : u32 = 0;
}
make_vector2u32 :: (a: u32, b: u32) -> Vector2u32 {
	v: Vector2u32 = ---;
	v.a = a;
	v.b = b;
	return v;
}

Vector3u32 :: struct {
	x : u32 = 0;
	y : u32 = 0;
	z : u32 = 0;
}

Mesh :: struct {
	vao : u32 = 0;
	vbo : u32 = 0;
	ebo : u32 = 0;

	nvert := 0;
	nface := 0;
	nedge := 0;

	vertices : [..] Vector3;
	faces    : [..] Vector3u32;
	edges    : [..] Vector2u32;

	vertex_colors : [..] Vector3;
	edge_colors   : [..] Vector3;
	face_colors   : [..] Vector3;

	Vertex :: struct {
		pos   : Vector3;
		color : Vector3;
	};

	cpu_buffer : [..] Vertex;
};


load_mesh :: (file: string) -> Mesh {
	data, success := read_entire_file(file);
	if !success return .{};

	mesh : Mesh;

	mesh.nvert = 0;
	mesh.nface = 0;

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

		     if scan2(line, "v % % %", *v.x, *v.y, *v.z) mesh.nvert += 1;
		else if scan2(line, "f % % %", *f.x, *f.y, *f.z) mesh.nface += 1;
		else if scan2(line, "f %/% %/% %/%", *ft.x, *ft.y, *ft.z) array_add(*mesh.faces, f);
	}
	
	edge_map : Table(u64, bool);
	init(*edge_map, mesh.nvert);
	
	defer uninit(*edge_map);

	array_reserve(*mesh.vertices, mesh.nvert);
	array_reserve(*mesh.faces, mesh.nface);

	array_reserve(*mesh.face_colors, mesh.nface);
	array_reserve(*mesh.vertex_colors, mesh.nvert);

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
		else if scan2(line, "f %/% %/% %/%", *f.x, *ft.x, *f.y, *ft.y, *f.z, *ft.z)
			array_add(*mesh.faces, f);
	}
	for * mesh.faces {
		it.x -= 1;
		it.y -= 1;
		it.z -= 1;
	}

	for mesh.faces {
		table_add(*edge_map, (cast(u64) min(it.x, it.y)) * 0xffff_ffff + max(it.x, it.y), true);
		table_add(*edge_map, (cast(u64) min(it.y, it.z)) * 0xffff_ffff + max(it.y, it.z), true);
		table_add(*edge_map, (cast(u64) min(it.z, it.x)) * 0xffff_ffff + max(it.z, it.x), true);
	}
	mesh.nedge = edge_map.count;

	array_reserve(*mesh.edges, mesh.nedge);
	array_reserve(*mesh.edge_colors, mesh.nedge);
	for edge_map
		array_add(
			*mesh.edges, make_vector2u32(xx (it_index / 0xffff_ffff), xx (it_index % 0xffff_ffff)));

	for mesh.faces {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.face_colors, c);
	}
	for mesh.vertices {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.vertex_colors, c);
	}
	for mesh.edges {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.edge_colors, c);
	}

	// OEPNGL
	glGenVertexArrays(1, *mesh.vao);
	glGenBuffers(1, *mesh.vbo);
	glGenBuffers(1, *mesh.ebo);

	update_gpu_data(*mesh);

	glBindVertexArray(mesh.vao);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 12);

	return mesh;
}
update_gpu_data :: (mesh: *Mesh) {
	mesh.cpu_buffer.count = 0;
	make_vertex :: (p : Vector3, c : Vector3) -> Mesh.Vertex {
		v : Mesh.Vertex = ---;
		v.pos = p;
		v.color = c;
		return v;
	}
	push_vertex :: (p : Vector3, c : Vector3, buffer : *[..] Mesh.Vertex) #expand {
		array_add(buffer, make_vertex(p, c));
	}

	for mesh.faces {
		push_vertex(mesh.vertices[it.x], mesh.face_colors[it_index], *mesh.cpu_buffer);
		push_vertex(mesh.vertices[it.y], mesh.face_colors[it_index], *mesh.cpu_buffer);
		push_vertex(mesh.vertices[it.z], mesh.face_colors[it_index], *mesh.cpu_buffer);
	}

	push_point :: (p : Vector3, c : Vector3, buffer : *[..] Mesh.Vertex) {
		R       : float : 0.1;
		PI      : float : 3.1415926;
		H_ANGLE : float : PI / 180 * 72;
		V_ANGLE : float : #run atan(0.5);

		vertices : [12] Mesh.Vertex;
		vertices[0] = make_vertex(p + Vector3.{0, 0, R}, c);

		hAngle1 : float = -PI / 2 - H_ANGLE / 2;
		hAngle2 : float = -PI / 2;

		for 1..5 {
			i1 := it;
			i2 := it + 5;

			z  := R * sin(V_ANGLE);
			xy := R * cos(V_ANGLE);

			v1 : Vector3 = ---;
			v1.x = xy * cos(hAngle1);
			v1.y = xy * sin(hAngle1);
			v1.z = +z;
			v2 : Vector3 = ---;
			v2.x = xy * cos(hAngle2);
			v2.y = xy * sin(hAngle2);
			v2.z = -z;

			vertices[i1] = make_vertex(v1 + p, c);
			vertices[i2] = make_vertex(v2 + p, c);

			hAngle1 += H_ANGLE;
			hAngle2 += H_ANGLE;
		}

		vertices[11] = make_vertex(p + Vector3.{0, 0, -R}, c);

		for 0..4 {
			array_add(buffer, vertices[0]);
			array_add(buffer, vertices[1 + (it + 0) % 5]);
			array_add(buffer, vertices[1 + (it + 1) % 5]);
		}
		for 0..4 {
			array_add(buffer, vertices[1 + (it + 0) % 5]);
			array_add(buffer, vertices[1 + (it + 1) % 5]);
			array_add(buffer, vertices[6 + (it + 0) % 5]);

			array_add(buffer, vertices[6 + (it + 0) % 5]);
			array_add(buffer, vertices[6 + (it + 1) % 5]);
			array_add(buffer, vertices[1 + (it + 1) % 5]);
		}
		for 0..4 {
			array_add(buffer, vertices[11]);
			array_add(buffer, vertices[6 + (it + 1) % 5]);
			array_add(buffer, vertices[6 + (it + 0) % 5]);
		}
	}
	for mesh.vertices {
		push_point(it, mesh.vertex_colors[it_index], *mesh.cpu_buffer);
	}

	push_edge:: (a : Vector3, b : Vector3, c : Vector3, buffer : *[..] Mesh.Vertex) {
		R       : float : 0.05;

		x := (b - a) / 2;
		z := Vector3.{0, 0, 1};
		y := normalize(cross(x, z), fallback = .{y = 1}) * R;
		z = normalize(cross(y, x)) * R;

		mat := make_matrix_from_columns(x, y, z, Matrix3);

		vertices : [8] Vector3;
		vertices[0] = .{ -1, -1, -1 };
		vertices[1] = .{ -1, +1, -1 };
		vertices[2] = .{ -1, +1, +1 };
		vertices[3] = .{ -1, -1, +1 };
		vertices[4] = .{ +1, -1, -1 };
		vertices[5] = .{ +1, +1, -1 };
		vertices[6] = .{ +1, +1, +1 };
		vertices[7] = .{ +1, -1, +1 };

		for * vertices { <<it = mat * <<it; }
		for * vertices { <<it += (a + b) / 2; }

		push_vertex(vertices[0 + 0], c, buffer);
		push_vertex(vertices[0 + 1], c, buffer);
		push_vertex(vertices[0 + 2], c, buffer);
		
		push_vertex(vertices[0 + 1], c, buffer);
		push_vertex(vertices[0 + 2], c, buffer);
		push_vertex(vertices[0 + 3], c, buffer);
		

		push_vertex(vertices[4 + 0], c, buffer);
		push_vertex(vertices[4 + 1], c, buffer);
		push_vertex(vertices[4 + 2], c, buffer);

		push_vertex(vertices[4 + 1], c, buffer);
		push_vertex(vertices[4 + 2], c, buffer);
		push_vertex(vertices[4 + 3], c, buffer);

		for 0..3 {
			push_vertex(vertices[0 + (0 + it) % 4], c, buffer);
			push_vertex(vertices[4 + (0 + it) % 4], c, buffer);
			push_vertex(vertices[4 + (1 + it) % 4], c, buffer);
			
			push_vertex(vertices[0 + (0 + it) % 4], c, buffer);
			push_vertex(vertices[4 + (1 + it) % 4], c, buffer);
			push_vertex(vertices[0 + (1 + it) % 4], c, buffer);
		}
	}

	for mesh.edges {
		b := *mesh.cpu_buffer;
		push_edge(mesh.vertices[it.a], mesh.vertices[it.b], mesh.edge_colors[it_index], b);
	}

	glBindVertexArray(mesh.vao);

	glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
	glBufferData(
		GL_ARRAY_BUFFER,
		size_of(Mesh.Vertex) * mesh.cpu_buffer.count,
		mesh.cpu_buffer.data,
		GL_DYNAMIC_DRAW
	);

	// glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
	// glBufferData(
	// 	GL_ELEMENT_ARRAY_BUFFER,
	// 	size_of(Vector3u32) * buffer_indices.count,
	// 	buffer_indices.data,
	// 	GL_DYNAMIC_DRAW
	// );

}

free_mesh :: (mesh : Mesh) {
	array_free(mesh.vertices);
	array_free(mesh.faces);
	array_free(mesh.edges);
	array_free(mesh.face_colors);
	array_free(mesh.edge_colors);
	array_free(mesh.vertex_colors);

	array_free(mesh.cpu_buffer);
}