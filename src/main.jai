#import "Basic";
Simp :: #import "Simp";
Input :: #import "Input";
#import "GL";

#import "Window_Creation";

#load "std.jai";

Raylib :: #import "raylib";

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
	camera : Raylib.Camera;

	model : Raylib.Model;
};

window_state : Window_State;
simp_state : Simp_State;

main :: () {
	#if OS == .WINDOWS {
		Windows :: #import "Windows";
		Windows.SetProcessDPIAware();
		Windows.timeBeginPeriod(1);
	}

	Raylib.InitWindow(xx window_state.width, xx window_state.height, "Solide");

	scene : Scene_State;
	scene.camera.position = .{-250, 0, 0};
	scene.camera.target = .{0, 0, 0};
	scene.camera.up = .{0, 1, 0};
	scene.camera.fovy = 60;
	scene.camera.projection = Raylib.CameraProjection.CAMERA_PERSPECTIVE;

	scene.model = Raylib.LoadModel("model.obj");


	mesh := scene.model.meshes;
	colors : [..]u8;
	array_resize(*colors, mesh.vertexCount * 4);

	for 0..mesh.vertexCount-1 {
		colors[it * 4 + 0] = 255;
		colors[it * 4 + 1] = 0;
		colors[it * 4 + 2] = 0;
		colors[it * 4 + 3] = 255;
	}

	mesh.colors = colors.data;
	Raylib.UnloadMesh(mesh);
	Raylib.UploadMesh(mesh, true);

	println("%", <<scene.model.meshes);

	Raylib.SetCameraMode(scene.camera, .CAMERA_THIRD_PERSON);

	while !Raylib.WindowShouldClose() {
		update(*scene);
		render(*scene);

		reset_temporary_storage();
	}
}

update :: (scene: *Scene_State) {
	Raylib.UpdateCamera(*scene.camera);
}

render :: (scene: *Scene_State) {
	Raylib.BeginDrawing();
	Raylib.ClearBackground(Raylib.DARKGRAY);

	{
		Raylib.BeginMode3D(scene.camera);
		defer Raylib.EndMode3D();

		Raylib.DrawCube(.{2.5, 0, 0}, 5, 0.5, 0.5, .{255, 0, 0, 255});
		Raylib.DrawCube(.{0, 2.5, 0}, 0.5, 5, 0.5, .{0, 255, 0, 255});
		Raylib.DrawCube(.{0, 0, 2.5}, 0.5, 0.5, 5, .{0, 0, 255, 255});
		Raylib.DrawModel(scene.model, .{0, 0, 0}, 1, Raylib.RAYWHITE);
	}

	Raylib.DrawText("Test", 20, 20, 10, Raylib.BLACK);

	Raylib.EndDrawing();
}