#scope_file
#import "Basic";
Simp :: #import "Simp";
GetRect :: #import "GetRect";
Input :: #import "Input";
#import "GL";
#import "Random";
#import "Math";
#import "Window_Creation";

#import "src/geometry";
#import "src/std";
#import "src/mesh";
#import "src/shader";
Render :: #import "src/render";
MKL :: #import "src/mkl";
Geometry :: #import "src/geometry";
Collision :: #import "src/collision";
DEC :: #import "src/dec";
Color :: #import "src/color";
#scope_export

Window_State :: struct {
	handle : Window_Type;

	width := 1600;
	height := 900;
};

Simp_State :: struct {
	width : s64;
	height : s64;
};

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

	shader : Shader;
	mesh   : Mesh;
	half_mesh : Half_Mesh;

	selected_simplicial : Geometry.Simplicial_Complex;
	selected_half_edge := -1;

	selected_point : s64 = -1;
	hover_vertex : s64 = -1;
	hover_edge : s64 = -1;
	hover_face : s64 = -1;

	run := false;

	camera: Camera;

	vertex_normals : [] Vector3;
};

Ui_State :: struct {
	eat_event := false;
	scroll_value := 0.0;

	reset_visible := false;
	show_vertex_interpolated := false;
	show_half_edges := false;
	show_normals := false;

	add_point := false;
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
};

window_state : Window_State;
simp_state : Simp_State;


main :: () {
	#if OS == .WINDOWS {
		Windows :: #import "Windows";
		Windows.SetProcessDPIAware();
		Windows.timeBeginPeriod(1);
	}

	window_state.handle = create_window(window_state.width, window_state.height, "Solide");
	window_state.width, window_state.height = Simp.get_render_dimensions(window_state.handle);

	Simp.set_render_target(window_state.handle);
	Simp.init_fonts();
	GetRect.ui_init();

	scene : Scene_State;
	scene.shader = shader_init();
	scene.mesh   = load_mesh("spot.obj");
	scene.half_mesh = construct_half_mesh(scene.mesh);
	build_matrices(scene.half_mesh, *scene.mesh);

	// init Simplicial.
	array_resize(*scene.selected_simplicial.vertices, scene.mesh.vertices.count);
	array_resize(*scene.selected_simplicial.edges, scene.mesh.edges.count);
	array_resize(*scene.selected_simplicial.faces, scene.mesh.faces.count);
	for * scene.selected_simplicial.vertices { <<it = 0; }
	for * scene.selected_simplicial.edges { <<it = 0; }
	for * scene.selected_simplicial.faces { <<it = 0; }

	scene.camera.pos    = .{ 1, 0, 1 };
	scene.camera.target = .{ 0, 0, 0 };

	ui : Ui_State;

	timer := current_time_monotonic();	

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	quit := false;
	while !quit {
		dt := cast(float) to_float64_seconds(current_time_monotonic() - timer);
		timer = current_time_monotonic();
		Input.update_window_events();

		for Input.get_window_resizes() {
			Simp.update_window(it.window);

			if it.window == window_state.handle {
				window_state.width  = it.width;
				window_state.height = it.height;
			}
		}

		scene.run = false;

		scene.mouse_left_pressed = false;
		scene.mouse_right_pressed = false;
		for Input.events_this_frame {
			GetRect.getrect_handle_event(it);
			if it.type == .QUIT then quit = true;

			if it.type == {
			case .KEYBOARD;
				if it.key_pressed && it.key_code == .ESCAPE {
					quit = true;
				}
				if it.key_code == #char "Z" then scene.z_down = xx it.key_pressed;
				if it.key_code == #char "S" then scene.s_down = xx it.key_pressed;
				if it.key_code == #char "Q" then scene.q_down = xx it.key_pressed;
				if it.key_code == #char "D" then scene.d_down = xx it.key_pressed;
				if it.key_pressed && it.key_code == #char "E" then scene.selected_point += 1;
				if it.key_pressed && it.key_code == #char "A" then scene.selected_point -= 1;
				if it.key_pressed && it.key_code == #char "R" then scene.selected_point = -1;
				if it.key_pressed && it.key_code == .SPACEBAR then scene.run = true;

				mouse_left\_can_be_pressed := !scene.mouse_left\_down;
				mouse_right_can_be_pressed := !scene.mouse_right_down;

				if it.key_code == .MOUSE_BUTTON_RIGHT scene.mouse_right_down = it.key_pressed > 0;
				if it.key_code == .MOUSE_BUTTON_LEFT  scene.mouse_left_down  = it.key_pressed > 0;

				scene.mouse_left\_pressed = mouse_left\_can_be_pressed && scene.mouse_left\_down;
				scene.mouse_right_pressed = mouse_right_can_be_pressed && scene.mouse_right_down;
			}
		}
		if scene.mesh.nvert > 0 then scene.selected_point %= scene.mesh.nvert;
		else                         scene.selected_point = -1;
		scene.selected_point = max(scene.selected_point, -1);

		render(*scene, *ui);
		update(*scene, *ui, dt);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State, ui: *Ui_State, dt: float) {
	T += dt;
	scene.camera.target = .{ 0, 0, 0 };
	
	if scene.selected_point >= 0 {
		scene.camera.target = scene.mesh.vertices[scene.selected_point];
	}

	delta := scene.camera.pos - scene.camera.target;
	theta := atan2(delta.y, delta.x);
	l : float = 0;
	l += delta.x * delta.x;
	l += delta.y * delta.y;
	l = sqrt(l);

	scene.camera.pos.z = scene.camera.target.z + l / 2;
	if scene.q_down theta += scene.camera.speed * dt;
	if scene.d_down theta -= scene.camera.speed * dt;
	if scene.z_down l += scene.camera.speed * dt;
	if scene.s_down l -= scene.camera.speed * dt;
	
	scene.camera.pos.x = scene.camera.target.x + cos(theta) * l;
	scene.camera.pos.y = scene.camera.target.y + sin(theta) * l;

	if ui.reset_visible Geometry.clear(scene.selected_simplicial);
	if ui.add_point && scene.selected_point >= 0 {
		scene.selected_simplicial.vertices[scene.selected_point] = 1;
	}

	if ui.run_star {
		star := Geometry.star(scene.selected_simplicial, scene.mesh);
		defer free(star);

		Geometry.swap(*star, *scene.selected_simplicial);
	}
	if ui.run_closure {
		closure := Geometry.closure(scene.selected_simplicial, scene.mesh);
		defer free(closure);

		Geometry.swap(*closure, *scene.selected_simplicial);
	}

	if ui.run_link {
		link := Geometry.link(scene.selected_simplicial, scene.mesh);
		defer free(link);

		Geometry.swap(*link, *scene.selected_simplicial);
	}

	if ui.run_boundary {
		boundary := Geometry.boundary(scene.selected_simplicial, scene.mesh);
		defer free(boundary);

		Geometry.swap(*boundary, *scene.selected_simplicial);
	}

	if ui.run_cotan {
		for scene.half_mesh.vertices {
			co := cotan(it, scene.half_mesh, scene.mesh);
			t := 1.0 / (1.0 + exp(co));
			scene.mesh.vertex_colors[it_index] = Color.map(t);
		}
		ui.show_vertex_interpolated = true;
	}

	if ui.run_barycentric_dual_area {
		ts := NewArray(scene.half_mesh.vertices.count, float, allocator=temp);

		max_t := 0.0;
		for scene.half_mesh.vertices {
			area := barycentric_dual_area(it_index, scene.half_mesh, scene.mesh);
			ts[it_index] = area;
			max_t = max(max_t, area);
		}
		for ts scene.mesh.vertex_colors[it_index] = Color.map(it / max_t);
		ui.show_vertex_interpolated = true;
	}

	if ui.run_hodge0 {
		star0 := scene.mesh.hodge_star_0;
		
		max_t := 0.0;
		for star0.values max_t = max(max_t, it);
		for star0.values scene.mesh.vertex_colors[it_index] = Color.map(it / max_t);
		ui.show_vertex_interpolated = true;
	}

	if ui.run_hodge1 {
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
	}

	if ui.run_hodge2 {
		star2 := scene.mesh.hodge_star_2;
		
		max_t := 0.0;
		for star2.values max_t = max(max_t, it);
		for * scene.mesh.face_colors { <<it = Color.map(star2.values[it_index] / max_t); }
		ui.show_vertex_interpolated = false;
	}

	if ui.run_angle {
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
	}

	if ui.run_angle_defect {
		ts := NewArray(scene.mesh.nvert, float, allocator=temp);

		for 0..scene.mesh.nvert-1 {
			ts[it] = Geometry.angle_defect(it, scene.half_mesh, scene.mesh);
		}

		max_t : float = 2 * PI;
		min_t : float = -2 * PI;
		for * scene.mesh.vertex_colors { <<it = Color.map((ts[it_index] - min_t) / (max_t - min_t)); }
		ui.show_vertex_interpolated = true;
	}
	
	if ui.run_next {
		if scene.selected_half_edge < 0 {
			scene.selected_half_edge = max(scene.selected_half_edge, 0);
		} else {
			scene.selected_half_edge = scene.half_mesh.half_edges[scene.selected_half_edge].next;
		}
	}

	if ui.run_twin {
		if scene.selected_half_edge < 0 {
			scene.selected_half_edge = max(scene.selected_half_edge, 0);
		} else {
			scene.selected_half_edge = scene.half_mesh.half_edges[scene.selected_half_edge].twin;
		}
	}

	if ui.run_normal_angle_weighted {
		array_free(scene.vertex_normals);
		scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

		for 0..scene.mesh.nvert-1 {
			scene.vertex_normals[it] = Geometry.vertex_normal_angle_weighted(
				it, scene.half_mesh, scene.mesh
			);
		}

		ui.show_normals = true;
	}

	if ui.run_normal_sphere_inscribed {
		array_free(scene.vertex_normals);
		scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

		for 0..scene.mesh.nvert-1 {
			scene.vertex_normals[it] = Geometry.vertex_normal_sphere_inscribed(
				it, scene.half_mesh, scene.mesh
			);
		}

		ui.show_normals = true;
	}

	if ui.run_normal_area_weighted {
		array_free(scene.vertex_normals);
		scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

		for 0..scene.mesh.nvert-1 {
			scene.vertex_normals[it] = Geometry.vertex_normal_area_weighted(
				it, scene.half_mesh, scene.mesh
			);
		}

		ui.show_normals = true;
	}

	if ui.run_normal_gaussian_curvature {
		array_free(scene.vertex_normals);
		scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

		for 0..scene.mesh.nvert-1 {
			scene.vertex_normals[it] = Geometry.vertex_normal_gaussian_curvature(
				it, scene.half_mesh, scene.mesh
			);
		}

		ui.show_normals = true;
	}

	if ui.run_normal_mean_curvature {
		array_free(scene.vertex_normals);
		scene.vertex_normals = NewArray(scene.mesh.nvert, Vector3);

		for 0..scene.mesh.nvert-1 {
			scene.vertex_normals[it] = Geometry.vertex_normal_mean_curvature(
				it, scene.half_mesh, scene.mesh
			);
		}

		ui.show_normals = true;
	}

	update_ray_picking(scene, ui);

	for * scene.mesh.vertex_visible {
		<<it = scene.selected_simplicial.vertices[it_index] > 0 || scene.hover_vertex == it_index;
	}
	for * scene.mesh.edge_visible   {
		<<it = scene.selected_simplicial.edges[it_index] > 0    || scene.hover_edge == it_index;
	}
	temp_colors := NewArray(scene.mesh.face_colors.count, Vector3, allocator=temp);
	for * scene.mesh.face_colors    {
		temp_colors[it_index] = <<it;
		if scene.selected_simplicial.faces[it_index] > 0 || scene.hover_face == it_index then
			temp_colors[it_index] = .{1, 1, 1};
	}

	{
		t := scene.mesh.face_colors;
		scene.mesh.face_colors.data = temp_colors.data;
		defer scene.mesh.face_colors.data = t.data;
		old := false;
		if scene.selected_point >= 0 old = scene.mesh.vertex_visible[scene.selected_point];
		if scene.selected_point >= 0 scene.mesh.vertex_visible[scene.selected_point] = true;
		update_gpu_data(*scene.mesh, ui.show_vertex_interpolated);
		if scene.selected_point >= 0 scene.mesh.vertex_visible[scene.selected_point] = old;
	}
}

update_ray_picking :: (scene: *Scene_State, ui: *Ui_State) {
	ray := ray_from_camera(window_state, scene);
	tri : Collision.Triangle = ---;
	cap : Collision.Capsule = ---;
	sph : Collision.Sphere = ---;

	cap.r = 0.01;
	sph.r = 0.015;

	t_tri : float = FLOAT32_MAX;
	t_cap : float = FLOAT32_MAX;
	t_sph : float = FLOAT32_MAX;

	tri_idx := -1;
	edg_idx := -1;
	ver_idx := -1;

	for scene.mesh.faces {
		tri.a = scene.mesh.vertices[it.x];
		tri.b = scene.mesh.vertices[it.y];
		tri.c = scene.mesh.vertices[it.z];

		t, hit := Collision.triangle_ray_t(tri, ray);
		if hit && t_tri > t {
			t_tri = t;
			tri_idx = it_index;
		}
	}
	for scene.mesh.edges {
		cap.a = scene.mesh.vertices[it.a];
		cap.b = scene.mesh.vertices[it.b];

		t, hit := Collision.capsule_ray_t(cap, ray);
		if hit && t_cap > t {
			t_cap = t;
			edg_idx = it_index;
		}
	}
	for scene.mesh.vertices {
		sph.p = it;

		t, hit := Collision.sphere_ray_t(sph, ray);
		if hit && t_sph > t {
			t_sph = t;
			ver_idx = it_index;
		}
	}

	t_min := min(t_tri, min(t_cap, t_sph));

	scene.hover_vertex = ifx ver_idx >= 0 && t_sph == t_min then ver_idx else -1;
	scene.hover_edge   = ifx edg_idx >= 0 && t_cap == t_min then edg_idx else -1;
	scene.hover_face   = ifx tri_idx >= 0 && t_tri == t_min then tri_idx else -1;

	if scene.mouse_left_pressed && !ui.eat_event {
		if scene.hover_vertex >= 0 scene.selected_simplicial.vertices[scene.hover_vertex] = 1;
		if scene.hover_edge   >= 0 scene.selected_simplicial.edges[scene.hover_edge] = 1;
		if scene.hover_face   >= 0 scene.selected_simplicial.faces[scene.hover_face] = 1;
	}
}

samples :: #run -> [] Render.Arrow {
	vec : [2000] Render.Arrow;
	for 0..vec.count-1 {
		vec[it].a = .{0, 0, 0};
		vec[it].b = make_vector3(
			random_get_zero_to_one() * 2 - 1, -1 + 2 * random_get_zero_to_one(), random_get_zero_to_one() * 2 - 1
		);
		vec[it].color = vec[it].b;
		vec[it].b = (0.1 + random_get_zero_to_one() * 0.9) *normalize(vec[it].b);
		vec[it].r = random_get_zero_to_one() * 0.05 + 0.05;
	}
	return vec;
};

T := 0.0;

render :: (scene: *Scene_State, ui: *Ui_State) {
	glClearColor(.15, .08, .08, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	// glDepthMask(GL_TRUE);
	// glEnable(GL_CULL_FACE);
	// glCullFace(GL_BACK);
	glEnable(GL_DEPTH_TEST);
	view := look_at_matrix(scene.camera.pos, scene.camera.target);
	proj := projection(scene.camera);
	set_uniform(scene.shader, "view", view);
	set_uniform(scene.shader, "projection", proj);

	render(scene.mesh, scene.shader);

	if ui.show_half_edges {
		instances := NewArray(scene.half_mesh.half_edges.count, Render.Arrow, allocator=temp);
		for scene.half_mesh.half_edges {
			a := scene.mesh.vertices[it.vertex];
			b := scene.mesh.vertices[scene.half_mesh.half_edges[it.next].vertex];

			c := mean(it.face, scene.mesh);

			a = c + (a - c) * 0.9;
			b = c + (b - c) * 0.9;

			instances[it_index].a = a;
			instances[it_index].b = b;
			instances[it_index].r = area(it.face, scene.mesh);
			instances[it_index].color = .{1, 1, 1};
		}
		Render.arrows(instances, proj * view, tip_ratio=0.3);
	}
	if ui.show_normals {
		instances := NewArray(scene.vertex_normals.count, Render.Arrow, allocator=temp);
		for scene.vertex_normals {
			a := scene.mesh.vertices[it_index];
			b := a + it * 0.025;

			instances[it_index].a = a;
			instances[it_index].b = b;
			instances[it_index].r = 0.002;
			instances[it_index].color = .{1, 1, 1};
		}
		Render.arrows(instances, proj * view, tip_ratio=0.1);
	}
	// Render.arrows(samples, proj * view, tip_ratio= 0.8 * sin(T) * sin(T) + 0.1);

	render_ui(scene, ui);

	Simp.swap_buffers(window_state.handle);
}

render :: (mesh: Mesh, shader: Shader) {
	glUseProgram(shader.program);
	glBindVertexArray(mesh.vao);
	glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
	glDrawArrays(GL_TRIANGLES, xx 0, xx mesh.cpu_buffer.count);

}

render_ui :: (scene: *Scene_State, ui: *Ui_State) {
	glDisable(GL_DEPTH_TEST);
	// glDepthMask(GL_FALSE);
	Simp.set_shader_for_color();
	current_time := to_float64_seconds (current_time_monotonic ());
	GetRect.ui_per_frame_update(
		window_state.handle, xx window_state.width, xx window_state.height, current_time
	);

	theme := GetRect.default_overall_theme;
	font := theme.label_theme.font;

	ui.eat_event = false;
	pad : float = 10;
	k := window_state.height * 0.05;

	scroll_region := GetRect.get_rect(pad, pad, 5*k, window_state.height - 2 * pad);
	{
		region, inside := GetRect.begin_scrollable_region(scroll_region);
		r := inside;
		r.y = scroll_region.h + scroll_region.y;
		r.h = k;
		r.w = 4 * k;
		r.y += ui.scroll_value;

		defer GetRect.end_scrollable_region(region, r.w, r.y, *ui.scroll_value);

		ui.reset_visible = GetRect.button(r, "Reset", *theme.button_theme);
		ui.eat_event |= ui.reset_visible;
		r.y -= k + pad;

		ui.run_star = GetRect.button(r, "Run star", *theme.button_theme);
		ui.eat_event |= ui.run_star;
		r.y -= k + pad;

		ui.run_closure = GetRect.button(r, "Run closure", *theme.button_theme);
		ui.eat_event |= ui.run_closure;
		r.y -= k + pad;

		ui.run_link = GetRect.button(r, "Run link", *theme.button_theme);
		ui.eat_event |= ui.run_link;
		r.y -= k + pad;

		ui.run_boundary = GetRect.button(r, "Run boundary", *theme.button_theme);
		ui.eat_event |= ui.run_boundary;
		r.y -= k + pad;

		ui.add_point = GetRect.button(r, "Add point", *theme.button_theme);
		ui.eat_event |= ui.add_point;
		r.y -= k + pad;

		ui.run_cotan = GetRect.button(r, "Cotan", *theme.button_theme);
		ui.eat_event |= ui.run_cotan;
		r.y -= k + pad;

		ui.run_barycentric_dual_area = GetRect.button(r, "Barycenter", *theme.button_theme);
		ui.eat_event |= ui.run_barycentric_dual_area;
		r.y -= k + pad;

		ui.run_hodge0 = GetRect.button(r, "*0", *theme.button_theme);
		ui.eat_event |= ui.run_hodge0;
		r.y -= k + pad;

		ui.run_hodge1 = GetRect.button(r, "*1", *theme.button_theme);
		ui.eat_event |= ui.run_hodge1;
		r.y -= k + pad;

		ui.run_hodge2 = GetRect.button(r, "*2", *theme.button_theme);
		ui.eat_event |= ui.run_hodge2;
		r.y -= k + pad;

		ui.run_angle = GetRect.button(r, "Angle", *theme.button_theme);
		ui.eat_event |= ui.run_angle;
		r.y -= k + pad;

		ui.run_angle_defect = GetRect.button(r, "Angle Defect", *theme.button_theme);
		ui.eat_event |= ui.run_angle_defect;
		r.y -= k + pad;
		
		ui.run_next = GetRect.button(r, "Next", *theme.button_theme);
		ui.eat_event |= ui.run_next;
		r.y -= k + pad;

		ui.run_twin = GetRect.button(r, "Twin", *theme.button_theme);
		ui.eat_event |= ui.run_twin;
		r.y -= k + pad;

		if GetRect.button(r, "Toggle Vertex", *theme.button_theme) {
			ui.eat_event |= true;
			ui.show_vertex_interpolated = !ui.show_vertex_interpolated;
		}
		r.y -= k + pad;

		if GetRect.button(r, "Toggle Half Edges", *theme.button_theme) {
			ui.eat_event |= true;
			ui.show_half_edges = !ui.show_half_edges;
		}
		r.y -= k + pad;
		
		if GetRect.button(r, "Toggle Normals", *theme.button_theme) {
			ui.eat_event |= true;
			ui.show_normals = !ui.show_normals;
		}
		r.y -= k + pad;
		
		ui.run_normal_angle_weighted = GetRect.button(r, "N phi", *theme.button_theme);
		ui.eat_event |= ui.run_normal_angle_weighted;
		r.y -= k + pad;

		ui.run_normal_sphere_inscribed = GetRect.button(r, "N s", *theme.button_theme);
		ui.eat_event |= ui.run_normal_sphere_inscribed;
		r.y -= k + pad;
		
		ui.run_normal_area_weighted = GetRect.button(r, "N a", *theme.button_theme);
		ui.eat_event |= ui.run_normal_area_weighted;
		r.y -= k + pad;
		
		ui.run_normal_gaussian_curvature = GetRect.button(r, "KN", *theme.button_theme);
		ui.eat_event |= ui.run_normal_gaussian_curvature;
		r.y -= k + pad;

		ui.run_normal_mean_curvature = GetRect.button(r, "HN", *theme.button_theme);
		ui.eat_event |= ui.run_normal_mean_curvature;
		r.y -= k + pad;

		r.y -= k + pad;
	}


	GetRect.draw_popups();
}

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

perspective :: (fov: float, ratio: float, f: float, n: float) -> Matrix4 {
	uw := 1.0 / tan(fov / 2.0);
	uh := uw * ratio;
	
	matrix := Matrix4_Identity;
	matrix._11 = uh;
	matrix._22 = uw;
	matrix._33 = -(f + n) / (f - n);
	matrix._34 = -2 * f * n / (f - n);
	matrix._43 = -1;
	return  matrix;
}

simplicial_from_vertex ::(mesh: Mesh, i: u32) -> Simplicial_Complex {
	v := build_vector_list(mesh, i);
	e : [..] float;
	f : [..] float;

	array_resize(*e, mesh.nedge);
	array_resize(*f, mesh.nedge);

	for * e { <<it = 0; }
	for * f { <<it = 0; }

	return make_simplicial(v, e, f);
}

get_color :: (i: int) -> Vector3 {
	return make_vector3(
		fmod(cast(float) i, 100) / 100,
		fmod(cast(float) i, 200) / 200,
		fmod(cast(float) i, 300) / 300
	);
}

projection :: (c: Camera) -> Matrix4 {
	return perspective(
		c.fov / 180 * 3.1415926, cast(float) window_state.height / window_state.width, c.far, c.near
	);
}

ray_from_camera :: (window: Window_State, scene: Scene_State) -> Collision.Ray {
	mouse_x, mouse_y, success := get_mouse_pointer_position(window.handle, true);

	ndc := make_vector2(
		2.0 * mouse_x / (window.width - 0) - 1,
		2.0 * mouse_y / (window.height - 0) - 1
	);
	hcc := make_vector4(ndc.x, ndc.y, 1, 1);
	projection_inv, invertible1 := inverse(projection(scene.camera));
	if !invertible1 return .{};
	ecc := projection_inv * hcc;

	view := look_at_matrix(scene.camera.pos, scene.camera.target);
	view_inv, invertible2 := inverse(view);
	if !invertible2 return .{};
	ray := normalize((view_inv * ecc).xyz);

	pos_offset := (view_inv * make_vector4(0, 0, 1, 0)).xyz;
	pos := scene.camera.pos + pos_offset;

	return Collision.ray(pos, ray);
}



