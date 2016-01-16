-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Shader compilation and setup. Only the most basic features
-- in place, later iterations will maintain multiple shader languages,
-- format descriptor parsing, chaining and loading.

-- Usual workaround for the fantastic GLES2 / GL21 precision specification
-- incompatibility.
local old_build = build_shader;
function build_shader(vertex, fragment, label)
	fragment = [[
		#ifdef GL_ES
			#ifdef GL_FRAGMENT_PRECISION_HIGH
				precision highp float;
			#else
				precision mediump float;
			#endif
		#else
			#define lowp
			#define mediump
			#define highp
		#endif
	]] .. fragment;
	return old_build(vertex, fragment, label);
end

local shdrtbl = {};
local frag_noalpha = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

void main(){
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col, obj_opacity);
}
]];

--
-- simple bar spectogram, adapted from guycooks reference at shadertoy
--
local frag_spect = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

#define bars 32.0
#define bar_sz (1.0 / bars)
#define bar_gap (0.1 * bar_sz)

float h2rgb(float h){
	if (h < 0.0)
		h += 1.0;
	if (h < 0.16667)
		return 0.1 + 4.8 * h;
	if (h < 0.5)
		return 0.9;
	if (h < 0.66669)
		return 0.1 + 4.8 * (0.6667 - h);
	return 0.1;
}

vec3 i2c(float i)
{
	float h = 0.6667 - (i * 0.6667);
	return vec3(h2rgb(h + 0.3334), h2rgb(h), h2rgb(h - 0.3334));
}

void main()
{
	if (obj_opacity < 0.01)
		discard;

	vec2 uv = vec2(1.0 - texco.s, 1.0 - texco.t);
	float start = floor(uv.x * bars) / bars;

	if (uv.x - start < bar_gap || uv.x > start + bar_sz - bar_gap){
		gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

/* rather low resolution as we've done no funky "pack float in rgba" trick */
	float intens = 0.0;
	for (float s = 0.0; s < bar_sz; s += bar_sz * 0.02){
		intens += texture2D(map_tu0, vec2(start + s, 0.5)).g;
	}

	intens *= 0.02;
	intens = clamp(intens, 0.005, 1.0);

	float i = float(intens > uv.y);
	gl_FragColor = vec4(i2c(intens) * i, obj_opacity);
}
]];

-- works with autocrop
local frag_clamp = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform float crop_opa;
varying vec2 texco;

void main()
{
	vec4 col = texture2D(map_tu0, texco);
	if (texco.s > 1.0 || texco.t > 1.0)
		gl_FragColor = vec4(0.0, 0.0, 0.0, obj_opacity * crop_opa);
	else
		gl_FragColor = vec4(
			col.r, col.g, col.b, obj_opacity * col.a);
}
]];

shdrtbl["noalpha"] = {
	name = "No Alpha",
	shid = build_shader(nil, frag_noalpha, "noalpha")
};

shdrtbl["fft_spectogram"] = {
	name = "spectogram",
	shid = build_shader(nil, frag_spect, "spectogram"),
	fft = true,
	hidden = true
};

shdrtbl["clamp_black"] = {
	name = "clamp_crop",
	shid = build_shader(nil, frag_clamp, "clamp_crop"),
	hidden = true
};

-- need better management for global config of shader tunables..
shader_uniform(shdrtbl["clamp_black"].shid, "crop_opa",
	"f", PERSIST, gconfig_get("term_opa"));

function shader_setup(wnd, name)
	if (shdrtbl[name] == nil) then
		return;
	end
	image_shader(wnd.canvas, shdrtbl[name].shid);
end

function shader_getkey(name)
	for k,v in pairs(shdrtbl) do
		if (v.name == name) then
			return k, v;
		end
	end
	return name, shdrtbl[name];
end

function shader_list(fltfld)
	local res = {};
	for k,v in pairs(shdrtbl) do
		if (fltfld) then
			for i,j in ipairs(fltfld) do
				if (v[j]) then
					table.insert(res, v.name);
					break;
				end
			end
		elseif (not v.hidden) then
			table.insert(res, v.name);
		end
	end
	return res;
end
