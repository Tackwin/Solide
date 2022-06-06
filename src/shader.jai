#scope_file
#import "Basic";
#import "GL";
#import "Math";
#import "src/std";

#scope_export

FRAG :: #string FRAG
#version 410 core
layout (location = 0) in vec3 color;

out vec4 frag_color;

void main() {
	frag_color = vec4(color, 1.0);
}
FRAG

VERT :: #string VERT
#version 410 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 color;

uniform mat4 view;
uniform mat4 projection;

layout (location = 0) out vec3 frag_color;

void main() {
	frag_color = color;
	gl_Position = vec4(pos, 1.0) * view * projection;
}
VERT

Shader :: struct {
	vertex   : u32 = 0;
	fragment : u32 = 0;
	program  : u32 = 0;
};

shader_init :: () -> Shader {
	shader : Shader;
	source : [1] *u8;
	source[0] = VERT.data;

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
	
	source[0] = FRAG.data;
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