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
	if (intens < trans_blend + 0.02){
		col.r = 1.0;
		col.g = 0.5;
		col.b = 0.0;
	}

	col.a = 1.0;
	gl_FragColor = col;
}

]], "destroy_burn"
},
};

local flame = build_shader(nil, [[
uniform sampler2D map_tu0;
varying vec2 texco;
uniform float trans_blend;

float hash2D(vec2 x) {
	return fract(sin(dot(x, vec2(13.454, 7.405)))*12.3043);
}

float voronoi2D(vec2 uv) {
	vec2 fl = floor(uv);
	vec2 fr = fract(uv);
	float res = 1.0;
	for( int j=-1; j<=1; j++ ) {
		for( int i=-1; i<=1; i++ ) {
			vec2 p = vec2(i, j);
			float h = hash2D(fl+p);
			vec2 vp = p-fr+h;
			float d = dot(vp, vp);

			res +=1.0/pow(d, 8.0);
		}
	}
	return pow( 1.0/res, 1.0/16.0 );
}

void main()
{
	vec4 col = texture2D(map_tu0, texco);
	vec2 uv = texco / vec2(100, 100);
	float tv = 2.0 * trans_blend - 1.0;

	float up0 = voronoi2D(uv * vec2(6.0, 4.0) + vec2(0, tv ));
	float up1 = 0.5 + voronoi2D(uv * vec2(6.0, 4.0) + vec2(42, tv) + 30.0 );
	float finalMask = up0 * up1 + (1.0-uv.y);

	finalMask += (1.0-uv.y)* 0.5;
	finalMask *= 0.7-abs(uv.x - 0.5);

	vec3 dark = mix( vec3(0.0), vec3( 1.0, 0.4, 0.0),  step(0.8,finalMask) ) ;
	vec3 light = mix( dark, vec3( 1.0, 0.8, 0.0),  step(0.95, finalMask) ) ;

	gl_FragColor = vec4(light, 1.0);
}

]], "flame");

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
		wnd.effective_w < 100 and wnd.effective_w * 0.2 or wnd.effective_w * 0.1,
		wnd.effective_h < 100 and wnd.effective_h * 0.2 or wnd.effective_h * 0.1,
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
--	image_shader(vid, flame);
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

-- re-use the menu entry but apply on a 'fake' window where we unpin
-- and expire randomly by attaching to its update timer
local cloth = system_load("tools/flair/cloth.lua")();

local function run_clothfall(wm, wnd, space, space_active, popup)
	if (not space_active) then
		return;
	end

	local vid = flair_supp_clone(wnd);
	if (not valid_vid(vid)) then
		return;
	end

	local fwin = {
		canvas = vid,
		border = null_surface(1,1)
	};
	link_image(fwin.border, fwin.canvas);

	local count = gconfig_get("flair_speed");
	local steps = 0;

	cloth.start(fwin, true);
	local oupd = fwin.verlet.update;
	fwin.verlet.update = function(...)

	for i=0,fwin.verlet.w-1,1 do
	fwin.verlet_control.pin(fwin.verlet, i, 0, false);
	end

-- will cause the destructor to run
		if (not valid_vid(vid)) then
			fwin.canvas = nil;
			return false;
		end

		return oupd(...);
	end
end

return {
	dissolve = function(...)
		run_shader("dissolve", ...);
	end,
	splitfade = function(...)
		run_destr_eval(falling, ...);
	end,
	clothfall = function(...)
		run_clothfall(...);
	end
};
