local destroy_shid;

local shaders = {
-- a more ambitious version would use a LUT to give a perlin-noise
-- like distribution, weight that with the contents and the distance
-- to the last known mouse cursor position, with an edge gradient
-- using yellow-red-blacks for the burn.
dissolve = {nil, nil, [[
uniform sampler2D map_tu0;
varying vec2 texco;
uniform float trans_blend;

void main()
{
	vec4 col = texture2D(map_tu0, texco);
	float intens = (col.r + col.g + col.b) / 3.0;
	if (intens < trans_blend)
		discard;
	col.a = 1.0;
	gl_FragColor = col;
}

]], "destroy_burn"
},
};

-- on-demand compile shaders
local function synch_shader(key)
	local sk = shaders[key];
	assert(sk);

	if (sk[1]) then
		return sk[1];
	else
		sk[1] = build_shader(sk[2], sk[3], sk[4]);
		return sk[1];
	end
end

-- generic runner for creating a canvas copy and dispatching a
-- shader, can be re-used for all effects that don't require special
-- details like window specific uniforms
local function run_shader(key, wm, wnd, space, space_active, popup)
	if (not space_active) then
		return;
	end

	local vid = flair_supp_clone(wnd);
	if (valid_vid(vid)) then
		blend_image(vid, 0.0, gconfig_get("flair_speed"));
		image_shader(vid, synch_shader("dissolve"));
	end
end

return {
	dissolve = function(...)
		run_shader("dissolve", ...);
	end
};
