
#import "Basic";
Simp :: #import "Simp";
Input :: #import "Input";
#import "GL";

#import "Window_Creation";

#load "std.jai";
#load "mesh.jai";
#load "shader.jai";
MKL :: #import "src/mkl";

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

	scene : Scene_State;
	scene.shader = shader_init();
	scene.mesh   = load_mesh("model.obj");
	scene.camera_pos    = .{ 1, 0, 1 };
	scene.camera_target = .{ 0, 0, 0 };

	scene.mesh.A0 = build_vertex_edge_adjacency_matrix(scene.mesh);
	scene.mesh.A1 = build_edge_face_adjacency_matrix(scene.mesh);

	timer := current_time_monotonic();	

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
				if it.key_code == #char "E" then scene.selected_point += 1;
				if it.key_code == #char "A" then scene.selected_point -= 1;
				if it.key_code == #char "R" then scene.selected_point = -1;
				if it.key_code == .SPACEBAR then scene.run = true;
			}
		}
		if scene.mesh.nvert > 0 then scene.selected_point %= scene.mesh.nvert;
		else                         scene.selected_point = -1;
		scene.selected_point = max(scene.selected_point, -1);

		update(*scene, dt);
		render(*scene);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State, dt: float) {

	for * scene.mesh.vertex_visible { <<it = false; }
	scene.camera_target = .{ 0, 0, 0 };
	if scene.selected_point > 0 {
		scene.mesh.vertex_visible[scene.selected_point] = true;
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

	if scene.run && scene.selected_point < 0 {
		println("Error select a point");
	}
	if scene.run && scene.selected_point > 0 {
		vec := build_vector_list(scene.mesh, xx scene.selected_point);
		closure_edge := MKL.mul(scene.mesh.A0, vec);
		closure_face := MKL.mul(scene.mesh.A1, closure_edge);

		for closure_edge if it > 0 {
			scene.mesh.edge_visible[it_index] = true;
		}
		for closure_face if it > 0 {
			scene.mesh.face_colors[it_index] = .{1, 1, 1};
		}
	}

	update_gpu_data(*scene.mesh);
}

render :: (scene: *Scene_State) {
	glClearColor(.15, .08, .08, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glEnable(GL_DEPTH_TEST);
	view := look_at_matrix(scene.camera_pos, scene.camera_target);
	projection := perspective(1.0, cast(float) window_state.height / window_state.width, 500, 0.01);
	set_uniform(scene.shader, "view", view);
	set_uniform(scene.shader, "projection", projection);

	render(scene.mesh, scene.shader);

	Simp.swap_buffers(window_state.handle);
}

render :: (mesh: Mesh, shader: Shader) {
	glUseProgram(shader.program);
	glBindVertexArray(mesh.vao);
	glDrawArrays(GL_TRIANGLES, xx 0, xx mesh.cpu_buffer.count);
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