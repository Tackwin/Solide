#import "Basic";
Simp :: #import "Simp";
Input :: #import "Input";
#import "GL";

#import "Window_Creation";

#load "std.jai";
#load "mesh.jai";
#load "shader.jai";

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

	camera_speed := 1.5;
	camera_pos : Vector3;
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
	scene.camera_pos.x = 1;
	scene.camera_pos.y = 0;
	scene.camera_pos.z = 1;

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
			}
		}

		update(*scene, dt);
		render(*scene);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State, dt: float) {
	theta := atan2(scene.camera_pos.y, scene.camera_pos.x);
	l : float = 0;
	l += scene.camera_pos.x * scene.camera_pos.x;
	l += scene.camera_pos.y * scene.camera_pos.y;
	l = sqrt(l);

	if scene.q_down theta += scene.camera_speed * dt;
	if scene.d_down theta -= scene.camera_speed * dt;
	if scene.z_down l += 20 * scene.camera_speed * dt;
	if scene.s_down l -= 20 * scene.camera_speed * dt;

	scene.camera_pos.x = cos(theta) * l;
	scene.camera_pos.y = sin(theta) * l;
}

render :: (scene: *Scene_State) {
	glClearColor(.15, .08, .08, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glEnable(GL_DEPTH_TEST);
	view := look_at_matrix(scene.camera_pos, .{0, 0, 0});
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

	rotation := make_matrix_from_rows(x, y, z);

	// translation := Matrix4_Identity;
	// rotation._14 = -viewpoint.x;
	// rotation._24 = -viewpoint.y;
	// rotation._34 = -viewpoint.z;
	// result := rotation * translation;
	result := translate(rotation, -viewpoint);

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