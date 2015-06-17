-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Tiler comprise the main tiling window management,
-- event routing, key interpretation and other hooks. It returns
-- a single creation function (tiler_create(W, H)) that returns the
-- usual table of functions and members in pseudo-OO style.
--

--
-- there is a planned 'effects layer' that reuses the shader API functions
-- for pixman / framebuffer based backends. This layer will (but do not
-- currently) expose a function to set border width and color.
--
assert(SHADER_LANGUAGE == "GLSL120" or SHADER_LANGUAGE == "GLSL100");
local ent_count = 1;
local border_shader = [[
	uniform sampler2D map_diffuse;
	uniform float border;
	uniform float obj_opacity;
	uniform vec2 obj_output_sz;

	varying vec2 texco;

	void main()
	{
		float margin_s = (border / obj_output_sz.x);
		float margin_t = (border / obj_output_sz.y);

		if ( texco.s <= 1.0 - margin_s && texco.s >= margin_s &&
			texco.t <= 1.0 - margin_t && texco.t >= margin_t )
			discard;

		gl_FragColor = vec4(texture2D(map_diffuse, texco).rgb, 1.0);
	}
]];

-- used for drawing both highlight and background
local tile_shader = [[
uniform float border;
uniform vec3 col_border;
uniform vec3 col_bg;
uniform vec2 obj_output_sz;
varying vec2 texco;

void main()
{
	float bstep_x = border/obj_output_sz.x;
	float bstep_y = border/obj_output_sz.y;

	bvec2 marg1 = greaterThan(texco, vec2(1.0 - bstep_x, 1.0 - bstep_y));
	bvec2 marg2 = lessThan(texco, vec2(bstep_x, bstep_y));
	float f = float( !(any(marg1) || any(marg2)) );

	gl_FragColor = vec4(mix(col_border, col_bg, f), 1.0);
}
]];

local function build_shaders()
	local a = build_shader(nil, border_shader, "border_act");
	shader_uniform(a, "border", "f", PERSIST, 1);

	a = build_shader(nil, border_shader, "border_inact");
	shader_uniform(a, "border", "f", PERSIST, 1);

	a = build_shader(nil, tile_shader, "tile_act");
	local col = gconfig_get("pcol_act_border");
	shader_uniform(a, "col_border", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	col = gconfig_get("pcol_act_bg");
	shader_uniform(a, "col_bg", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	shader_uniform(a, "border", "f", PERSIST, 1);

	a = build_shader(nil, tile_shader, "tile_alert");
	col = gconfig_get("tcol_alert_border");
	shader_uniform(a, "col_border", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	col = gconfig_get("tcol_alert");
	shader_uniform(a, "col_bg", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);

	a = build_shader(nil, tile_shader, "tile_inact");
	col = gconfig_get("pcol_bg");
	shader_uniform(a, "col_bg", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	col = gconfig_get("pcol_border");
	shader_uniform(a, "col_border", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	shader_uniform(a, "border", "f", PERSIST, 1);
end
build_shaders();

local function linearize(wnd)
	local res = {};
	local dive = function(wnd, df)
		if (wnd == nil or wnd.children == nil) then
			return;
		end

		for i,v in ipairs(wnd.children) do
			table.insert(res, v);
			df(v, df);
		end
	end
	dive(wnd, dive);
	return res;
end

local function wnd_destroy(wnd)
	local wm = wnd.wm;
	if (wnd.fullscreen) then
		wnd.space:tile();
	end

-- mark a new node as selected
	if (#wnd.children > 0) then
		wnd.children[1]:select();
	elseif (wnd.parent and wnd.parent.parent) then
		wnd.parent:select();
	else
		wnd:prev();
	end

-- re-assign to parent
	for k,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, v);
		v.parent = wnd.parent;
	end

-- drop references, cascade delete from anchor
	delete_image(wnd.anchor);
	table.remove_match(wnd.parent.children, wnd);

	for i=1,10 do
		if (wm.spaces[i] and wm.spaces[i].selected == wnd) then
			wm.spaces[i].selected = nil;
		end
	end

	if (wm.selected == wnd) then
		wm.selected = nil;
	end

-- in tabbed mode, titlebar is not linked to the anchor and
-- won't cascade down, so to not leak a vid, drop it here
	if (valid_vid(wnd.titlebar)) then
		delete_image(wnd.titlebar);
	end

	local space = wnd.space;
	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end

-- drop global tracking
	table.remove_match(wm.windows, wnd);

-- rebuild layout
	space:resize();
end

local function wnd_message(wnd, message)
	print(message);
end

local function wnd_deselect(wnd)
	if (wnd.wm.spaces[wnd.wm.space_ind].mode == "tab") then
		hide_image(wnd.anchor);
	end

	image_shader(wnd.border, "border_inact");
	image_sharestorage(wnd.wm.border_color, wnd.border);
	image_sharestorage(wnd.wm.border_color, wnd.titlebar);
end

local function wnd_select(wnd, source)
	if (wnd.wm.selected) then
		wnd.wm.selected:deselect();
	end

	if (wnd.wm.spaces[wnd.wm.space_ind].mode == "tab") then
		show_image(wnd.anchor);
	end

	image_shader(wnd.border, "border_act");
	image_sharestorage(wnd.wm.active_border_color, wnd.border);
	image_sharestorage(wnd.wm.active_border_color, wnd.titlebar);

	wnd.wm.selected = wnd;
	wnd.space.selected = wnd;
end

--
-- This is _the_ operation when it comes to window management here, it resizes
-- the actual size of a tile (which may not necessarily match the size of the
-- underlying surface). Keep everything divisible by two for simplicity.
--
-- The overall structure in split mode is simply a tree, split resources fairly
-- between individuals (with an assignable weight) and recurse down to children
--
local function level_resize(level, x, y, w, h, node)
	local fair = math.ceil(w / #level.children);
	fair = (fair % 2) == 0 and fair or fair + 1;

	if (#level.children == 0) then
		return;
	end

	local process_node = function(node, last)
		node.x = x; node.y = y;
		node.h = h;

		if (last) then
			node.w = w;
		else
			node.w = math.ceil(fair * node.weight);
			node.w = (node.w % 2) == 0 and node.w or node.w + 1;
		end

		if (#node.children > 0) then
			node.h = math.ceil(h / 2 * node.vweight);
			node.h = (node.h % 2) == 0 and node.h or node.h + 1;
			level_resize(node, x, y + node.h, node.w, h - node.h);
		end

		node:resize(node.w, node.h);
		move_image(node.anchor, node.x, node.y);

		x = x + node.w;
		w = w - node.w;
	end

	for i=1,#level.children-1 do
		process_node(level.children[i]);
	end

	process_node(level.children[#level.children], true);
end

local function workspace_activate(space)
	local dive_down = function(level, fun)
		for i=1,#level.children do
			show_image(level.children[i].anchor);
			fun(level.children[i], fun);
		end
	end

	local tgt = space.selected and space.selected or space.children[1];
	dive_down(space, dive_down);
end

local function workspace_inactivate(space, store)
	local dive_down = function(level, fun)
		for i=1,#level.children do
			hide_image(level.children[i].anchor);
			fun(level.children[i], fun);
		end
	end

	dive_down(space, dive_down);
end

local function switch_fullscreen(space, to)
	if (space.selected == nil) then
		return;
	end

	workspace_inactivate(space);
	if (to) then
		image_mask_clear(space.selected.source, MASK_OPACITY);
		hide_image(space.wm.statusbar);
	else
		image_mask_set(space.selected.source, MASK_OPACITY);
		hide_image(space.selected.anchor);
	end
end

local function drop_fullscreen(space, swap)
	workspace_activate(space);

	if (not space.selected) then
		return;
	end

	local dw = space.selected;
	space.locked = false;
	dw.fullscreen = nil;
	resize_image(dw.wm.client_area, dw.wm.width, dw.wm.client_height);
	image_mask_set(dw.source, MASK_OPACITY);
	space.switch_hook = nil;
end

local function drop_tab(space)
	local res = linearize(space);

-- new mode will resize so don't worry about that, just relink
	for k,v in ipairs(res) do
		if (v.titlebar) then
			link_image(v.titlebar, v.anchor);
			move_image(v.titlebar, 1, 1);
		end
	end

	space.mode_hook = nil;
	space.switch_hook = nil;
	workspace_activate(space);
end

local function switch_tab(space, to)
	local lst = linearize(space);
	for k,v in ipairs(lst) do
		if (v.titlebar) then
			if (to) then
				show_image(v.titlebar);
			else
				hide_image(v.titlebar);
			end
		end
	end
	if (space.selected) then
		if (to) then
			show_image(space.selected.anchor);
		else
			hide_image(space.selected.anchor);
		end
	end
end

local function drop_float(space, swap)
-- iterate windows, add / activate special mouse
-- handler and resize button
end

-- just unlink statusbar, resize all at the same time (also hides some
-- of the latency in clients producing new output buffers with the correct
-- dimensions etc). then line the statusbars at the top.
local function set_tab(space)
	space.mode_hook = drop_tab;
	space.switch_hook = switch_tab;

	local lst = linearize(space);
	if (#lst == 0) then
		return;
	end

	local fairw = math.floor(space.wm.width / #lst);
	local tbar_sz = gconfig_get("tbar_sz");
	local ofs = 0;

	for k,v in ipairs(lst) do
		v:resize(space.wm.width, space.wm.client_height);
		move_image(v.anchor, 0, 0);
		hide_image(v.anchor);
		if (v.titlebar) then
			link_image(v.titlebar, space.wm.anchor);
			move_image(v.titlebar, ofs, 0);
			resize_image(v.titlebar, fairw, tbar_sz);
			ofs = ofs + fairw;
		end
	end

	workspace_inactivate(space);
	if (space.selected) then
		space.selected:select();
	end
end

local function set_fullscreen(space)
	if (not space.selected) then
		return;
	end
	local dw = space.selected;

-- hide all images + statusbar
	hide_image(dw.wm.statusbar);
	workspace_inactivate(space);
	dw.fullscreen = true;
	space.locked = true;
	space.mode_hook = drop_fullscreen;
	space.switch_hook = switch_fullscreen;
	image_mask_clear(dw.source, MASK_OPACITY);
	resize_image(dw.wm.client_area, dw.wm.width, dw.wm.height);
	dw:resize(dw.wm.width, dw.wm.height);
	move_image(dw.anchor, 0, 0);
end

local function set_float(space)
	show_image(wm.statusbar);
	space.mode_hook = drop_float;
end

local function set_tile(space)
	show_image(space.wm.statusbar);
	level_resize(space, 0, 0, space.wm.width,
		space.wm.height - gconfig_get("sbar_sz") - 1);
end

local space_handlers = {
	tile = set_tile,
	float = set_float,
	fullscreen = set_fullscreen,
	tab = set_tab
};

local function workspace_destroy(space)
	if (space.mode_hook) then
		space:mode_hook();
		space.mode_hook = nil;
	end

	while (#space.children > 0) do
		space.children[1]:destroy();
	end

	if (valid_vid(space.rendertarget)) then
		delete_image(space.rendertarget);
	end

	if (space.label_id ~= nil) then
		delete_image(space.label_id);
	end

	for k,v in pairs(space) do
		space[k] = nil;
	end
end

local function workspace_set(space, mode)
	if (mode == space.mode or (mode ~= "fullscreen" and mode ~= "tile"
		and mode ~= "tab")) then
		return;
	end

-- cleanup to revert to the normal stable state (tiled)
	if (space.mode_hook) then
		space:mode_hook();
		space.mode_hook = nil;
	end

	space.mode = mode;
	space:resize();
end

-- could possibly support less intense versions with downscale
-- or lower rates, is rather context- dependent
local function workspace_rendertarget(space, destroy)
	if (destroy) then
		if (valid_vid(space.rendertarget)) then
-- FIXME: detach windows
		end
		space.rendertarget = nil;
		return;
	end

	if (not valid_vid(space.rendertarget)) then
		space.rendertarget = alloc_surface(space.wm.width, space.wm.height);
		define_rendertarget(space.rendertarget, {});
	end

	return space.rendertarget;
end

local function workspace_resize(space)
	if (space_handlers[space.mode]) then
		space_handlers[space.mode](space);
	end
end

local function workspace_label(space, lbl)
	delete_image(space.label_id);
	space.label_id = nil;
	space.label = lbl;
	space.wm:update_statusbar();
end

local function create_workspace(wm)
	local res = {
		activate = workspace_activate,
		inactivate = workspace_inactivate,
		resize = workspace_resize,
		destroy = workspace_destroy,
		get_rendertarget = workspace_rendertarget,
		fullscreen = function(ws) workspace_set(ws, "fullscreen"); end,
		tile = function(ws) workspace_set(ws, "tile"); end,
		tab = function(ws) workspace_set(ws, "tab"); end,
		set_label = workspace_label,
		float = function(ws) workspace_set(ws, "float"); end,
		mode = "tile",
		name = "workspace_" .. tostring(ent_count);
		insert = "horizontal",
		children = {},
		weight = 1.0,
		vweight = 1.0
	};
	ent_count = ent_count + 1;
	res.wm = wm;
	res:activate();
	return res;
end

local function wnd_merge(wnd)
	local i = 1;
	while (i ~= #wnd.parent.children) do
		if (wnd.parent.children[i] == wnd) then
			break;
		end
		i = i + 1;
	end

	if (i < #wnd.parent.children) then
		for j=i+1,#wnd.parent.children do
			table.insert(wnd.children, wnd.parent.children[j]);
			wnd.parent.children[j].parent = wnd;
		end
		for j=#wnd.parent.children,i+1,-1 do
			table.remove(wnd.parent.children, j);
		end
	end

	wnd.space:resize();
end

local function wnd_collapse(wnd)
	for k,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, v);
		v.parent = wnd.parent;
	end
	wnd.children = {};
	wnd.space:resize();
end

local function apply_scalemode(wnd, mode, src, props, maxw, maxh)
	local outw = 1;
	local outh = 1;

	if (wnd.scalemode == "normal") then
-- explore: modify texture coordinates and provide scrollbars
		if (props.width > 0 and props.height > 0) then
			outw = props.width < maxw and props.width or maxw;
			outh = props.height < maxh and props.height or maxh;
		end

	elseif (wnd.scalemode == "stretch") then
		outw = maxw;
		outh = maxh;

	elseif (wnd.scalemode == "aspect") then
		local ar = props.width / props.height;
		local wr = props.width / maxw;
		local hr = props.height/ maxh;

		outw = hr > wr and math.ceil(maxh * ar - 0.5) or maxw;
		outh = hr < wr and math.ceil(maxw / ar - 0.5) or maxh;
	end

	resize_image(src, outw, outh);
	return outw, outh;
end

local function wnd_resize(wnd, neww, newh)
	resize_image(wnd.anchor, neww, newh);
	resize_image(wnd.border, neww, newh);

	resize_image(wnd.titlebar, neww,
		image_surface_properties(wnd.titlebar).height);

	wnd.width = neww;
	wnd.height = newh;

	local props = image_storage_properties(wnd.source);

-- to save space for border width, statusbar and other properties
	if (not wnd.fullscreen) then
		move_image(wnd.source, wnd.pad_left, wnd.pad_top);
		neww = neww - wnd.pad_left - wnd.pad_right;
		newh = newh - wnd.pad_top - wnd.pad_bottom;
	else
		move_image(wnd.source, 0, 0);
	end

	if (neww <= 0 or newh <= 0) then
		return;
	end

	wnd.effective_w = neww;
	wnd.effective_h = newh;

	if (wnd.resize_hook) then
		wnd:resize_hook(neww, newh);
	end

	wnd.effective_w, wnd.effective_h = apply_scalemode(wnd,
		wnd.scalemode, wnd.source, props, neww, newh);

-- good spot to add post-processing filters and upscalers

	if (wnd.centered) then
		move_image(wnd.anchor, math.floor(0.5*(neww - wnd.effective_w)),
			math.floor(0.5*(neww - wnd.effective_h)));
	end
end

local function wnd_next(mw, level)
	if (mw.fullscreen) then
		return;
	end

-- we use three states; true, false or nil.
	if (mw.wm.spaces[mw.wm.space_ind].mode == "tab" and level == nil) then
		level = true;
	end

	if (level) then
		if (#mw.children > 0) then
			mw.children[1]:select();
			return;
		end
	end

	local i = 1;
	while (i < #mw.parent.children) do
		if (mw.parent.children[i] == mw) then
			break;
		end
		i = i + 1;
	end

	if (i == #mw.parent.children) then
		if (mw.parent.parent ~= nil) then
			return wnd_next(mw.parent, false);
		else
			i = 1;
		end
	else
		i = i + 1;
	end

	mw.parent.children[i]:select();
end

local function wnd_prev(mw, level)
	if (mw.fullscreen) then
		return;
	end

	if (level or mw.wm.spaces[mw.wm.space_ind].mode == "tab") then
		if (mw.parent.select) then
			mw.parent:select();
			return;
		end
	end

	local ind = 1;
	for i,v in ipairs(mw.parent.children) do
		if (v == mw) then
			ind = i;
			break;
		end
	end

	if (ind == 1) then
		if (mw.parent.parent) then
			mw.parent:select();
		else
			mw.parent.children[#mw.parent.children]:select();
		end
	else
		ind = ind - 1;
		mw.parent.children[ind]:select();
	end
end

local function wnd_reassign(wnd, ind)
	local newspace = wnd.wm.spaces[ind];

-- don't switch unless necessary
	if (wnd.space == newspace or wnd.fullscreen) then
		return;
	end

-- drop selection references unless we can find a new one
	if (wnd.wm.selected == wnd) then
		wnd:prev();
		wnd.wm.selected = wnd.wm.selected ~= wnd and wnd.wm.selected or nil;
	end

-- create if it doesn't exist
	if (newspace == nil) then
		wnd.wm.spaces[ind] = create_workspace(wnd.wm);
		newspace = wnd.wm.spaces[ind];
	end

	local seltgt = wnd.wm.selected;

-- reparent
	table.remove_match(wnd.parent.children, wnd);
	for i,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, v);
		v.parent = wnd.parent;
	end

-- update workspace assignment
	wnd.children = {};
	local oldspace = wnd.space;
	wnd.space = newspace;
	wnd.parent = newspace;
	table.insert(newspace.children, wnd);

-- weights aren't useful for new space, reset
	wnd.weight = 1.0;
	wnd.vweight = 1.0;
	hide_image(wnd.anchor);
	wnd:deselect();

-- subtle resize in order to propagate resize events while still hidden
	if (not(newspace.selected and newspace.selected.fullscreen)) then
		newspace.selected = wnd;
		newspace:resize();
	end
	oldspace:resize();
	wnd.wm:update_statusbar();
end

--
-- re-adjust each window weight, they are not allowed to go down to negative
-- range and the last cell will always pad to fit
--
local function wnd_grow(wnd, w, h)
	if (wnd.locked) then
		return;
	end

	if (h ~= 0) then
		wnd.vweight = wnd.vweight + h;
		wnd.parent.vweight = wnd.parent.vweight - h;
	end

	if (w ~= 0) then
		wnd.weight = wnd.weight + w;
		for i=1,#wnd.parent.children do
			if (wnd.parent.children[i] ~= wnd) then
				wnd.parent.children[i].weight = wnd.parent.children[i].weight - w;
			end
		end
	end

	wnd.space:resize();
end

local function wnd_title(wnd, message)
	local props = image_surface_properties(wnd.titlebar);
	if (valid_vid(wnd.title_temp)) then
		delete_image(wnd.title_temp);
		wnd.title_temp = nil;
	end

	if (type(message) == "string") then
		message = render_text(string.format("%s %s",
			gconfig_get("tbar_textstr"), string.gsub(message, "\\", "\\\\")));
	end

	if (not valid_vid(message)) then
		if (props.opacity <= 0.001) then
			return;
		end
		hide_image(wnd.titlebar);
		local vch = wnd.pad_top - 1;
		wnd.pad_top = wnd.pad_top - gconfig_get("tbar_sz");
		if (vch > 0) then
			wnd.space:resize();
		end
		return;
	end

	if (props.opacity <= 0.001) then
		show_image(wnd.titlebar);
		wnd.pad_top = wnd.pad_top + gconfig_get("tbar_sz");
		wnd.space:resize();
	end

	link_image(message, wnd.titlebar);
	wnd.title_temp = message;
	image_clip_on(message, CLIP_SHALLOW);
	resize_image(wnd.titlebar, wnd.width - 2, gconfig_get("tbar_sz"));
	image_inherit_order(message, 1);
	move_image(message, 1, 1);
	show_image(message);
end

local function wnd_alert(wnd)
	local wm = wnd.wm;

	if (not wm.selected or wm.selected == wnd) then
		return;
	end

	if (wnd.space ~= wm.spaces[wm.space_ind]) then
		image_shader(wnd.space.label_id, "tile_alert");
	end

	image_sharestorage(wm.alert_color, wnd.titlebar);
	image_sharestorage(wm.alert_color, wnd.border);
end

local function wnd_create(wm, source, opts)
	if (opts == nil) then opts = {}; end

	local res = {
		anchor = null_surface(1, 1),
-- we use fill surfaces rather than color surfaces to get texture coordinates
		border = fill_surface(1, 1, 255, 255, 255),
		titlebar = fill_surface(1,
			gconfig_get("tbar_sz"), unpack(gconfig_get("tbar_bg"))),
		children = {},
		pad_left = 1,
		pad_right = 1,
		pad_top = 1,
		pad_bottom = 1,
		width = 1,
		height = 1,
		effective_w = 0,
		effective_h = 0,
		weight = 1.0,
		vweight = 1.0,
		scalemode = opts.scalemode and opts.scalemode or "normal",
		alert = wnd_alert,
		assign_ws = wnd_reassign,
		destroy = wnd_destroy,
		message = wnd_message,
		set_title = wnd_title,
		resize = wnd_resize,
		select = wnd_select,
		deselect = wnd_deselect,
		next = wnd_next,
		merge = wnd_merge,
		collapse = wnd_collapse,
		prev = wnd_prev,
		grow = wnd_grow,
		name = "wnd_" .. tostring(ent_count);
	};
	ent_count = ent_count + 1;
	image_tracetag(res.anchor, "wnd_anchor");
	image_tracetag(res.border, "wnd_border");

	res.source = source;
	res.wm = wm;

-- initially, titlebar stays hidden
	link_image(res.titlebar, res.anchor);
	image_inherit_order(res.titlebar, true);
	move_image(res.titlebar, 1, 1);

	if (wm.spaces[wm.space_ind] == nil) then
		wm.spaces[wm.space_ind] = create_workspace(wm);
		wm:update_statusbar();
	end

	local space = wm.spaces[wm.space_ind];
	image_inherit_order(res.anchor, true);
	image_inherit_order(res.border, true);
	image_inherit_order(source, true);

	link_image(source, res.anchor);
	link_image(res.border, res.anchor);

	image_shader(res.border, "border_inact");
	link_image(source, res.anchor);
	order_image(res.border, 1);

	show_image({res.border, source});

	if (not wm.selected or wm.selected.space ~= space) then
		table.insert(space.children, res);
		res.parent = space;

	elseif (space.insert == "horizontal") then
		if (wm.selected.parent) then
			table.insert(wm.selected.parent.children, res);
			res.parent = wm.selected.parent;
		else
			table.insert(space.children, res);
			res.parent = space;
		end
	else
		table.insert(wm.selected.children, res);
		res.parent = wm.selected;
	end

	res.space = space;
	table.insert(wm.windows, res);
	if (not(wm.selected and wm.selected.fullscreen)) then
		show_image(res.anchor);
		space:resize();
		res:select();
	else
		image_shader(res.border, "border_inact");
		image_sharestorage(res.wm.border_color, res.border);
	end
	return res;
end

local function tick_windows(wm)
	for k,v in ipairs(wm.windows) do
		if (v.tick) then
			v:tick();
		end
	end
end

local function tiler_find(wm, source)
	for i=1,#wm.windows do
		if (wm.windows[i].source == source) then
			return wm.windows[i];
		end
	end
	return nil;
end

local function tiler_statusbar_update(wm, msg, state)
	local statush = gconfig_get("sbar_sz");
	resize_image(wm.statusbar, wm.width, statush);
	move_image(wm.statusbar, 0, wm.height - statush);
	show_image(wm.statusbar);

	local ofs = 0;
	for i=1,10 do
		if (wm.spaces[i] ~= nil) then
			local space = wm.spaces[i];

-- no pre-rendered label? render and associate with tile
			if (space.label_id == nil) then
				local text = render_text(string.format("%s%s %d%s",
					gconfig_get("font_str"), gconfig_get("text_color"), i,
					space.label ~= nil and ":" .. space.label or ""));
				local props = image_surface_properties(text);
				if (not space.label) then
					move_image(text, math.ceil(0.5*(statush - props.width)), 3);
				else
					move_image(text, 2, 3);
				end
				local tilew = (props.width+4) > statush and (props.width+4) or statush;
				local tile = fill_surface(tilew, statush, 255, 255, 255);
				link_image(text, tile);
				show_image({text, tile});
				image_inherit_order(tile, true);
				image_inherit_order(text, true);
				link_image(tile, wm.statusbar);
				space.label_id = tile;
			end

			image_shader(space.label_id,
				i == wm.space_ind and "tile_act" or "tile_inact");

-- tiles can have variable width
			local props = image_surface_properties(space.label_id);
			move_image(space.label_id, ofs, 0);
			ofs = ofs + props.width + 1;
		end
	end

-- add msg in statusbar "slot", protect against overflow into ws list
	if (msg ~= nil) then
		if (valid_vid(wm.statusbar_msg)) then
			delete_image(wm.statusbar_msg);
		end
		wm.statusbar_msg = msg;
		show_image(msg);
		link_image(msg, wm.statusbar);
		image_inherit_order(msg, true);
		local props = image_surface_properties(msg);
		local xpos = wm.width - props.width;

-- align to 20px just to lessen the effect of non-monospace font
		if (xpos % 20 ~= 0) then
			xpos = xpos - (xpos % 20);
		end
		xpos = xpos < ofs and ofs or xpos;
		move_image(msg, xpos, 3);
	end
end

local function tiler_switchws(wm, ind)
	local cur = wm.spaces[wm.space_ind];
	local cw = wm.selected;

	if (cur.switch_hook) then
		cur:switch_hook(false);
	else
		workspace_inactivate(cur, true);
	end

	if (#cur.children == 0) then
		cur:destroy();
		wm.spaces[wm.space_ind] = nil;
	else
		cur.selected = cw;
	end

	if (wm.spaces[ind] == nil) then
		wm.spaces[ind] = create_workspace(wm);
	end

	wm.space_ind = ind;
	wm:update_statusbar();

	if (wm.spaces[ind].switch_hook) then
		wm.spaces[ind]:switch_hook(true);
	else
		workspace_activate(wm.spaces[ind]);
	end

	if (wm.spaces[ind].selected) then
		wnd_select(wm.spaces[ind].selected);
	else
		wm.selected = nil;
	end
end

function tiler_create(width, height, opts)
	opts.font_sz = (opts.font_sz ~= nil) and opts.font_sz or 12;
	opts.font = (opts.font ~= nil) and opts.font or "default.ttf";

	local clh = height - opts.font_sz - 2;
	assert(clh > 0);

	local res = {
-- null surfaces for clipping / moving / drawing
		client_area = null_surface(width, clh),
		client_height = clh,
		anchor = null_surface(1, 1),
		statusbar = color_surface(width, gconfig_get("sbar_sz"),
			unpack(gconfig_get("sbar_bg"))),

-- pre-alloc these as they will be re-used a lot
		border_color = fill_surface(1, 1,
			unpack(gconfig_get("tcol_inactive_border"))),

		alert_color =	 fill_surface(1, 1,
			unpack(gconfig_get("tcol_alert"))),

		active_border_color = fill_surface(1, 1,
			unpack(gconfig_get("tcol_border"))),

		lbar = tiler_lbar,
		tick = tick_windows,

-- management members
		spaces = {},
		windows = {},
		space_ind = 1,

-- kept per/tiler in order to allow custom modes as well
		scalemodes = {"normal", "stretch", "aspect"},

-- public functions
		switch_ws = tiler_switchws,
		add_window = wnd_create,
		find_window = tiler_find,
		error_message = tiler_message,
		update_statusbar = tiler_statusbar_update,
	};
	res.width = width;
	res.height = height;

	move_image(res.statusbar, 0, clh);
	link_image(res.client_area, res.anchor);
	link_image(res.statusbar, res.anchor);
	show_image({res.anchor, res.client_area, res.statusbar});

	res.spaces[1] = create_workspace(res);
	res:update_statusbar();

	return res;
end
