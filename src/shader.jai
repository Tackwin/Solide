#scope_file
#import "Basic";
#import "GL";
#import "Math";
#import "src/std";

#scope_export

FRAG :: #string FRAG
#version 410 core
layout (location = 0) in vec3 color;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec4 pos;

out vec4 frag_color;

vec3 light_pos = vec3(10, 10, 10);

void main() {
	vec3 light_dir = normalize(light_pos - pos.xyz);
	float diff = max(dot(normal, light_dir), 0.2);

	frag_color = vec4(diff * color, 1.0);
}
FRAG

VERT :: #string VERT
#version 410 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 color;
layout (location = 2) in vec3 normal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

layout (location = 0) out vec3 frag_color;
layout (location = 1) out vec3 frag_normal;
layout (location = 2) out vec4 frag_pos;

void main() {
	frag_color = color;
	frag_pos = vec4(pos, 1.0) * model;
	frag_normal = (vec4(normal, 0.0) * model).xyz;
	gl_Position = frag_pos * view * projection;
}
VERT

Shader :: struct {
	vertex   : u32 = 0;
	fragment : u32 = 0;
	program  : u32 = 0;
};

shader_init :: () -> Shader { return shader_init(VERT, FRAG); }
shader_init :: (vert: string, frag: string) -> Shader {
	shader : Shader;
	source : [1] *u8;
	source[0] = vert.data;

	shader.vertex = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(shader.vertex, 1, source.data, null);
	glCompileShader(shader.vertex);

	success : s32;
	glGetShaderiv(shader.vertex, GL_COMPILE_STATUS, *success);
	if !success {
		build_log : [1024] u8;
		glGetShaderInfoLog(shader.vertex, build_log.count, null, build_log.data);

		build_log_str : string;
		build_log_str.data = build_log.data;
		build_log_str.count = 1024;
		println("Error compiling vertex shader \n %", build_log_str);
		return .{};
	}
	
	source[0] = frag.data;
	shader.fragment = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(shader.fragment, 1, source.data, null);
	glCompileShader(shader.fragment);

	glGetShaderiv(shader.fragment, GL_COMPILE_STATUS, *success);
	if !success {
		build_log : [1024] u8;
		glGetShaderInfoLog(shader.fragment, build_log.count, null, build_log.data);

		build_log_str : string;
		build_log_str.data = build_log.data;
		build_log_str.count = 1024;
		println("Error compiling fragment shader \n %", build_log_str);
		return .{};
	}

	shader.program = glCreateProgram();
	glAttachShader(shader.program, shader.vertex);
	glAttachShader(shader.program, shader.fragment);
	glLinkProgram(shader.program);

	glGetProgramiv(shader.program, GL_LINK_STATUS, *success);
	if !success {
		build_log : [1024] u8;
		glGetShaderInfoLog(shader.fragment, build_log.count, null, build_log.data);

		build_log_str : string;
		build_log_str.data = build_log.data;
		build_log_str.count = 1024;
		println("Error linking shader \n %", build_log_str);
		return .{};
	}

	glDeleteShader(shader.vertex);
	glDeleteShader(shader.fragment);
	return shader;
}

set_uniform :: (using shader: Shader, name: string, mat: Matrix4) {
	glUseProgram(program);
	loc := glGetUniformLocation(program, name.data);
	glUniformMatrix4fv(loc, 1, false, cast(*float) *mat);
}
set_uniform :: (using shader: Shader, name: string, mat: Vector3) {
	glUseProgram(program);
	loc := glGetUniformLocation(program, name.data);
	glUniform3fv(loc, 1, cast(*float) *mat);
}
set_uniform :: (using shader: Shader, name: string, value: bool) {
	glUseProgram(program);
	loc := glGetUniformLocation(program, name.data);
	glUniform1ui(loc, xx (ifx value then 1 else 0));
}
set_uniform :: (using shader: Shader, name: string, value: float) {
	glUseProgram(program);
	loc := glGetUniformLocation(program, name.data);
	glUniform1f(loc, value);
}