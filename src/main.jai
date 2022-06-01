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
	d_down : bool = false;
	q_down : bool = false;

	shader : Shader;
	mesh   : Mesh;

	camera_speed := 0.5;
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
	scene.camera_pos.x = 0;
	scene.camera_pos.y = 100;
	scene.camera_pos.z = -100;

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

	if scene.q_down theta += scene.camera_speed * dt;
	if scene.d_down theta -= scene.camera_speed * dt;

	l := scene.camera_pos.x * scene.camera_pos.x + scene.camera_pos.y * scene.camera_pos.y;
	l = sqrt(l);

	scene.camera_pos.x = cos(theta) * l;
	scene.camera_pos.y = sin(theta) * l;
}

render :: (scene: *Scene_State) {
	glClearColor(.15, .08, .08, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glEnable(GL_DEPTH_TEST);
	view := make_look_at_matrix(scene.camera_pos, .{0, 0, 0}, .{0, 0, 1});
	projection := orthographic_projection_matrix(0, 300, -100, 100, -100, 100);
	vp := projection * view;
	set_uniform(scene.shader, "viewProjection", vp);

	render(scene.mesh, scene.shader);

	Simp.swap_buffers(window_state.handle);
}

render :: (mesh: Mesh, shader: Shader) {
	glUseProgram(shader.program);
	glBindVertexArray(mesh.vao);
	glDrawElements(GL_TRIANGLES, xx (mesh.faces.count * 3), GL_UNSIGNED_INT, xx 0);
}