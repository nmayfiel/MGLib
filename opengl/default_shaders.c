
const char *shader_source_vertex = "					\
#version 330 core										\
														\
layout(location = 0) in vec3 in_position;				\
layout(location = 1) in vec2 in_uv;						\
layout(location = 2) in vec4 in_color;					\
uniform mat4 in_projection;								\
out vec2 frag_uv;										\
out vec4 frag_color;									\
														\
void main()												\
{														\
    frag_uv = in_uv;									\
    frag_color = in_color;								\
	mat4 proj = in_projection;							\
    gl_Position = proj * vec4(in_position, 1); 			\
}														\
";

const char *shader_source_fragment = "					\
#version 330 core										\
														\
uniform float in_time;									\
in vec2 frag_uv;										\
in vec4 frag_color;										\
out vec4 outColor;										\
														\
void main()												\
{														\
    outColor = frag_color;					   			\
}														\
";

const char *tex_shader_source_fragment = "				\
#version 330 core										\
														\
uniform sampler2D texture_sample;						\
uniform float in_time;									\
in vec2 frag_uv;										\
in vec4 frag_color;										\
out vec4 outColor;										\
														\
void main()												\
{														\
	vec4 txc = texture(texture_sample, frag_uv); 		\
	if (txc.a > 0)										\
	{													\
		outColor = mix(txc, frag_color, frag_color.a);	\
	}													\
	else												\
	{													\
		discard;										\
	}													\
}														\
";

const char *flashing_tex_shader_source_fragment = "				\
#version 330 core												\
																\
uniform sampler2D texture_sample;								\
uniform float in_time;								   			\
in vec2 frag_uv;												\
in vec4 frag_color;												\
out vec4 outColor;												\
																\
void main()														\
{																\
	float tim = 0.5 + 0.5 * sin(in_time * 10.0);	   			\
	vec4 txc = texture(texture_sample, frag_uv); 				\
	if (txc.a > 0)												\
	{															\
		outColor = mix(txc, frag_color, frag_color.a * tim);	\
	}															\
	else														\
	{															\
		discard;												\
	}															\
}																\
";


