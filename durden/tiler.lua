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

local windows = {};

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

	a = build_shader(nil, tile_shader, "tile_inact");
	local col = gconfig_get("pcol_bg");
	shader_uniform(a, "col_bg", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	col = gconfig_get("pcol_border");
	shader_uniform(a, "col_border", "fff", PERSIST,
		col[1] / 255.0, col[2] / 255.0, col[3] / 255.0);
	shader_uniform(a, "border", "f", PERSIST, 1);
end
build_shaders();

local function wnd_destroy(wnd)
	local wm = wnd.wm;

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

	local space = wnd.space_ind;
	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end

-- drop global tracking
	table.remove_match(windows, wnd);

-- rebuild layout
	wm.spaces[space]:resize();
end

local function wnd_message(wnd, message)
	print(message);
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

		node:resize(node.x, node.y, node.w, node.h);

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

	space.wm.selected = space.selected and space.selected or space.children[1];
	dive_down(space, dive_down);
end

local function workspace_inactivate(space)
	local dive_down = function(level, fun)
		for i=1,#level.children do
			hide_image(level.children[i].anchor);
-- need to do something about clock ticks?
			fun(level.children[i], fun);
		end
	end

	dive_down(space, dive_down);
end

local function workspace_resize(space)
	if (space.mode == "tile") then
		level_resize(space, 0, 0, space.wm.width,
			space.wm.height-gconfig_get("sbar_sz"));

	elseif (space.mode == "tab") then

	else
		print("fullscreen");
	end
end

local function workspace_destroy(space)
	while (#space.children > 0) do
		space.children[1]:destroy();
	end
	if (space.label_id ~= nil) then
		delete_image(space.label_id);
	end
	for k,v in pairs(space) do
		space[k] = nil;
	end
end

local function create_workspace(wm)
	local res = {
		activate = workspace_activate,
		inactivate = workspace_inactivate,
		resize = workspace_resize,
		destroy = workspace_destroy,
		mode = "tile",
		insert = "horizontal",
		children = {},
		weight = 1.0,
		vweight = 1.0
	};

	res.wm = wm;
	res:activate();
	return res;
end

local function wnd_reassign(wnd, ind)
	wnd.space_ind = ind;
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

	wnd.wm.spaces[wnd.space_ind]:resize();
end

local function wnd_collapse(wnd)
	for k,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, v);
		v.parent = wnd.parent;
	end
	wnd.children = {};
	wnd.wm.spaces[wnd.space_ind]:resize();
end

local function wnd_resize(wnd, x, y, neww, newh)
	move_image(wnd.anchor, x, y);
	resize_image(wnd.anchor, neww, newh);
	resize_image(wnd.border, neww, newh);

	local props = image_storage_properties(wnd.source);

-- to save space for border width, statusbar and other properties
	move_image(wnd.source, wnd.pad_left, wnd.pad_top);
	local neww = neww - wnd.pad_left - wnd.pad_right;
	local newh = newh - wnd.pad_top - wnd.pad_bottom;

	if (neww <= 0 or newh <= 0) then
		return;
	end

	wnd.effective_w = neww;
	wnd.effective_h = newh;

	neww = neww > props.width and props.width or neww;
	newh = newh > props.height and props.height or newh;

	if (wnd.resize_hook) then
		wnd:resize_hook(neww, newh);
	end

--
-- need more modes here: stretch, upscale, crop
--
	if (wnd.auto_resize) then
		resize_image(wnd.source, wnd.effective_w, wnd.effective_h);
	end
end

local function wnd_deselect(wnd)
	if (wnd.wm.selected ~= wnd) then
		return;
	end
	wnd.wm.selected = nil;
	wnd.wm.spaces[wnd.wm.space_ind].selected = nil;
	image_shader(wnd.border, "border_inact");
	image_sharestorage(wnd.wm.border_color, wnd.border);
end

local function wnd_select(wnd, source)
	if (wnd.wm.selected == wnd) then
		return;
	end

	if (wnd.wm.selected) then
		wnd.wm.selected:deselect();
	end

	image_shader(wnd.border, "border_act");
	image_sharestorage(wnd.wm.active_border_color, wnd.border);
	wnd.wm.selected = wnd;
	wnd.wm.spaces[wnd.wm.space_ind].selected = wnd;
end

local function wnd_next(mw, level)
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
	if (level) then
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

local function wnd_assign_ws(wnd, ind)
	if (wnd.space_ind == ind) then
		return;
	end

-- drop selection refrences
	if (wnd.wm.selected == wnd) then
		wnd:prev();
		wnd.wm.selected = wnd.wm.selected ~= wnd and wnd.wm.selected or nil;
	end

	if (wnd.wm.spaces[ind] == nil) then
		wnd.wm.spaces[ind] = create_workspace(wnd.wm);
	end

-- reparent
	table.remove_match(wnd.parent.children, wnd);
	for i,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, v);
		v.parent = wnd.parent;
	end

-- update current workspace
	wnd.children = {};
	wnd.wm.spaces[wnd.space_ind]:resize();
	wnd.space_ind = ind;
	wnd.weight = 1.0;
	wnd.vweight = 1.0;
	wnd.wm.spaces[ind].selected = wnd;

	table.insert(wnd.wm.spaces[ind].children, wnd);
	wnd.parent = wnd.wm.spaces[ind];
	wnd.wm.spaces[ind]:resize();

	if (wnd.wm.space_ind ~= ind) then
		wnd.wm.spaces[ind]:inactivate();
	end

	wnd.wm.spaces[wnd.wm.space_ind]:activate();
	wnd.wm:update_statusbar();
end

--
-- re-adjust each window weight, they are not allowed to go down to negative
-- range and the last cell will always pad to fit
--
local function wnd_grow(wnd, w, h)
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

	wnd.wm.spaces[wnd.space_ind]:resize();
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
		pad_right = 0,
		pad_top = 1,
		pad_bottom = 0,
		weight = 1.0,
		vweight = 1.0,

		auto_resize = opts.auto_resize ~= nil and opts.auto_resize or false,

		assign_ws = wnd_assign_ws,
		destroy = wnd_destroy,
		message = wnd_message,
		resize = wnd_resize,
		select = wnd_select,
		deselect = wnd_deselect,
		next = wnd_next,
		merge = wnd_merge,
		collapse = wnd_collapse,
		prev = wnd_prev,
		grow = wnd_grow,
	};

	image_tracetag(res.anchor, "wnd_anchor");
	image_tracetag(res.border, "wnd_border");

	res.source = source;
	res.wm = wm;

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

	show_image({res.border, source, res.anchor});

-- insertion modes may need some more work when we consider subclass,
-- particularly for popups etc.
	if (not wm.selected or wm.selected.space_ind ~= wm.space_ind) then
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

	res.space_ind = wm.space_ind;
	space:resize();
	table.insert(windows, res);
	res:select();
	return res;
end

local function tick_windows()
	for k,v in ipairs(windows) do
		if (v.tick) then
			v:tick();
		end
	end
end

local function tiler_statusbar_update(wm, msg)
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
				move_image(text, math.ceil(0.5*(statush - props.width)), 3);
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
	local cur = wm.space_ind;

	workspace_inactivate(wm.spaces[cur]);
	if (#wm.spaces[cur].children == 0) then
		wm.spaces[cur]:destroy();
		wm.spaces[cur] = nil;
	end
	if (wm.spaces[ind] == nil) then
		wm.spaces[ind] = create_workspace(wm);
	end

	workspace_activate(wm.spaces[ind]);
	wm.space_ind = ind;
	wm.selected = wm.spaces[ind].selected;
	wm:update_statusbar();
end

function tiler_create(width, height, opts)
	opts.font_sz = (opts.font_sz ~= nil) and opts.font_sz or 12;
	opts.font = (opts.font ~= nil) and opts.font or "default.ttf";

	local clh = height - opts.font_sz - 2;
	assert(clh > 0);

	local res = {
-- null surfaces for clipping / moving / drawing
		client_area = null_surface(width, clh);
		anchor = null_surface(1, 1),
		statusbar = color_surface(width, gconfig_get("sbar_sz"),
			unpack(gconfig_get("sbar_bg"))),

-- pre-alloc these as they will be re-used a lot
		border_color = fill_surface(1, 1,
			unpack(gconfig_get("tcol_inactive_border"))),
		active_border_color = fill_surface(1, 1,
			unpack(gconfig_get("tcol_border"))),

		switch_ws = tiler_switchws,
		add_window = wnd_create,
		find_window = tiler_find,
		error_message = tiler_message,
		update_statusbar = tiler_statusbar_update,

		tick = tick_windows,

-- management members
		spaces = {},
		space_ind = 1
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

function tiler_find(source)
	for i=1,#windows do
		if (windows[i].source == source) then
			return windows[i];
		end
	end
	return nil;
end

-- extend some of the built- ins with common used functions

function string.split(instr, delim)
	local res = {};
	local strt = 1;
	local delim_pos, delim_stp = string.find(instr, delim, strt);

	while delim_pos do
		table.insert(res, string.sub(instr, strt, delim_pos-1));
		strt = delim_stp + 1;
		delim_pos, delim_stp = string.find(instr, delim, strt);
	end

	table.insert(res, string.sub(instr, strt));
	return res;
end

function table.remove_match(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in ipairs(tbl) do
		if (v == match) then
			table.remove(tbl, k);
			return v;
		end
	end

	return nil;
end

function table.remove_vmatch(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in pairs(tbl) do
		if (v == match) then
			tbl[k] = nil;
			return v;
		end
	end

	return nil;
end
