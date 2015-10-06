-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Shader compilation and setup. Only the most basic features
-- in place, later iterations will maintain multiple shader languages,
-- format descriptor parsing, chaining and loading.

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

shdrtbl["noalpha"] = {
	name = "No Alpha",
	shid = build_shader(nil, frag_noalpha, "noalpha")
};

function shader_setup(wnd, name)
	if (shdrtbl[name] == nil) then
		return;
	end
	image_shader(wnd.canvas, shdrtbl[name].shid);
end

function shader_getkey(name)
	for k,v in pairs(shdrtbl) do
		if (v.name == name) then
			return k;
		end
	end
end

function shader_list()
	local res = {};
	for k,v in pairs(shdrtbl) do
		table.insert(res, v.name);
	end
	return res;
end
