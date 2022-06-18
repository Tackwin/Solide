#scope_file
#import "GL";
#import "Basic";
#import "Math";
#import "src/shader";


arrow_vao : u32 = xx 0xFFFFFFFF;
arrow_vbo : u32 = xx 0xFFFFFFFF;
arrow_ibo : u32 = xx 0xFFFFFFFF;
arrow_ebo : u32 = xx 0xFFFFFFFF;

VertexData :: struct {
	pos: Vector3;
	normal: Vector3;
};
InstanceData :: struct {
	model: Matrix4;
	color: Vector3;
};

ARROW_FRAG :: #string FRAG
#version 410 core
layout (location = 0) in vec3 color;

out vec4 frag_color;

void main() {
	frag_color = vec4(color, 1.0);
}
FRAG

ARROW_VERT :: #string VERT
#version 410 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in mat4 model;
layout (location = 6) in vec3 color;

uniform mat4 vp;
uniform int is_lit;
uniform float tip_ratio;

layout (location = 0) out vec3 frag_color;

void main() {
	frag_color = color;

	vec3 local_pos = pos;

	if (pos.x > 0 && pos.x < 1) {
		local_pos.x = tip_ratio;
	}

	gl_Position = vec4(local_pos, 1.0) * model * vp;
}
VERT

arrow_shader: Shader;
arrow_instances : [..] InstanceData;
arrow_vertices : [..] VertexData;
arrow_indices : [..] u8;

init_arrow :: () {
	glGenVertexArrays(1, *arrow_vao);
	glGenBuffers(1, *arrow_vbo);
	glGenBuffers(1, *arrow_ibo);
	glGenBuffers(1, *arrow_ebo);

	array_add(*arrow_vertices, VertexData.{ Vector3.{1, 0, 0}, Vector3.{1, 0, 0} });

	for 0..5 {
		v: VertexData;
		v.pos.x = 0.5;
		v.pos.y = 1.0 * cos(2 * PI * it / 6);
		v.pos.z = 1.0 * sin(2 * PI * it / 6);

		v.normal.x = 0;
		v.normal.y = cos(2 * PI * it / 6);
		v.normal.z = sin(2 * PI * it / 6);

		array_add(*arrow_vertices, v);
	}
	
	for 0..5 {
		v: VertexData;
		v.pos.x = 0.5;
		v.pos.y = 0.5 * cos(2 * PI * it / 6);
		v.pos.z = 0.5 * sin(2 * PI * it / 6);

		v.normal.x = 0;
		v.normal.y = cos(2 * PI * it / 6);
		v.normal.z = sin(2 * PI * it / 6);

		array_add(*arrow_vertices, v);
	}

	
	for 0..5 {
		v: VertexData;
		v.pos.x = 0;
		v.pos.y = 0.5 * cos(2 * PI * it / 6);
		v.pos.z = 0.5 * sin(2 * PI * it / 6);

		v.normal.x = 0;
		v.normal.y = cos(2 * PI * it / 6);
		v.normal.z = sin(2 * PI * it / 6);

		array_add(*arrow_vertices, v);
	}

	array_add(*arrow_vertices, .{ Vector3.{0, 0, 0}, Vector3.{-1, 0, 0}});

	for 0..5 array_add(*arrow_indices, xx 0, xx (1 + it), xx (1 + (1 + it) % 6));

	for 0..5 {
		array_add(*arrow_indices, xx (1 + it), xx (7 + it), xx (7 + (1 + it) % 6));
		array_add(*arrow_indices, xx (1 + it), xx (7 + (1 + it) % 6), xx (1 + (1 + it) % 6));
	}

	for 0..5 {
		array_add(*arrow_indices, xx (7 + it), xx (13 + it), xx (13 + (1 + it) % 6));
		array_add(*arrow_indices, xx (7 + it), xx (13 + (1 + it) % 6), xx (7 + (1 + it) % 6));
	}

	for 0..5 array_add(*arrow_indices, xx (13 + it), xx 19, xx (13 + (it + 1) % 6));


	
	glBindVertexArray(arrow_vao);
	glBindBuffer(GL_ARRAY_BUFFER, arrow_vbo);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(VertexData), xx 0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(VertexData), xx 12);
	glBindBuffer(GL_ARRAY_BUFFER, arrow_ibo);
	glEnableVertexAttribArray(2);
	glEnableVertexAttribArray(3);
	glEnableVertexAttribArray(4);
	glEnableVertexAttribArray(5);
	glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, size_of(InstanceData), xx 0);
	glVertexAttribPointer(3, 4, GL_FLOAT, GL_FALSE, size_of(InstanceData), xx 16);
	glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, size_of(InstanceData), xx 32);
	glVertexAttribPointer(5, 4, GL_FLOAT, GL_FALSE, size_of(InstanceData), xx 48);
	glEnableVertexAttribArray(6);
	glVertexAttribPointer(6, 3, GL_FLOAT, GL_FALSE, size_of(InstanceData), xx 60);
	for 2..6 glVertexAttribDivisor(xx it, 1);

	glBindBuffer(GL_ARRAY_BUFFER, arrow_vbo);
	glBufferData(
		GL_ARRAY_BUFFER,
		size_of(VertexData) * arrow_vertices.count,
		arrow_vertices.data,
		GL_STATIC_DRAW
	);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, arrow_ebo);
	glBufferData(
		GL_ELEMENT_ARRAY_BUFFER,
		size_of(u8) * arrow_indices.count,
		arrow_indices.data,
		GL_STATIC_DRAW
	);

	arrow_shader = shader_init(ARROW_VERT, ARROW_FRAG);
}

#scope_export

arrow :: (
	a: Vector3, b: Vector3, r: float, color: Vector3, VP: Matrix4, tip_ratio := 0.1, lit := false
) {
	if (arrow_vao == 0xFFFFFFFF) init_arrow();

	x := normalize(b - a, fallback=.{1, 0, 0});
	y := normalize(cross(x, .{0, 0, 1}), fallback=.{0, 1, 0});
	z := normalize(cross(x, y), fallback=.{0, 0, 1});
	x *= length(b - a);
	y *= r;
	z *= r;

	model := make_matrix_from_columns(x, y, z);
	model._14 = a.x;
	model._24 = a.y;
	model._34 = a.z;

	instances : InstanceData;
	instances.model = model;
	instances.color = color;

	glBindBuffer(GL_ARRAY_BUFFER, arrow_ibo);
	glBufferData(GL_ARRAY_BUFFER, size_of(InstanceData), *instances, GL_DYNAMIC_DRAW);

	set_uniform(arrow_shader, "vp", VP);
	set_uniform(arrow_shader, "is_lit", lit);
	set_uniform(arrow_shader, "tip_ratio", 1 - tip_ratio);

	glBindVertexArray(arrow_vao);
	glUseProgram(arrow_shader.program);
	glBindBuffer(GL_ARRAY_BUFFER, arrow_vbo);
	glDrawElementsInstanced(GL_TRIANGLES, xx arrow_indices.count, GL_UNSIGNED_BYTE, xx 0, 1);
}

Arrow :: struct {
	a: Vector3;
	b: Vector3;
	r: float;
	color: Vector3;
};

arrows :: (arrow_instance: []Arrow, VP: Matrix4, tip_ratio := 0.1, lit := false) {
	if (arrow_vao == 0xFFFFFFFF) init_arrow();


	instances := NewArray(arrow_instance.count, InstanceData, allocator=temp);
	for arrow_instance {
		x := normalize(it.b - it.a, fallback=.{1, 0, 0});
		y := normalize(cross(x, .{0, 0, 1}), fallback=.{0, 1, 0});
		z := normalize(cross(x, y), fallback=.{0, 0, 1});
		x *= length(it.b - it.a);
		y *= it.r;
		z *= it.r;

		model := make_matrix_from_columns(x, y, z);
		model._14 = it.a.x;
		model._24 = it.a.y;
		model._34 = it.a.z;

		instances[it_index].model = model;
		instances[it_index].color = it.color;
	}

	glBindBuffer(GL_ARRAY_BUFFER, arrow_ibo);
	glBufferData(
		GL_ARRAY_BUFFER, size_of(InstanceData) * instances.count, instances.data, GL_DYNAMIC_DRAW
	);

	set_uniform(arrow_shader, "vp", VP);
	set_uniform(arrow_shader, "is_lit", lit);
	set_uniform(arrow_shader, "tip_ratio", 1 - tip_ratio);

	glBindVertexArray(arrow_vao);
	glUseProgram(arrow_shader.program);
	glBindBuffer(GL_ARRAY_BUFFER, arrow_vbo);
	glDrawElementsInstanced(
		GL_TRIANGLES, xx arrow_indices.count, GL_UNSIGNED_BYTE, xx 0, xx instances.count
	);
}