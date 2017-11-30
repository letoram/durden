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

local function run_destr_eval(evalf, wm, wnd, space, space_active, popup)
	if (not space_active or popup) then
		return;
	end

	flair_supp_segment(wnd,
		wnd.effective_w < 100 and wnd.effective_w * 0.3 or wnd.effective_w * 0.15,
		wnd.effective_h < 100 and wnd.effective_h * 0.3 or wnd.effective_h * 0.15,
	evalf);
end

local function falling(vid, speed, cx, cy, cw, ch, ox, oy, sx, sy, sw, sh)
	local rx = ox - cx;
	local ry = oy - cy;
	local dist = 0.00001 + math.sqrt(rx*rx+ry*ry);

	local mx = sw - ox;
	local my = sw - oy;
	local maxdist = 0.00001 + math.sqrt(sw * sw + sh * sh);

-- initial delay is proportional to the distance from the epicentrum
-- manipulating these transformations and delays really defines the
-- effect, be creative :)
	local fact = dist / maxdist;
	local delay = fact * (0.5 * speed);
	move_image(vid, cx, cy, delay);
	resize_image(vid, cw, ch, delay);
	rotate_image(vid, 0, delay + delay * 0.1);
	blend_image(vid, 1.0, delay);

	local ifun = INTERP_EXPOUT;
-- have each piece travel the same distance so the speed will match
	move_image(vid, cx+8, cy+8, speed, ifun);
	resize_image(vid, 16, 16, speed, ifun);
	rotate_image(vid, math.random(359), speed, ifun);
	blend_image(vid, 0.0, speed, ifun);
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
	end,
	splitfade = function(...)
		run_destr_eval(falling, ...);
	end
};
