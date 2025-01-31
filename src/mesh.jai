#scope_file
#import "Basic";
#import "String";
#import "File";
#import "GL";
#import "Math";
#import "Random";
#import "Hash_Table";
MKL :: #import "src/mkl";
#import "src/std";
#scope_export
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
	#place x;
	comp : [3] u32 = ---;
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

	vertex_visible : [..] bool;
	edge_visible   : [..] bool;
	face_visible   : [..] bool;

	pair_vertex_edge_map : Table(u64, u32);

	A0 : MKL.Sparse_Matrix;
	A1 : MKL.Sparse_Matrix;

	hodge_star_0: MKL.Sparse_Matrix;
	hodge_star_1: MKL.Sparse_Matrix;
	hodge_star_2: MKL.Sparse_Matrix;

	d0 : MKL.Sparse_Matrix;
	d1 : MKL.Sparse_Matrix;

	grad : MKL.Sparse_Matrix;
	div  : MKL.Sparse_Matrix;

	laplace : MKL.Sparse_Matrix;
	M : MKL.Sparse_Matrix;
	Lc : MKL.Sparse_Matrix;

	Vertex :: struct {
		pos    : Vector3;
		color  : Vector3;
		normal : Vector3;
	};

	cpu_buffer : [..] Vertex;
};

Half_Edge :: struct {
	vertex := -1;
	edge := -1;
	face := -1;

	twin := -1;
	next := -1;
};

Half_Mesh :: struct {
	vertices : [] int;
	edges : [] int;
	faces : [] int;

	half_edges : [] Half_Edge;
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
		if line.count == 0 continue;

		v : Vector3    = ---;
		f : Vector3u32 = ---;
		fn : Vector3u32 = ---;
		ft : Vector3u32 = ---;

		     if scan2(line, "v % % %", *v.x, *v.y, *v.z) mesh.nvert += 1;
		else if scan2(line, "f % % %", *f.x, *f.y, *f.z) mesh.nface += 1;
		else if scan2(line, "f %/% %/% %/%", *f.x, *ft.x, *f.y, *ft.y, *f.z, *ft.z) mesh.nface += 1;
		else if scan2(line, "f %/%/% %/%/% %/%/%", *f.x, *ft.x, *fn.x, *f.y, *ft.y, *fn.y, *f.z, *ft.z, *fn.z) mesh.nface += 1;
	}
	
	init(*mesh.pair_vertex_edge_map, mesh.nvert);

	array_reserve(*mesh.vertices, mesh.nvert);
	array_reserve(*mesh.faces, mesh.nface);

	array_reserve(*mesh.face_colors, mesh.nface);
	array_reserve(*mesh.vertex_colors, mesh.nvert);

	array_reserve(*mesh.vertex_visible, mesh.nvert);
	array_reserve(*mesh.face_visible, mesh.nface);

	rest = data;
	while true {
		found, line, rest = split_from_left(rest, #char "\n");
		if !found break;

		line = trim(line, " \r\t\n");
		if line.count == 0 continue;

		v : Vector3    = ---;
		f : Vector3u32 = ---;
		ft : Vector3u32 = ---;
		fn : Vector3u32 = ---;

		     if scan2(line, "v % % %", *v.x, *v.y, *v.z) array_add(*mesh.vertices, v);
		else if scan2(line, "f % % %", *f.x, *f.y, *f.z) array_add(*mesh.faces, f);
		else if scan2(line, "f %/% %/% %/%", *f.x, *ft.x, *f.y, *ft.y, *f.z, *ft.z)
			array_add(*mesh.faces, f);
		else if scan2(line, "f %/%/% %/%/% %/%/%", *f.x, *ft.x, *fn.x, *f.y, *ft.y, *fn.y, *f.z, *ft.z, *fn.z)
			array_add(*mesh.faces, f);
	}
	for * mesh.faces {
		it.x -= 1;
		it.y -= 1;
		it.z -= 1;
	}

	for mesh.faces {
		table_set(
			*mesh.pair_vertex_edge_map,
			(cast(u64) min(it.x, it.y)) * 0xffff_ffff + max(it.x, it.y),
			0
		);
		table_set(
			*mesh.pair_vertex_edge_map,
			(cast(u64) min(it.y, it.z)) * 0xffff_ffff + max(it.y, it.z),
			0
		);
		table_set(
			*mesh.pair_vertex_edge_map,
			(cast(u64) min(it.z, it.x)) * 0xffff_ffff + max(it.z, it.x),
			0
		);
	}

	mesh.nedge = mesh.pair_vertex_edge_map.count;
	array_reserve(*mesh.edges, mesh.nedge);
	array_reserve(*mesh.edge_colors, mesh.nedge);
	array_reserve(*mesh.edge_visible, mesh.nedge);
	for * mesh.pair_vertex_edge_map {
		<<it = xx mesh.edges.count;
		array_add(
			*mesh.edges, make_vector2u32(xx (it_index / 0xffff_ffff), xx (it_index % 0xffff_ffff))
		);
	}

	for mesh.faces {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.face_colors, c);
		array_add(*mesh.face_visible, true);
	}
	for mesh.vertices {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.vertex_colors, c);
		array_add(*mesh.vertex_visible, false);
	}
	for mesh.edges {
		c := make_vector3(
			random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
		);
		array_add(*mesh.edge_colors, c);
		array_add(*mesh.edge_visible, false);
	}

	// OEPNGL
	glGenVertexArrays(1, *mesh.vao);
	glGenBuffers(1, *mesh.vbo);
	glGenBuffers(1, *mesh.ebo);

	update_gpu_data(*mesh, false, .[]);

	glBindVertexArray(mesh.vao);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 12);
	glEnableVertexAttribArray(2);
	glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Mesh.Vertex), xx 24);

	return mesh;
}

construct_half_mesh :: (mesh: Mesh) -> Half_Mesh {
	map :: (a: u32, b: u32) -> u64 { return (cast(u64) a) * 0xffff_ffff + b; };
	set_map :: (a: u32, b: u32) -> u64 { return (cast(u64) min(a, b)) * 0xffff_ffff + max(a, b); };

	
	half_mesh : Half_Mesh;
	
	array_resize(*half_mesh.vertices, mesh.nvert);
	array_resize(*half_mesh.edges, mesh.nedge);
	array_resize(*half_mesh.faces, mesh.nface);

	for * half_mesh.vertices { <<it = -1; }
	for * half_mesh.edges { <<it = -1; }
	for * half_mesh.faces { <<it = -1; }

	edge_table : Table(u64, int);
	defer uninit(*edge_table);
	pair_edge_table : Table(u64, int);
	defer uninit(*pair_edge_table);

	for mesh.edges {
		table_set(*pair_edge_table, set_map(it.a, it.b), it_index);
	}

	half_edges : [..] Half_Edge;
	array_reserve(*half_edges, mesh.nface * 3);

	for f, f_index: mesh.faces {
		half_mesh.faces[f_index] = half_edges.count;

		for i: 0..2 {
			a := f.comp[(i + 0) % 3];
			b := f.comp[(i + 1) % 3];
			

			table_set(*edge_table, map(a, b), half_edges.count);
			half_edges.count += 1;
			half_edges[half_edges.count - 1].face = f_index;

			edge_idx, found := table_find(pair_edge_table, set_map(a, b));
			assert(found);
			half_edges[half_edges.count - 1].edge = edge_idx;

			if half_mesh.vertices[a] < 0 then half_mesh.vertices[a] = half_edges.count - 1;
			half_edges[half_edges.count - 1].vertex = a;
		}


		for i: 0..2 {
			a := f.comp[(i + 0) % 3];
			b := f.comp[(i + 1) % 3];
			c := f.comp[(i + 2) % 3];

			curr, found1 := table_find(edge_table, map(a, b));
			assert(found1);

			next, found2 := table_find(edge_table, map(b, c));
			assert(found2);
			half_edges[curr].next = next;

			twin, found3 := table_find(edge_table, map(b, a));
			if found3 {
				half_edges[curr].twin = twin;
				half_edges[twin].twin = curr;
			}
		}
	}

	for mesh.edges {
		idx, found := table_find(edge_table, map(it.a, it.b));
		if (!found) idx, found = table_find(edge_table, map(it.b, it.a));
		assert(found);

		half_mesh.edges[it_index] = idx;
	}

	half_mesh.half_edges = half_edges;

	return half_mesh;
}

free :: (mesh : Mesh) {
	array_free(mesh.vertices);
	array_free(mesh.faces);
	array_free(mesh.edges);
	array_free(mesh.face_colors);
	array_free(mesh.edge_colors);
	array_free(mesh.vertex_colors);
	array_free(mesh.face_visible);
	array_free(mesh.edge_visible);
	array_free(mesh.vertex_visible);
	uninit(*mesh.pair_vertex_edge_map);

	array_free(mesh.cpu_buffer);

	MKL.free(mesh.A0);
	MKL.free(mesh.A1);
	MKL.free(mesh.hodge_star_0);
	MKL.free(mesh.hodge_star_1);
	MKL.free(mesh.hodge_star_2);
	MKL.free(mesh.d0);
	MKL.free(mesh.d1);
	MKL.free(mesh.M);
	MKL.free(mesh.Lc);
	MKL.free(mesh.laplace);
	MKL.free(mesh.grad);
	MKL.free(mesh.div);
}

free :: (half_mesh: Half_Mesh) {
	array_free(half_mesh.vertices);
	array_free(half_mesh.faces);
	array_free(half_mesh.edges);
	array_free(half_mesh.half_edges);
}

build_matrices :: (half_mesh: Half_Mesh, mesh: *Mesh) {
	mesh.A0 = build_vertex_edge_adjacency_matrix(mesh);
	mesh.A1 = build_edge_face_adjacency_matrix(mesh);
	mesh.hodge_star_0 = build_hodge_star_0(half_mesh, mesh);
	mesh.hodge_star_1 = build_hodge_star_1(half_mesh, mesh);
	mesh.hodge_star_2 = build_hodge_star_2(half_mesh, mesh);
	mesh.d0 = build_d0(mesh);
	mesh.d1 = build_d1(mesh);
	mesh.M = build_mass(half_mesh, mesh);
	mesh.Lc = build_lc(half_mesh, mesh);
	mesh.laplace = build_laplace(half_mesh, mesh);
	mesh.grad = build_grad(half_mesh, mesh);
	mesh.div = build_div(half_mesh, mesh);
}

update_gpu_data :: (
	mesh: *Mesh,
	interpolate_vertex_color: bool,
	normals: [] Vector3
) {
	mesh.cpu_buffer.count = 0;
	make_vertex :: (p : Vector3, c : Vector3, n: Vector3) -> Mesh.Vertex {
		v : Mesh.Vertex = ---;
		v.pos = p;
		v.color = c;
		v.normal = n;
		return v;
	}
	push_vertex :: (p : Vector3, c : Vector3, n: Vector3, buffer : *[..] Mesh.Vertex) #expand {
		array_add(buffer, make_vertex(p, c, n));
	}

	for mesh.faces if mesh.face_visible[it_index] {
		a := mesh.vertices[it.x];
		b := mesh.vertices[it.y];
		c := mesh.vertices[it.z];
		
		normala := normalize(cross(b - a, c - a));
		normalb := normalize(cross(b - a, c - a));
		normalc := normalize(cross(b - a, c - a));
		if (it.x < normals.count) normala = normals[it.x];
		if (it.y < normals.count) normalb = normals[it.y];
		if (it.z < normals.count) normalc = normals[it.z];

		if interpolate_vertex_color {
			push_vertex(mesh.vertices[it.x], mesh.vertex_colors[it.x], normala, *mesh.cpu_buffer);
			push_vertex(mesh.vertices[it.y], mesh.vertex_colors[it.y], normalb, *mesh.cpu_buffer);
			push_vertex(mesh.vertices[it.z], mesh.vertex_colors[it.z], normalc, *mesh.cpu_buffer);
		} else {
			push_vertex(mesh.vertices[it.x], mesh.face_colors[it_index], normala, *mesh.cpu_buffer);
			push_vertex(mesh.vertices[it.y], mesh.face_colors[it_index], normalb, *mesh.cpu_buffer);
			push_vertex(mesh.vertices[it.z], mesh.face_colors[it_index], normalc, *mesh.cpu_buffer);
		}
	}

	push_point :: (p : Vector3, c : Vector3, buffer : *[..] Mesh.Vertex) {
		R       : float : 0.02;
		PI      : float : 3.1415926;
		H_ANGLE : float : PI / 180 * 72;
		V_ANGLE : float : #run atan(0.5);

		vertices : [12] Mesh.Vertex;
		vertices[0] = make_vertex(p + Vector3.{0, 0, R}, c, .{0, 0, 1});

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

			vertices[i1] = make_vertex(v1 + p, c, normalize(v1));
			vertices[i2] = make_vertex(v2 + p, c, normalize(v2));

			hAngle1 += H_ANGLE;
			hAngle2 += H_ANGLE;
		}

		vertices[11] = make_vertex(p + Vector3.{0, 0, -R}, c, .{0, 0, -1});

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
	for mesh.vertices if mesh.vertex_visible[it_index] {
		push_point(it, mesh.vertex_colors[it_index], *mesh.cpu_buffer);
	}

	push_edge:: (a : Vector3, b : Vector3, c : Vector3, buffer : *[..] Mesh.Vertex) {
		R       : float : 0.001;

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

		push_vertex(vertices[0 + 0], c, normalize(vertices[0 + 0]), buffer);
		push_vertex(vertices[0 + 1], c, normalize(vertices[0 + 1]), buffer);
		push_vertex(vertices[0 + 2], c, normalize(vertices[0 + 2]), buffer);

		push_vertex(vertices[0 + 1], c, normalize(vertices[0 + 1]), buffer);
		push_vertex(vertices[0 + 2], c, normalize(vertices[0 + 2]), buffer);
		push_vertex(vertices[0 + 3], c, normalize(vertices[0 + 3]), buffer);


		push_vertex(vertices[4 + 0], c, normalize(vertices[4 + 0]), buffer);
		push_vertex(vertices[4 + 1], c, normalize(vertices[4 + 1]), buffer);
		push_vertex(vertices[4 + 2], c, normalize(vertices[4 + 2]), buffer);

		push_vertex(vertices[4 + 1], c, normalize(vertices[4 + 1]), buffer);
		push_vertex(vertices[4 + 2], c, normalize(vertices[4 + 2]), buffer);
		push_vertex(vertices[4 + 3], c, normalize(vertices[4 + 3]), buffer);

		for 0..3 {
			push_vertex(
				vertices[0 + (0 + it) % 4], c, normalize(vertices[0 + (0 + it) % 4]), buffer
			);
			push_vertex(
				vertices[4 + (0 + it) % 4], c, normalize(vertices[4 + (0 + it) % 4]), buffer
			);
			push_vertex(
				vertices[4 + (1 + it) % 4], c, normalize(vertices[4 + (1 + it) % 4]), buffer
			);
			push_vertex(
				vertices[0 + (0 + it) % 4], c, normalize(vertices[0 + (0 + it) % 4]), buffer
			);
			push_vertex(
				vertices[4 + (1 + it) % 4], c, normalize(vertices[4 + (1 + it) % 4]), buffer
			);
			push_vertex(
				vertices[0 + (1 + it) % 4], c, normalize(vertices[0 + (1 + it) % 4]), buffer
			);
		}
	}

	for mesh.edges if mesh.edge_visible[it_index] {
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

get_edge_index :: (mesh: Mesh, vertex_a: u32, vertex_b: u32) -> u32 {
	a := min(vertex_a, vertex_b);
	b := max(vertex_a, vertex_b);
	it, found := table_find(mesh.pair_vertex_edge_map, (cast(u64) a) * 0xffff_ffff + b);
	assert(found);
	return it;
}

build_vertex_edge_adjacency_matrix :: (mesh: Mesh) -> MKL.Sparse_Matrix {
	values : [..] float;
	col_idx : [..] s64;
	rows_start : [..] s64;
	array_resize(*values    , mesh.nedge * 2);
	array_resize(*col_idx   , mesh.nedge * 2);
	array_resize(*rows_start, mesh.nedge + 1);
	
	for * rows_start { <<it = (it_index + 0) * 2; };
	for * values     { <<it = 1; };
	for mesh.edges {
		col_idx[it_index * 2 + 0] = min(it.a, it.b);
		col_idx[it_index * 2 + 1] = max(it.a, it.b);
	}

	return MKL.create_sparse_matrix(mesh.nedge, mesh.nvert, rows_start, col_idx, values);
}

build_edge_face_adjacency_matrix :: (mesh: Mesh) -> MKL.Sparse_Matrix {
	values : [..] float;
	col_idx : [..] s64;
	rows_end : [..] s64;
	rows_start : [..] s64;
	array_resize(*values    , mesh.nface * 3);
	array_resize(*col_idx   , mesh.nface * 3);
	array_resize(*rows_start, mesh.nface + 1);

	for * rows_start { <<it = (it_index + 0) * 3; };
	for * values     { <<it = 1; }

	for mesh.faces {
		i := it_index;
		col_idx[i * 3 + 0] = get_edge_index(mesh, it.x, it.y);
		col_idx[i * 3 + 1] = get_edge_index(mesh, it.y, it.z);
		col_idx[i * 3 + 2] = get_edge_index(mesh, it.z, it.x);

		// Sort three values
		if col_idx[i * 3 + 0] > col_idx[i * 3 + 1] Swap(*col_idx[i * 3 + 0], *col_idx[i * 3 + 1]);
		if col_idx[i * 3 + 0] > col_idx[i * 3 + 2] Swap(*col_idx[i * 3 + 0], *col_idx[i * 3 + 2]);
		if col_idx[i * 3 + 1] > col_idx[i * 3 + 2] Swap(*col_idx[i * 3 + 1], *col_idx[i * 3 + 2]);
	}

	return MKL.create_sparse_matrix(mesh.nface, mesh.nedge, rows_start, col_idx, values);
}

build_vector_list :: (mesh: Mesh, vertices: ..u32) -> [..] float {
	v: [..] float;
	array_resize(*v, mesh.nvert);

	for vertices v[it] = 1;
	return v;
}

normal :: (face: int, mesh: Mesh) -> Vector3 {
	a := mesh.vertices[mesh.faces[face].x];
	b := mesh.vertices[mesh.faces[face].y];
	c := mesh.vertices[mesh.faces[face].z];

	return normalize(cross(b - a, c - a));
}

area :: (face: int, mesh: Mesh) -> float {
	i := mesh.vertices[mesh.faces[face].x];
	j := mesh.vertices[mesh.faces[face].y];
	k := mesh.vertices[mesh.faces[face].z];

	lij := length(j - i);
	ljk := length(k - j);
	lki := length(i - k);

	s := (lij + ljk + lki) / 2;
	return sqrt(s * (s - lij) * (s - ljk) * (s - lki));
}

total_area :: (mesh: Mesh) -> float {
	s := 0.0;
	for 0..mesh.nface-1 s += area(it, mesh);
	return s;
}

mean :: (face: int, mesh: Mesh) -> Vector3 {
	i := mesh.vertices[mesh.faces[face].x];
	j := mesh.vertices[mesh.faces[face].y];
	k := mesh.vertices[mesh.faces[face].z];

	return (i + j + k) / 3;
}

cotan :: (half_edge: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	curr := half_mesh.half_edges[half_edge];
	next := half_mesh.half_edges[curr.next];
	next_next := half_mesh.half_edges[next.next];
	
	a := mesh.vertices[curr.vertex];
	b := mesh.vertices[next.vertex];
	c := mesh.vertices[next_next.vertex];

	cos := dot(normalize(a - c), normalize(b - c));
	sin := length(cross(normalize(a - c), normalize(b - c)));

	return cos / sin;
}

barycentric_dual_area :: (vertex: int, half_mesh: Half_Mesh, mesh: Mesh) -> float {
	sum := 0.0;
	for iterate_adjacent_faces(vertex, *half_mesh, *mesh) sum += area(it.face, mesh);
	return sum / 3;
}

build_hodge_star_0 :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows := mesh.vertices.count;
	cols := rows;

	rows_start := NewArray(rows, s64);
	col_idx    := NewArray(rows + 1, s64);
	values     := NewArray(rows, float);

	for * rows_start { <<it = it_index; }
	for * col_idx    { <<it = it_index; }
	for * values {
		<<it = barycentric_dual_area(it_index, half_mesh, mesh);
	}

	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

build_hodge_star_1 :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows := mesh.edges.count;
	cols := rows;

	rows_start := NewArray(rows, s64);
	col_idx    := NewArray(rows + 1, s64);
	values     := NewArray(rows, float);

	for * rows_start { <<it = it_index; }
	for * col_idx    { <<it = it_index; }
	for * values {
		s := 0.0;
		s += cotan(half_mesh.edges[it_index], half_mesh, mesh);
		if (half_mesh.half_edges[half_mesh.edges[it_index]].twin >= 0)
			s += cotan(half_mesh.half_edges[half_mesh.edges[it_index]].twin, half_mesh, mesh);

		<<it = s / 2;
	}

	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

build_hodge_star_2 :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows := mesh.faces.count;
	cols := rows;

	rows_start := NewArray(rows, s64);
	col_idx    := NewArray(rows + 1, s64);
	values     := NewArray(rows, float);

	for * rows_start { <<it = it_index; }
	for * col_idx    { <<it = it_index; }
	for mesh.faces {
		i := mesh.vertices[it.x];
		j := mesh.vertices[it.y];
		k := mesh.vertices[it.z];

		lij := length(j - i);
		ljk := length(k - j);
		lki := length(i - k);

		s := (lij + ljk + lki) / 2;
		values[it_index] = sqrt(s * (s - lij) * (s - ljk) * (s - lki));
	}

	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

build_d0 :: (mesh: *Mesh) -> MKL.Sparse_Matrix {

	rows := mesh.nedge;
	cols := mesh.nvert;

	values     := NewArray(rows * 2, float);
	col_idx    := NewArray(values.count, s64);
	rows_start := NewArray(values.count + 1, s64);

	rows_start[rows_start.count - 1] = values.count;

	for e: 0..rows-1 {
		rows_start[e] = 2 * e;

		col_idx[2 * e + 0] = min(mesh.edges[e].a, mesh.edges[e].b);
		col_idx[2 * e + 1] = max(mesh.edges[e].a, mesh.edges[e].b);

		if mesh.edges[e].a < mesh.edges[e].b {
			values[2 * e + 0] = -1;
			values[2 * e + 1] = +1;
		}
		else {
			values[2 * e + 0] = +1;
			values[2 * e + 1] = -1;
		}
		
	}

	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

build_d1 :: (mesh: *Mesh) -> MKL.Sparse_Matrix {

	rows := mesh.nface;
	cols := mesh.nedge;

	values     := NewArray(rows * 3, float);
	col_idx    := NewArray(values.count, s64);
	rows_start := NewArray(values.count + 1, s64);

	rows_start[rows_start.count - 1] = values.count;

	for f: 0..rows-1 {
		a := mesh.faces[f].x;
		b := mesh.faces[f].y;
		c := mesh.faces[f].z;

		rows_start[f] = 3 * f;

		col_idx[3 * f + 0] = get_edge_index(mesh, mesh.faces[f].x, mesh.faces[f].y);
		col_idx[3 * f + 1] = get_edge_index(mesh, mesh.faces[f].y, mesh.faces[f].z);
		col_idx[3 * f + 2] = get_edge_index(mesh, mesh.faces[f].z, mesh.faces[f].x);

		values[3 * f + 0] = ifx a == mesh.edges[get_edge_index(mesh, a, b)].a then 1.0 else -1.0;
		values[3 * f + 1] = ifx b == mesh.edges[get_edge_index(mesh, b, c)].a then 1.0 else -1.0;
		values[3 * f + 2] = ifx c == mesh.edges[get_edge_index(mesh, c, a)].a then 1.0 else -1.0;
		
		// Sort three values
		if col_idx[f * 3 + 0] > col_idx[f * 3 + 1] {
			Swap(*col_idx[f * 3 + 0], *col_idx[f * 3 + 1]);
			Swap(*values [f * 3 + 0], *values [f * 3 + 1]);
		}
		if col_idx[f * 3 + 0] > col_idx[f * 3 + 2] {
			Swap(*col_idx[f * 3 + 0], *col_idx[f * 3 + 2]);
			Swap(*values [f * 3 + 0], *values [f * 3 + 2]);
		}
		if col_idx[f * 3 + 1] > col_idx[f * 3 + 2] {
			Swap(*col_idx[f * 3 + 1], *col_idx[f * 3 + 2]);
			Swap(*values [f * 3 + 1], *values [f * 3 + 2]);
		}
	}

	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

build_laplace :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows_start : [..] s64;
	col_idx : [..] s64;
	values : [..] float;

	row := NewArray(mesh.nvert, float, allocator=temp);

	for i: 0..mesh.nvert-1 {

		ui := 0.0;
		a := 2 * barycentric_dual_area(i, half_mesh, mesh);

		for * row { <<it = FLOAT32_MAX; }
		for iterate_adjacent_faces(i, *half_mesh, *mesh) {
			uj := 0.0;
			uj += cotan(it.out_half_edge, half_mesh, mesh);
			if half_mesh.half_edges[it.out_half_edge].twin >= 0
				uj += cotan(half_mesh.half_edges[it.out_half_edge].twin, half_mesh, mesh);

			j := tip(it.out_half_edge, half_mesh);

			row[j] = uj;
			ui -= uj;
		}

		row[i] = ui;

		array_add(*rows_start, values.count);

		for row if it != FLOAT32_MAX {
			array_add(*col_idx, it_index);
			array_add(*values, it);
		}
	}
	array_add(*rows_start, values.count);

	mat := MKL.create_sparse_matrix(mesh.nvert, mesh.nvert, rows_start, col_idx, values);
	return mat;
}

build_mass :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows_start : [..] s64;
	col_idx : [..] s64;
	values : [..] float;

	for i: 0..mesh.nvert-1 {
		array_add(*rows_start, values.count);
		array_add(*col_idx, i);
		array_add(*values, barycentric_dual_area(i, half_mesh, mesh));
	}
	array_add(*rows_start, values.count);

	return MKL.create_sparse_matrix(mesh.nvert, mesh.nvert, rows_start, col_idx, values);
}

build_lc :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows_start : [..] s64;
	col_idx : [..] s64;
	values : [..] float;

	row := NewArray(mesh.nvert, float, allocator=temp);

	for i: 0..mesh.nvert-1 {

		ui := 0.0;

		for * row { <<it = FLOAT32_MAX; }
		for iterate_adjacent_faces(i, *half_mesh, *mesh) {
			uj := 0.0;
			uj += cotan(it.out_half_edge, half_mesh, mesh);
			if half_mesh.half_edges[it.out_half_edge].twin >= 0
				uj += cotan(half_mesh.half_edges[it.out_half_edge].twin, half_mesh, mesh);

			j := tip(it.out_half_edge, half_mesh);

			row[j] = uj;
			ui -= uj;
		}

		row[i] = ui;

		array_add(*rows_start, values.count);


		for row if it != FLOAT32_MAX {
			array_add(*col_idx, it_index);
			array_add(*values, it);
		}
	}
	array_add(*rows_start, values.count);

	mat := MKL.create_sparse_matrix(mesh.nvert, mesh.nvert, rows_start, col_idx, values);
	return mat;
}


build_grad :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows_start : [..] s64;
	col_idx : [..] s64;
	values : [..] float;

	for f, f_idx: mesh.faces {
		a := area(f_idx, mesh);

		e0 := mesh.vertices[f.y] - mesh.vertices[f.x];
		e1 := mesh.vertices[f.z] - mesh.vertices[f.y];
		e2 := mesh.vertices[f.x] - mesh.vertices[f.z];

		n := normalize(cross(e0, e1));

		je0 := cross(n, e0);
		je1 := cross(n, e1);
		je2 := cross(n, e2);

		// X
		array_add(*rows_start, values.count);
		array_add(*col_idx, f.x);
		array_add(*values, je1.x / a);
		array_add(*col_idx, f.y);
		array_add(*values, je2.x / a);
		array_add(*col_idx, f.z);
		array_add(*values, je0.x / a);
		
		// Y
		array_add(*rows_start, values.count);
		array_add(*col_idx, f.x);
		array_add(*values, je1.y / a);
		array_add(*col_idx, f.y);
		array_add(*values, je2.y / a);
		array_add(*col_idx, f.z);
		array_add(*values, je0.y / a);
		
		// Z
		array_add(*rows_start, values.count);
		array_add(*col_idx, f.x);
		array_add(*values, je1.z / a);
		array_add(*col_idx, f.y);
		array_add(*values, je2.z / a);
		array_add(*col_idx, f.z);
		array_add(*values, je0.z / a);
	}

	array_add(*rows_start, values.count);

	return MKL.create_sparse_matrix(rows_start.count - 1, mesh.nvert, rows_start, col_idx, values);
}

build_div :: (half_mesh: Half_Mesh, mesh: Mesh) -> MKL.Sparse_Matrix {
	rows := mesh.nvert * 3;
	cols := mesh.nface * 3;

	rows_start : [..] s64;
	col_idx : [..] s64;
	values : [..] float;

	col_row : [..] s64;
	x_row : [..] float;
	y_row : [..] float;
	z_row : [..] float;
	defer {
		array_free(col_row);
		array_free(x_row);
		array_free(y_row);
		array_free(z_row);
	}

	for v, v_idx: mesh.vertices {
		a := v;

		col_row.count = 0;
		x_row.count = 0;
		y_row.count = 0;
		z_row.count = 0;

		for iterate_adjacent_faces(v_idx, *half_mesh, *mesh) {
			twin_in_he := half_mesh.half_edges[it.in_half_edge].twin;
			
			b := mesh.vertices[tip(it.out_half_edge, half_mesh)];
			c := mesh.vertices[tip(twin_in_he, half_mesh)];

			e1 := b - a;
			e2 := c - a;

			t1 := cotan(it.out_half_edge, half_mesh, mesh);
			t2 := cotan(twin_in_he, half_mesh, mesh);

			array_add(*col_row, it.face);
			array_add(*x_row, (t1 * e1.x + t2 * e2.x) / 2);
			array_add(*y_row, (t1 * e1.y + t2 * e2.y) / 2);
			array_add(*z_row, (t1 * e1.z + t2 * e2.z) / 2);
		}

		array_add(*rows_start, values.count);
		for x_row {
			array_add(*values, it);
			array_add(*col_idx, col_row[it_index]);
		}
		array_add(*rows_start, values.count);
		for y_row {
			array_add(*values, it);
			array_add(*col_idx, col_row[it_index]);
		}
		array_add(*rows_start, values.count);
		for z_row {
			array_add(*values, it);
			array_add(*col_idx, col_row[it_index]);
		}
	}
	array_add(*rows_start, values.count);
	return MKL.create_sparse_matrix(rows, cols, rows_start, col_idx, values);
}

collapse_div :: (div: [] float) -> [] float {
	collapsed : [] float;
	collapsed.data = div.data;
	collapsed.count = div.count / 3;
	for 0..(div.count/3)-1 {
		div[it] = div[it * 3 + 0];
		div[it] += div[it * 3 + 1];
		div[it] += div[it * 3 + 2];
	}
	return collapsed;
}

compute_div :: (X: [] Vector3, half_mesh: Half_Mesh, mesh: Mesh) -> [] float {
	d := NewArray(mesh.nvert, float);

	for v: 0..mesh.nvert-1 {
		d[v] = 0;

		a := mesh.vertices[v];
		for iterate_adjacent_faces(v, *half_mesh, *mesh) {
			twin_in_he := half_mesh.half_edges[it.in_half_edge].twin;
			
			b := mesh.vertices[tip(it.out_half_edge, half_mesh)];
			c := mesh.vertices[tip(twin_in_he, half_mesh)];

			e1 := a - b;
			e2 := a - c;

			t1 := cotan(it.out_half_edge, half_mesh, mesh);
			t2 := cotan(it.in_half_edge, half_mesh, mesh);

			d[v] += t1 * dot(e1, X[it.face]) + t2 * dot(e2, X[it.face]);
		}

		d[v] /= 2;
	}

	return d;
}

end_points :: (half_edge: Half_Edge, half_mesh: Half_Mesh, mesh: Mesh) -> (Vector3, Vector3) {
	a := mesh.vertices[half_edge.vertex];
	b := mesh.vertices[half_mesh.half_edges[half_edge.next].vertex];
	return (a, b);
}

tip :: (half_edge: int, half_mesh: Half_Mesh) -> int {
	return half_mesh.half_edges[half_mesh.half_edges[half_edge].next].vertex;
}

Iterate_Adjacent_Faces :: struct {
	vertex: int = -1;
	half_mesh: *Half_Mesh;
	mesh: *Mesh;
};

Vertex_Incident_Face :: struct {
	face: int = -1;
	vertex: int = -1;
	out\    _half_edge: int = -1;
	in\     _half_edge: int = -1;
	opposite_half_edge: int = -1;
};

iterate_adjacent_faces ::
	(vertex: int, half_mesh: *Half_Mesh, mesh: *Mesh) -> Iterate_Adjacent_Faces
{
	ret : Iterate_Adjacent_Faces = ---;
	ret.vertex = vertex;
	ret.half_mesh = half_mesh;
	ret.mesh = mesh;
	return ret;
}

for_expansion :: (iterator: Iterate_Adjacent_Faces, body: Code, flags: For_Flags) #expand {
	orig := iterator.half_mesh.vertices[iterator.vertex];
	edge := orig;
	
	`it : Vertex_Incident_Face;
	`it_index := 0;

	count := 0;
	while true {
		current : Vertex_Incident_Face;
		current.vertex = iterator.vertex;
		current.face = iterator.half_mesh.half_edges[edge].face;

		current.out_half_edge = edge;
		edge = iterator.half_mesh.half_edges[edge].next;

		current.opposite_half_edge = edge;
		edge = iterator.half_mesh.half_edges[edge].next;

		current.in_half_edge = edge;
		edge = iterator.half_mesh.half_edges[edge].twin;

		it = current;
		it_index = count;

		#insert body;
		
		count += 1;
		if edge == orig || edge < 0 return;
	}

	// If we come here then that means that we are at a boundary and we need to loop to the other
	// side of the first edge so we count every adjacent faces.
	orig = iterator.half_mesh.half_edges[orig].twin;
	edge = orig;
	while true {
		current : Vertex_Incident_Face;
		current.vertex = iterator.vertex;
		current.face = iterator.half_mesh.half_edges[edge].face;
		
		current.in_half_edge = edge;
		edge = iterator.half_mesh.half_edges[edge].next;

		current.out_half_edge = edge;
		current.opposite_half_edge = iterator.half_mesh.half_edges[edge].next;
		edge = iterator.half_mesh.half_edges[edge].twin;

		it = current;
		it_index = count;

		#insert body;
		
		count += 1;
		if edge == orig || edge < 0 return;
	}
}