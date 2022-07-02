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

#import "src/app";
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

window_state : Window_State;
simp_state : Simp_State;

#placeholder trigger_routines;
#placeholder compute_routines;

load :: (path: string, scene: *Scene_State) {
	free(scene.mesh);
	free(scene.half_mesh);
	array_free(scene.vertex_normals);
	array_free(scene.heat);
	
	scene.mesh   = load_mesh(path);
	scene.half_mesh = construct_half_mesh(scene.mesh);
	build_matrices(scene.half_mesh, *scene.mesh);

	// init Simplicial.
	array_resize(*scene.selected_simplicial.vertices, scene.mesh.vertices.count);
	array_resize(*scene.selected_simplicial.edges, scene.mesh.edges.count);
	array_resize(*scene.selected_simplicial.faces, scene.mesh.faces.count);
	for * scene.selected_simplicial.vertices { <<it = 0; }
	for * scene.selected_simplicial.edges { <<it = 0; }
	for * scene.selected_simplicial.faces { <<it = 0; }

	scene.heat = NewArray(scene.mesh.nvert, float);
	for * scene.heat { <<it = 0; };
}

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
	load("input/ico.obj", *scene);

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
				if ui.popup_load_mesh && it.key_pressed && it.key_code == .ENTER    then {
					load(tprint("input/%.obj", ui.load_input), *scene);
					ui.popup_load_mesh = false;
				}
				if ui.eat_event continue;
				if it.key_code == #char "Z" then scene.z_down = xx it.key_pressed;
				if it.key_code == #char "S" then scene.s_down = xx it.key_pressed;
				if it.key_code == #char "Q" then scene.q_down = xx it.key_pressed;
				if it.key_code == #char "D" then scene.d_down = xx it.key_pressed;
				if it.key_pressed && it.key_code == .SPACEBAR then scene.run = true;
				if it.key_pressed && it.key_code == #char "I" then ui.popup_load_mesh |= true;

				mouse_left\_can_be_pressed := !scene.mouse_left\_down;
				mouse_right_can_be_pressed := !scene.mouse_right_down;

				if it.key_code == .MOUSE_BUTTON_RIGHT scene.mouse_right_down = it.key_pressed > 0;
				if it.key_code == .MOUSE_BUTTON_LEFT  scene.mouse_left_down  = it.key_pressed > 0;

				scene.mouse_left\_pressed = mouse_left\_can_be_pressed && scene.mouse_left\_down;
				scene.mouse_right_pressed = mouse_right_can_be_pressed && scene.mouse_right_down;


			}
		}

		render(*scene, *ui);
		update(*scene, *ui, dt);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State, ui: *Ui_State, dt: float) {
	T += dt;
	scene.camera.target = .{ 0, 0, 0 };
	
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


	for compute_routines it(ui, scene);
	if ui.scale_up        scene.scale_factor *= 1.5;
	if ui.scale_down      scene.scale_factor /= 1.5;
	if ui.reset_normals   scene.vertex_normals.count = 0;
	if ui.toggle_rotation scene.unit_vector_rotating_time += dt;

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
		update_gpu_data(*scene.mesh, ui.show_vertex_interpolated, scene.vertex_normals);
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

	transformed_vertices := NewArray(scene.mesh.vertices.count, Vector3, allocator=temp);
	for * transformed_vertices {
		<<it = (scene.model_matrix * make_vector4(scene.mesh.vertices[it_index], 1.0)).xyz;
	}

	for scene.mesh.faces {
		tri.a = transformed_vertices[it.x];
		tri.b = transformed_vertices[it.y];
		tri.c = transformed_vertices[it.z];

		t, hit := Collision.triangle_ray_t(tri, ray);
		if hit && t_tri > t {
			t_tri = t;
			tri_idx = it_index;
		}
	}
	for scene.mesh.edges {
		cap.a = transformed_vertices[it.a];
		cap.b = transformed_vertices[it.b];

		t, hit := Collision.capsule_ray_t(cap, ray);
		if hit && t_cap > t {
			t_cap = t;
			edg_idx = it_index;
		}
	}
	for transformed_vertices {
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

	render(scene.mesh, scene.shader, scene);

	if ui.show_half_edges {
		instances := NewArray(scene.half_mesh.half_edges.count, Render.Arrow, allocator=temp);
		for scene.half_mesh.half_edges {
			a := scene.mesh.vertices[it.vertex];
			b := scene.mesh.vertices[scene.half_mesh.half_edges[it.next].vertex];

			c := mean(it.face, scene.mesh);

			a = c + (a - c) * 0.9;
			b = c + (b - c) * 0.9;

			instances[it_index].a = (scene.model_matrix * make_vector4(a, 1.0)).xyz;
			instances[it_index].b = (scene.model_matrix * make_vector4(b, 1.0)).xyz;
			instances[it_index].r = area(it.face, scene.mesh) * scene.scale_factor;
			instances[it_index].color = .{1, 1, 1};
		}
		Render.arrows(instances, proj * view, tip_ratio=0.3);
	}
	if ui.show_normals {
		instances := NewArray(scene.vertex_normals.count, Render.Arrow, allocator=temp);
		for scene.vertex_normals {
			a := scene.mesh.vertices[it_index];
			b := a + it * 0.025;

			instances[it_index].a = (scene.model_matrix * make_vector4(a, 1.0)).xyz;
			instances[it_index].b = (scene.model_matrix * make_vector4(b, 1.0)).xyz;
			instances[it_index].r = 0.002;
			instances[it_index].color = .{1, 1, 1};
		}
		Render.arrows(instances, proj * view, tip_ratio=0.1);
	}
	if ui.show_arrows {
		instances := NewArray(scene.face_arrows.count, Render.Arrow, allocator=temp);
		max_t := -FLOAT32_MAX;
		for scene.face_arrows max_t = max(max_t, length(it));
		
		for scene.face_arrows {
			r := sqrt(length(it) / max_t) * 0.1;
			a := sqrt(area(it_index, scene.mesh)) * 3;
			instances[it_index].a = mean(it_index, scene.mesh);
			instances[it_index].b = instances[it_index].a + normalize(it) * r;
			instances[it_index].r = 0.004;
			instances[it_index].color = .{1, 1, 1};
		}
		Render.arrows(instances, proj * view, tip_ratio=0.2);
	}
	// Render.arrows(samples, proj * view, tip_ratio= 0.8 * sin(T) * sin(T) + 0.1);

	render_ui(scene, ui);

	Simp.swap_buffers(window_state.handle);
}

render :: (mesh: Mesh, shader: Shader, scene: *Scene_State) {
	glUseProgram(shader.program);
	set_uniform(shader, "model", scene.model_matrix);
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
		r.y -= k + pad;

		for trigger_routines {
			ui.eat_event |= it(ui, *r);
			r.y -= pad;
		}
		r.y -= k + pad;
	}

	if ui.popup_load_mesh
	{
		r := GetRect.get_rect(window_state.width/2 - 3*k, 14.5*k, 6*k, 1*k);
		action, text, state :=
			GetRect.text_input(r, "", *theme.text_input_theme, input_action=.ACTIVATE);
		ui.load_input = state.text;
		ui.eat_event |= state.active;
	}


	GetRect.draw_popups();
}

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



