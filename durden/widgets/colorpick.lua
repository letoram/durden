local frag_1 = [[
varying vec2 texco;

vec3 hsv2rgb(vec3 c)
{
	vec3 step = vec3(0.0, 4.0, 2.0);
	vec3 rgb = clamp(
		abs(
			mod(c.x * 6.0 + step, 6.0) - 3.0
		) - 1.0, 0.0, 1.0
	);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void main()
{
	gl_FragColor = vec4(hsv2rgb(vec3(texco.s, 1.0, 1.0 - texco.t)), 1.0);
}
]];

local frag_2 = [[
/* conversion of IQs palette demo
 * License: MIT
 * Copyright (C) 2015 Inigo Quilez */

varying vec2 texco;

vec3 pal(float t, vec3 a, vec3 b, vec3 c, vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

void main()
{
	vec2 p = texco;
    // compute colors
    vec3                col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
    if( p.y>(1.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20) );
    if( p.y>(2.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.3,0.20,0.20) );
    if( p.y>(3.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,0.5),vec3(0.8,0.90,0.30) );
    if( p.y>(4.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20) );
    if( p.y>(5.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25) );
    if( p.y>(6.0/7.0) ) col = pal( p.x, vec3(0.8,0.5,0.4),vec3(0.2,0.4,0.2),vec3(2.0,1.0,1.0),vec3(0.0,0.25,0.25) );
	float f = fract(p.y * 7.0);
	col *= smoothstep( 0.49, 0.47, abs(f-0.5) );
	col *= 0.5 + 0.5*sqrt(4.0*f*(1.0-f));
	gl_FragColor = vec4(col, 1.0);
}
]];

-- we do this as a generate+readback thing
local function probe(ctx, yh, ident)
	ctx.ident = ident;
	return 1;
end

local shader_1;
local shader_2;
local function build_colorimage(w, h)
	local nelem = 3;
	local cmap = suppl_tgt_loadcolor(gconfig_get("tui_colorscheme"))
	if cmap then
		nelem = nelem + 1
	end

	local cellw = math.ceil(w / nelem);
	local space = active_display():active_space():preview(cellw, h, 5, 0);
	if not space then
		nelem = nelem - 1;
		cellw = math.ceil(w / nelem);
	else
		show_image(space);
	end

-- temporary rendertarget to image
	local v1 = null_surface(cellw, h);
	local v2 = null_surface(cellw, h);

	if (not valid_vid(v2)) then
		delete_image(v1);
		if valid_vid(space) then
			delete_image(space);
		end
		return;
	end

-- build a tree so we don't need to position / cleanup all
	local ap = v2
	link_image(v2, v1, ANCHOR_UR)
	if valid_vid(space) then
		link_image(space, v2, ANCHOR_UR)
		ap = space
	end

	if not shader_1 then
		shader_1 = build_shader(nil, frag_1, "colorpick_1");
	end

	if not shader_2 then
		shader_2 = build_shader(nil, frag_2, "colorpick_2");
	end

	local set = {v1, v2};
	if valid_vid(space) then
		table.insert(set, space);
	end

	if cmap then
		local ctbl = {}
		for i=1,#cmap do
			ctbl[(i-1)*3+1] = cmap[i][1]
			ctbl[(i-1)*3+2] = cmap[i][2]
			ctbl[(i-1)*3+3] = cmap[i][3]
		end

		local surf = raw_surface(1, #cmap, 3, ctbl)
		if valid_vid(surf) then
			resize_image(surf, cellw, h)
			table.insert(set, surf)
			link_image(surf, ap, ANCHOR_UR)
			ap = surf
		end
	end

-- build intermediate buffer
	show_image(set);
	local buf = alloc_surface(w, h, true);
	if not valid_vid(buf) then
		delete_image(v1);
		return;
	end

-- offscreen render to buffer
	image_shader(v1, shader_1);
	image_shader(v2, shader_2);

	define_rendertarget(buf, set, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
	rendertarget_forceupdate(buf);

-- save the contents but delete all other resources
	rendertarget_attach(active_display(true), v1, RENDERTARGET_DETACH);
	image_sharestorage(buf, v1);
	image_shader(v1, "DEFAULT");
	delete_image(buf);

	return v1;
end

local function color_to_ident(r, g, b, ident)
	return string.format("%d %d %d", r, g, b);
end

local shader;
local function show(ctx, anchor, ofs, yh)
	local w = math.clamp(yh * 6.0, 0, active_display().width);
	local surf = build_colorimage(w, yh);
	if not valid_vid(surf) then
		return 0, 0;
	end

-- attach so we autoclean
	show_image(surf);
	link_image(surf, anchor);
	image_inherit_order(surf, true);
	image_tracetag(surf, "color_swatch");

-- this is suprisingly complex, so the mouse handler calculates the surface-
-- local coordinates for the selected pixel, and the click action triggers
-- an update of a FBO with readback into a callback where the value can be
-- sampled and set to the input bar
	local buf = alloc_surface(2, 2);
	local ref = null_surface(2, 2);
	local hint = null_surface(320, 320);
	image_tracetag(buf, "color_dst");
	image_tracetag(ref, "color_pick");
	image_tracetag(hint, "color_preview");
	show_image({hint, ref});
	image_inherit_order(hint, true);
	link_image(hint, surf, ANCHOR_UR);
	link_image(buf, surf);

	image_sharestorage(surf, ref);
	image_sharestorage(surf, hint);

	local lx = 0;
	local ly = 0;
	local props = image_surface_resolve(surf);
	local store_props = image_storage_properties(surf);
	local sx = (props.width / store_props.width) / props.width;
	local sy = (props.height / store_props.height) / props.height;

	define_calctarget(buf, {ref}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0,
		function(tbl, w, h)
			local r, g, b = tbl:get(0, 0, 3);
			local lbar = tiler_lbar_isactive(true);
			if lbar then
				lbar.inp:set_str(color_to_ident(r, g, b, ctx.ident));
			end
		end
	);

-- add the clickhandler that lets us actually get the color
	ctx.mouseh = {
	name = "colorpick",
	own = function(ctx, val)
		return val == surf;
	end,

-- this is buggy due to an engine issue, if we translate x,y to surface
-- coordinates, the x/y of the anchor will not resolve correctly due to the
-- ANCHOR_ so wait for that to be fixed
	motion = function(ctx, vid, x, y)
		lx = x / props.width;
		ly = y / props.height;
		local txcos = {lx, ly, lx + sx, ly, lx + sx, ly + sy, lx, ly + sy};
		image_set_txcos(ref, txcos);
		image_set_txcos(hint, txcos);
	end,
	click = function()
		if valid_vid(buf) and valid_vid(ref) then
			rendertarget_forceupdate(buf);
			stepframe_target(buf);
		end
	end,
	};

	mouse_addlistener(ctx.mouseh, {"motion", "click"});

	return w, yh;
end

-- could also cache this a bit and add a cleanup timer to make it faster
local function destroy(ctx)
	if ctx.mouseh then
		mouse_droplistener(ctx.mouseh);
		ctx.mouseh = nil;
	end
end

return {
	name = "colorpick",
-- the name specifies what kind of format should be set on click
	paths = {
		"special:colorpick_r8g8b8",
		"special:colorpick_r8g8b8a8",
		"special:colorpick_rgbstr",
		"special:colorpick_rgbaf",
		"special:colorpick_rgbf"
	},
	show = show,
	probe = probe,
	destroy = destroy
};
