

#scope_file
#import "Basic";
#import "Math";
Geometry :: #import "src/geometry";
GetRect :: #import "GetRect";
Color :: #import "src/color";
MKL :: #import "src/mkl";
#import "src/std";
#import "src/mesh";
#import "src/shader";

#scope_export

Camera :: struct {
	fov := 60.0;
	far := 500.0;
	near := 0.01;

	speed := 1.5;

	pos : Vector3;
	target : Vector3;
}

Scene_State :: struct {
	mouse_left_pressed := false;
	mouse_right_pressed := false;
	mouse_left_down := false;
	mouse_right_down := false;
	
	z_down : bool = false;
	s_down : bool = false;
	d_down : bool = false;
	q_down : bool = false;

	model_matrix : Matrix4 = Matrix4_Identity;
	shader : Shader;
	mesh   : Mesh;
	half_mesh : Half_Mesh;

	selected_simplicial : Geometry.Simplicial_Complex;
	selected_half_edge := -1;

	hover_vertex : s64 = -1;
	hover_edge : s64 = -1;
	hover_face : s64 = -1;

	run := false;

	camera: Camera;

	vertex_normals : [] Vector3;
	face_arrows : [] Vector3;
	heat : [] float;

	unit_vector_rotating_time := 0.0;
	scale_factor := 1.0;
};

Ui_State :: struct {
	eat_event := false;
	scroll_value := 0.0;

	reset_visible := false;
	reset_normals := false;
	show_vertex_interpolated := false;
	show_half_edges := false;
	show_normals := false;
	show_arrows := false;

	scale_up := false;
	scale_down := false;

	toggle_rotation := false;

	add_point := false;
	run_grad := false;
	run_star := false;
	run_closure := false;
	run_link := false;
	run_boundary := false;
	run_cotan := false;
	run_barycentric_dual_area := false;
	run_hodge0 := false;
	run_hodge1 := false;
	run_hodge2 := false;
	run_angle := false;
	run_angle_defect := false;
	run_next := false;
	run_twin := false;
	run_normal_angle_weighted := false;
	run_normal_sphere_inscribed := false;
	run_normal_area_weighted := false;
	run_normal_gaussian_curvature := false;
	run_normal_mean_curvature := false;
	run_minimal_curvature := false;
	run_maximal_curvature := false;
	run_laplace := false;
	run_heat_iteration := false;
	run_heat_method := false;

	popup_load_mesh := false;
	load_input := "<path to your obj>";
};

// ========================================================================
trigger_null :: (ui: *Ui_State, r: *GetRect.Rect) -> bool { return false; }
compute_null :: (ui: *Ui_State, scene: *Scene_State) {}

// ========================================================================
trigger_reset :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.reset_visible = GetRect.button(<<r, "Reset");
	r.y -= r.h;
	return ui.reset_visible;
} @Action(0);

compute_reset :: (ui: *Ui_State, scene: *Scene_State) {
	if ui.reset_visible Geometry.clear(scene.selected_simplicial);
} @Action(0);


// ========================================================================
trigger_star :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_star = GetRect.button(<<r, "Star");
	r.y -= r.h;
	return ui.run_star;
} @Action(1);

compute_star :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_star return;
	star := Geometry.star(scene.selected_simplicial, scene.mesh);
	defer Geometry.free(star);

	Geometry.swap(*star, *scene.selected_simplicial);
} @Action(1);


// ========================================================================
trigger_closure :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_closure = GetRect.button(<<r, "Closure");
	r.y -= r.h;
	return ui.run_closure;
} @Action(2);

compute_closure :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_closure return;

	closure := Geometry.closure(scene.selected_simplicial, scene.mesh);
	defer Geometry.free(closure);

	Geometry.swap(*closure, *scene.selected_simplicial);
} @Action(2);


// ========================================================================
trigger_link :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_link = GetRect.button(<<r, "Link");
	r.y -= r.h;
	return ui.run_link;
} @Action(3);

compute_link :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_link return;

	link := Geometry.link(scene.selected_simplicial, scene.mesh);
	defer Geometry.free(link);

	Geometry.swap(*link, *scene.selected_simplicial);
} @Action(3);


// ========================================================================
trigger_boundary :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_boundary = GetRect.button(<<r, "Boundary");
	r.y -= r.h;
	return ui.run_boundary;
} @Action(4);

compute_boundary :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_boundary return;

	boundary := Geometry.boundary(scene.selected_simplicial, scene.mesh);
	defer Geometry.free(boundary);

	Geometry.swap(*boundary, *scene.selected_simplicial);
} @Action(4);


// ========================================================================
trigger_cotan :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_cotan = GetRect.button(<<r, "Cotan");
	r.y -= r.h;
	return ui.run_cotan;
} @Action(5);

compute_cotan :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_cotan return;

	for scene.half_mesh.vertices {
		co := cotan(it, scene.half_mesh, scene.mesh);
		t := 1.0 / (1.0 + exp(co));
		scene.mesh.vertex_colors[it_index] = Color.map(t);
	}
	ui.show_vertex_interpolated = true;
} @Action(5);


// ========================================================================
trigger_barycenter :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_barycentric_dual_area = GetRect.button(<<r, "Barycenter");
	r.y -= r.h;
	return ui.run_barycentric_dual_area;
} @Action(6);

compute_barycenter :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_barycentric_dual_area return;

	ts := NewArray(scene.half_mesh.vertices.count, float, allocator=temp);

	max_t := 0.0;
	for scene.half_mesh.vertices {
		area := barycentric_dual_area(it_index, scene.half_mesh, scene.mesh);
		ts[it_index] = area;
		max_t = max(max_t, area);
	}
	for ts scene.mesh.vertex_colors[it_index] = Color.map(it / max_t);
	ui.show_vertex_interpolated = true;
} @Action(6);


// ========================================================================
trigger_hodge0 :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_hodge0 = GetRect.button(r, "*0");
	r.y -= r.h;
	return ui.run_hodge0;
} @Action(7);

compute_hodge0 :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_hodge0 return;
	star0 := scene.mesh.hodge_star_0;
	
	max_t := 0.0;
	for star0.values max_t = max(max_t, it);
	for star0.values scene.mesh.vertex_colors[it_index] = Color.map(it / max_t);
	ui.show_vertex_interpolated = true;
} @Action(7);


// ========================================================================
trigger_hodge1 :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_hodge1 = GetRect.button(r, "*1");
	r.y -= r.h;
	return ui.run_hodge1;
} @Action(8);

compute_hodge1 :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_hodge1 return;
	star1 := scene.mesh.hodge_star_1;
	
	ts := NewArray(scene.mesh.nvert, float, allocator=temp);
	ns := NewArray(scene.mesh.nvert, float, allocator=temp);
	for * ns { <<it = 0; }
	max_t := 0.0;
	min_t := 0.0;
	for star1.values { max_t = max(max_t, it); min_t = min(min_t, it); }
	for star1.values {
		ts[scene.mesh.edges[it_index].a] += (it - min_t) / (max_t - min_t);
		ts[scene.mesh.edges[it_index].b] += (it - min_t) / (max_t - min_t);
		ns[scene.mesh.edges[it_index].a] += 1;
		ns[scene.mesh.edges[it_index].b] += 1;
	}
	for * scene.mesh.vertex_colors { <<it = Color.map(ts[it_index] / ns[it_index]); }
	ui.show_vertex_interpolated = true;
} @Action(8);


// ========================================================================
trigger_hodge2 :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_hodge2 = GetRect.button(r, "*2");
	r.y -= r.h;
	return ui.run_hodge2;
} @Action(9);

compute_hodge2 :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_hodge2 return;
	star2 := scene.mesh.hodge_star_2;
	
	max_t := 0.0;
	for star2.values max_t = max(max_t, it);
	for * scene.mesh.face_colors { <<it = Color.map(star2.values[it_index] / max_t); }
	ui.show_vertex_interpolated = false;
} @Action(9);


// ========================================================================
trigger_angle :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_angle = GetRect.button(r, "Angle");
	r.y -= r.h;
	return ui.run_angle;
} @Action(10);

compute_angle:: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_angle return;
	ts := NewArray(scene.mesh.nvert, float, allocator=temp);
	ns := NewArray(scene.mesh.nvert, float, allocator=temp);
	for * ns { <<it = 0; }

	for scene.half_mesh.half_edges {
		a := Geometry.angle(it_index, scene.half_mesh, scene.mesh);

		v := it.vertex;
		ts[v] += a;
		ns[v] += 1;
	}

	max_t : float = 3.1415926;
	for * scene.mesh.vertex_colors { <<it = Color.map(ts[it_index] / (ns[it_index] * max_t)); }
	ui.show_vertex_interpolated = true;
} @Action(10);


// ========================================================================
trigger_angle_defect :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_angle_defect = GetRect.button(r, "Angle defect");
	r.y -= r.h;
	return ui.run_angle_defect;
} @Action(11);

compute_angle_defect :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_angle_defect return;
	ts := NewArray(scene.mesh.nvert, float, allocator=temp);

	for 0..scene.mesh.nvert-1 {
		ts[it] = Geometry.angle_defect(it, scene.half_mesh, scene.mesh);
	}

	max_t : float = 2 * PI;
	min_t : float = -2 * PI;
	for * scene.mesh.vertex_colors { <<it = Color.map((ts[it_index] - min_t) / (max_t - min_t)); }
	ui.show_vertex_interpolated = true;
} @Action(11);


// ========================================================================
trigger_normal_angle_weigthed :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_normal_angle_weighted = GetRect.button(r, "N phi");
	r.y -= r.h;
	return ui.run_normal_angle_weighted;
} @Action(12);

compute_normal_angle_weigthed :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_normal_angle_weighted return;
	array_free(scene.vertex_normals);
	scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

	for 0..scene.mesh.nvert-1 {
		scene.vertex_normals[it] = Geometry.vertex_normal_angle_weighted(
			it, scene.half_mesh, scene.mesh
		);
	}

	ui.show_normals = true;
} @Action(12);


// ========================================================================
trigger_normal_sphere_inscribed :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_normal_sphere_inscribed = GetRect.button(r, "N s");
	r.y -= r.h;
	return ui.run_normal_sphere_inscribed;
} @Action(13);

compute_normal_sphere_inscribed :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_normal_sphere_inscribed return;
	array_free(scene.vertex_normals);
	scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

	for 0..scene.mesh.nvert-1 scene.vertex_normals[it] = Geometry.vertex_normal_sphere_inscribed(
		it, scene.half_mesh, scene.mesh
	);

	ui.show_normals = true;
} @Action(13);


// ========================================================================
trigger_normal_area_weighted :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_normal_area_weighted = GetRect.button(r, "N a");
	r.y -= r.h;
	return ui.run_normal_area_weighted;
} @Action(14);

compute_normal_area_weighted :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_normal_area_weighted return;
	array_free(scene.vertex_normals);
	scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

	for 0..scene.mesh.nvert-1 scene.vertex_normals[it] = Geometry.vertex_normal_area_weighted(
		it, scene.half_mesh, scene.mesh
	);

	ui.show_normals = true;
} @Action(14);


// ========================================================================
trigger_normal_gaussian_curvature :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_normal_gaussian_curvature = GetRect.button(r, "KN");
	r.y -= r.h;
	return ui.run_normal_gaussian_curvature;
} @Action(15);

compute_normal_gaussian_curvature :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_normal_gaussian_curvature return;
	scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

	for 0..scene.mesh.nvert-1 {
		scene.vertex_normals[it] = Geometry.vertex_normal_gaussian_curvature(
			it, scene.half_mesh, scene.mesh
		);
	}

	ui.show_normals = true;
} @Action(15);


// ========================================================================
trigger_normal_mean_curvature :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_normal_mean_curvature = GetRect.button(r, "HN");
	r.y -= r.h;
	return ui.run_normal_mean_curvature;
} @Action(16);

compute_normal_mean_curvature :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_normal_mean_curvature return;
	array_free(scene.vertex_normals);
	scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

	for 0..scene.mesh.nvert-1 {
		scene.vertex_normals[it] = Geometry.vertex_normal_mean_curvature(
			it, scene.half_mesh, scene.mesh
		);
	}

	ui.show_normals = true;
} @Action(16);


// ========================================================================
trigger_minimal_curvature :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_minimal_curvature = GetRect.button(r, "k1");
	r.y -= r.h;
	return ui.run_minimal_curvature;
} @Action(17);

compute_minimal_curvature :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_minimal_curvature return;
	ts := NewArray(scene.mesh.nvert, float, allocator=temp);

	min_t := +FLOAT32_MAX;
	max_t := -FLOAT32_MAX;
	for * ts {
		k1, k2 := Geometry.principal_curvatures(it_index, scene.half_mesh, scene.mesh);
		<<it = k1;
		min_t = min(min_t, <<it);
		max_t = max(max_t, <<it);
	}

	for * scene.mesh.vertex_colors {
		<<it = Color.map((ts[it_index] - min_t) / (max_t - min_t));
	}
	ui.show_vertex_interpolated = true;
} @Action(17);


// ========================================================================
trigger_maximal_curvature :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_maximal_curvature = GetRect.button(r, "k2");
	r.y -= r.h;
	return ui.run_maximal_curvature;
} @Action(18);

compute_maximal_curvature :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_maximal_curvature return;
	ts := NewArray(scene.mesh.nvert, float, allocator=temp);

	min_t := +FLOAT32_MAX;
	max_t := -FLOAT32_MAX;
	for * ts {
		k1, k2 := Geometry.principal_curvatures(it_index, scene.half_mesh, scene.mesh);
		<<it = k2;
		min_t = min(min_t, <<it);
		max_t = max(max_t, <<it);
	}

	for * scene.mesh.vertex_colors {
		<<it = Color.map((ts[it_index] - min_t) / (max_t - min_t));
	}
	ui.show_vertex_interpolated = true;
} @Action(18);


// ========================================================================
trigger_laplace :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_laplace = GetRect.button(r, "Laplace");
	r.y -= r.h;
	return ui.run_laplace;
} @Action(19);

compute_laplace :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_laplace return;
	prob := Geometry.scalar_problem(scene.mesh);
	
	u := NewArray(scene.mesh.nvert, float, allocator=temp);
	for scene.mesh.vertex_visible
		if it then u[it_index] = 2 * ((it_index % 2) - 0.5); else u[it_index] = 0;

	x := Geometry.solve(u, prob);
	defer array_free(x);

	min_t := +FLOAT32_MAX;
	max_t := -FLOAT32_MAX;
	for x {
		max_t = max(max_t, it);
		min_t = min(min_t, it);
	}

	for x scene.mesh.vertex_colors[it_index] = Color.map((it - min_t) / (max_t - min_t));
	ui.show_vertex_interpolated = true;
} @Action(19);


// ========================================================================
trigger_heat_iteration :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	toggle_heat_iteration := GetRect.button(r, "Heat iteration");
	r.y -= r.h;
	ui.run_heat_iteration ^= toggle_heat_iteration;
	return toggle_heat_iteration;
} @Action(20);

compute_heat_iteration :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_heat_iteration return;
	for 0..99 {
		for scene.mesh.vertex_visible if it then scene.heat[it_index] = 2 * ((it_index % 2) - 0.5);

		dt := MKL.mul(scene.mesh.laplace, scene.heat);
		defer array_free(dt);

		for scene.heat scene.heat[it_index] -= dt[it_index] * 0.01;
	}

	min_t := -1.0;
	max_t := +1.0;
	for scene.heat {
		max_t = max(max_t, it);
		min_t = min(min_t, it);
	}

	for scene.heat {
		c := Color.map((it - min_t) / (max_t - min_t), Color.Seismic_Color_Map);
		scene.mesh.vertex_colors[it_index] = c;
	}
	ui.show_vertex_interpolated = true;
} @Action(20);


// ========================================================================
trigger_heat_method :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_heat_method = GetRect.button(r, "Heat");
	r.y -= r.h;
	return ui.run_heat_method;
} @Action(20);

compute_heat_method :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_heat_method return;

	u0 := NewArray(scene.mesh.nvert, float, allocator=temp);

	for 0..99 {
		for scene.mesh.vertex_visible if it then u0[it_index] = 2 * ((it_index % 2) - 0.5);
		scene.heat = Geometry.heat_method(u0, scene.mesh);

		for * u0 { <<it = scene.heat[it_index]; };
	}

	min_t := -1.0;
	max_t := +1.0;
	for scene.heat {
		max_t = max(max_t, it);
		min_t = min(min_t, it);
	}

	for scene.heat {
		c := Color.log_map((it - min_t) / (max_t - min_t), Color.Seismic_Color_Map);
		scene.mesh.vertex_colors[it_index] = c;
	}
	ui.show_vertex_interpolated = true;
} @Action(28);


trigger_rotate :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	toggle_rotation := GetRect.button(r, "Rotate");
	if toggle_rotation ui.toggle_rotation ^= true;
	r.y -= r.h;
	return toggle_rotation;
} @Action(21);

compute_rotate :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.toggle_rotation return;

	x := cos(2 * PI * scene.unit_vector_rotating_time / 10 + 0 * PI / 3);
	y := cos(2 * PI * scene.unit_vector_rotating_time / 10 + 2 * PI / 3);
	z := cos(2 * PI * scene.unit_vector_rotating_time / 10 + 4 * PI / 3);

	scene.model_matrix = look_at_matrix(.{0, 0, 0}, normalize(make_vector3(x, y, z)));
	scene.model_matrix._11 *= scene.scale_factor;
	scene.model_matrix._12 *= scene.scale_factor;
	scene.model_matrix._13 *= scene.scale_factor;
	scene.model_matrix._21 *= scene.scale_factor;
	scene.model_matrix._22 *= scene.scale_factor;
	scene.model_matrix._23 *= scene.scale_factor;
	scene.model_matrix._31 *= scene.scale_factor;
	scene.model_matrix._32 *= scene.scale_factor;
	scene.model_matrix._33 *= scene.scale_factor;
} @Action(21);


trigger_reset_normal :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.reset_normals = GetRect.button(r, "Reset normals");
	r.y -= r.h;
	return ui.reset_normals;
} @Action(22);


trigger_scale_up :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.scale_up = GetRect.button(r, "Scale up");
	r.y -= r.h;
	return ui.scale_up;
} @Action(23);


trigger_scale_down :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.scale_down = GetRect.button(r, "Scale down");
	r.y -= r.h;
	return ui.scale_down;
} @Action(24);


trigger_toggle_vertex :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	toggle := GetRect.button(r, "Toggle Vertex");
	ui.show_vertex_interpolated ^= toggle;
	r.y -= r.h;
	return toggle;
} @Action(25);


trigger_toggle_half_edges :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	toggle := GetRect.button(r, "Toggle Half Edges");
	ui.show_half_edges ^= toggle;
	r.y -= r.h;
	return toggle;
} @Action(26);


trigger_normals :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	toggle := GetRect.button(r, "Toggle Normal");
	ui.show_normals ^= toggle;
	r.y -= r.h;
	return toggle;
} @Action(27);


trigger_grad :: (ui: *Ui_State, r: *GetRect.Rect) -> bool {
	ui.run_grad = GetRect.button(r, "Grad");
	r.y -= r.h;
	return ui.run_grad;
} @Action(29);

compute_grad :: (ui: *Ui_State, scene: *Scene_State) {
	if !ui.run_grad return;

	array_free(scene.face_arrows);
	scene.face_arrows = Geometry.grad(scene.heat, scene.mesh);

	ui.show_arrows = true;
} @Action(29);

#scope_file

look_at_matrix :: (viewpoint: Vector3, look_at: Vector3) -> Matrix4 {
	up : Vector3 = .{0, 0, 1};
	dir := look_at - viewpoint;
	normalize_or_z_axis(*dir);

	x := cross_product(dir, up);
	normalize_or_z_axis(*x);

	y := cross_product(x, dir);
	normalize_or_z_axis(*y);

	z := -1 * dir;

	result := translate(make_matrix_from_rows(x, y, z), -viewpoint);

	return result;
}

