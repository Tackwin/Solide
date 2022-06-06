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
MKL :: #import "src/mkl";
Geometry :: #import "src/geometry";
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

Scene_State :: struct {
	z_down : bool = false;
	s_down : bool = false;
	d_down : bool = false;
	q_down : bool = false;

	shader : Shader;
	mesh   : Mesh;

	selected_point : s64 = -1;

	run := false;

	camera_speed := 1.5;
	camera_pos : Vector3;
	camera_target : Vector3;
};

Ui_State :: struct {
	reset_visible := false;
	run_star := false;
	run_closure := false;
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
	scene.mesh   = load_mesh("model.obj");
	scene.camera_pos    = .{ 1, 0, 1 };
	scene.camera_target = .{ 0, 0, 0 };

	scene.mesh.A0 = build_vertex_edge_adjacency_matrix(scene.mesh);
	scene.mesh.A1 = build_edge_face_adjacency_matrix(scene.mesh);

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
			}
		}
		if scene.mesh.nvert > 0 then scene.selected_point %= scene.mesh.nvert;
		else                         scene.selected_point = -1;
		scene.selected_point = max(scene.selected_point, -1);

		update(*scene, *ui, dt);
		render(*scene, *ui);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State, ui: *Ui_State, dt: float) {

	scene.camera_target = .{ 0, 0, 0 };
	
	if scene.selected_point >= 0 {
		scene.camera_target = scene.mesh.vertices[scene.selected_point];
	}
	scene.camera_pos.z = scene.camera_target.z + 1;

	delta := scene.camera_pos - scene.camera_target;
	theta := atan2(delta.y, delta.x);
	l : float = 0;
	l += delta.x * delta.x;
	l += delta.y * delta.y;
	l = sqrt(l);

	if scene.q_down theta += scene.camera_speed * dt;
	if scene.d_down theta -= scene.camera_speed * dt;
	if scene.z_down l += 20 * scene.camera_speed * dt;
	if scene.s_down l -= 20 * scene.camera_speed * dt;
	
	scene.camera_pos.x = scene.camera_target.x + cos(theta) * l;
	scene.camera_pos.y = scene.camera_target.y + sin(theta) * l;

	if (ui.run_star || ui.run_closure) && scene.selected_point < 0 {
		println("Error select a point");
	}

	if ui.run_star && scene.selected_point >= 0 {
		print("Star");
		vec := build_vector_list(scene.mesh, xx scene.selected_point);
		star_edge, star_face := vertex_star(vec, scene.mesh);

		defer {
			array_free(vec);
			array_free(star_edge);
			array_free(star_face);
		}

		for star_edge if it > 0 {
			scene.mesh.edge_visible[it_index] = true;
		}
		for star_face if it > 0 {
			scene.mesh.face_colors[it_index] = .{1, 1, 1};
		}
	}
	if ui.run_closure && scene.selected_point >= 0 {
		print("Closure");
		vec := build_vector_list(scene.mesh, xx scene.selected_point);
		vertices, edges, faces := vertex_closure(vec, scene.mesh);
		defer {
			array_free(vertices);
			array_free(edges);
			array_free(faces);
		}

		for vertices if it > 0 {
			scene.mesh.vertex_visible[it_index] = true;
		}
		for edges if it > 0 {
			scene.mesh.edge_visible[it_index] = true;
		}
		for faces if it > 0 {
			scene.mesh.face_colors[it_index] = .{1, 1, 1};
		}
	}

	if ui.reset_visible {
		print("Reset");
		for * scene.mesh.vertex_visible { <<it = false; }
		for * scene.mesh.edge_visible { <<it = false; }
		for * scene.mesh.face_colors {
			c := make_vector3(
				random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()
			);
			<<it = c;
		}
	}

	{
		old := false;
		if scene.selected_point >= 0 old = scene.mesh.vertex_visible[scene.selected_point];
		if scene.selected_point >= 0 scene.mesh.vertex_visible[scene.selected_point] = true;
		update_gpu_data(*scene.mesh);
		if scene.selected_point >= 0 scene.mesh.vertex_visible[scene.selected_point] = old;
	}
}

render :: (scene: *Scene_State, ui: *Ui_State) {
	glClearColor(.15, .08, .08, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	// glDepthMask(GL_TRUE);
	glEnable(GL_DEPTH_TEST);
	view := look_at_matrix(scene.camera_pos, scene.camera_target);
	projection := perspective(1.0, cast(float) window_state.height / window_state.width, 500, 0.01);
	set_uniform(scene.shader, "view", view);
	set_uniform(scene.shader, "projection", projection);

	render(scene.mesh, scene.shader);
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

	pad : float = 10;
	k := window_state.height * 0.05;
	r := GetRect.get_rect(pad, pad, 3*k, k);

	ui.reset_visible = GetRect.button(r, "Reset", *theme.button_theme);
	r.y += k + pad;

	ui.run_star = GetRect.button(r, "Run star", *theme.button_theme);
	r.y += k + pad;

	ui.run_closure = GetRect.button(r, "Run closure", *theme.button_theme);
	r.y += k + pad;

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