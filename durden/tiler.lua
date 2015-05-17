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

local border_1px = build_shader(nil, border_shader, "border_1px");
local border_2px = build_shader(nil, border_shader, "border_2px");

shader_uniform(border_1px, "border", "f", PERSIST, 1);
shader_uniform(border_2px, "border", "f", PERSIST, 2);

local function wnd_destroy(wnd)
	local wm = wnd.wm;
	wnd:next();

	delete_image(wnd.anchor);
	table.remove_match(wnd.parent.children, wnd);

	if (wm.selected == wnd) then
		wm.selected = nil;
	end

	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end

	table.remove_match(windows, wnd);
	wm.spaces[wm.space_ind]:resize();
end

local function wnd_message(wnd, message)
	print(message);
end

local function wnd_reassign(wnd, ind)
	if (wnd.space_ind == ind) then
		return;
	end

	table.remove_match(wnd.wm.spaces[wnd.space_ind], wnd);

	wnd.space_ind = ind;
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
			node.h = math.ceil(node.h / 2 * node.vweight);
			node.h = (node.h % 2) == 0 and node.h or node.h + 1;
			level_resize(node, x, y + node.h, node.h);
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
end

local function workspace_inactivate(space)
end

local function workspace_resize(space)
	level_resize(space, 0, 0, space.wm.width, space.wm.height);
end

local function create_workspace(wm)
	local res = {
		activate = workspace_activate,
		inactivate = workspace_inactivate,
		resize = workspace_resize,
		insert = "level",
		children = {},
		weight = 1.0,
		vweight = 1.0
	};

	res.wm = wm;
	res:activate();
-- wm:update_statusbar();
	return res;
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

-- For many data sources, this will look terrible, so let the resize hook
-- handle things.
	if (wnd.auto_resize) then
		resize_image(wnd.source, neww, newh);
	end

	if (wnd.resize_hook) then
		wnd:resize_hook(neww, newh);
	end
end

local function wnd_deselect(wnd)
	if (wnd.wm.selected ~= wnd) then
		return;
	end
	wnd.wm.selected = nil;
	image_shader(wnd.border, border_1px);
	image_sharestorage(wnd.wm.border_color, wnd.border);
end

local function wnd_select(wnd, source)
	if (wnd.wm.selected == wnd) then
		return;
	end

	if (wnd.wm.selected) then
		wnd.wm.selected:deselect();
	end

	image_shader(wnd.border, border_2px);
	image_sharestorage(wnd.wm.active_border_color, wnd.border);
	wnd.wm.selected = wnd;
end

local function wnd_next(mw, level)
	if (level) then
		if (#mw.children > 0) then
			mw.children[1]:select();
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

	ind = ind == #mw.parent.children and 1 or ind + 1;
	mw.parent.children[ind]:select();
end

local function wnd_prev(mw, level)
	if (level) then
		if (mw.parent.select) then
			level.parent:select();
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

	ind = ind == 1 and #mw.parent.children or ind - 1;
	mw.parent.children[ind]:select();
end

--
-- re-adjust each window weight, they are not allowed to go down to negative
-- range and the last cell will always pad to fit
--
local function wnd_grow(wnd, w, h)
	if (h ~= 0) then
		wnd.vweight = wnd.vweight + h;
		for i=1,#wnd.children do
			wnd.children[i].vweight = wnd.children[i].vweight - h;
		end
	end

	if (w ~= 0) then
		wnd.weight = wnd.weight + w;
		for i=1,#wnd.parent.children do
			if (wnd.parent.children[i] ~= wnd) then
				wnd.parent.children[i].weight = wnd.parent.children[i].weight - w;
			end
		end
	end

	wnd.wm.spaces[wnd.wm.space_ind]:resize();
end

-- we use fill surfaces rather than color surfaces to get texture coordinates
local function wnd_create(wm, source, opts)
	if (opts == nil) then opts = {}; end

	local res = {
		anchor = null_surface(1, 1),
		border = fill_surface(1, 1, 255, 255, 255),

		children = {},
		pad_left = 1,
		pad_right = 0,
		pad_top = 1,
		pad_bottom = 0,
		weight = 1.0,
		weight = 1.0,

		auto_resize = opts.auto_resize ~= nil and opts.auto_resize or false,

		destroy = wnd_destroy,
		message = wnd_message,
		resize = wnd_resize,
		select = wnd_select,
		deselect = wnd_deselect,
		next = wnd_next,
		prev = wnd_prev,
		grow = wnd_grow,
	};

	res.source = source;
	res.wm = wm;

	if (wm.spaces[wm.space_ind] == nil) then
		wm.spaces[wm.space_ind] = create_workspace(wm, wm.space_ind);
	end

	image_inherit_order(res.anchor, true);
	image_inherit_order(res.border, true);
	image_inherit_order(source, true);

	link_image(source, res.anchor);
	link_image(res.border, res.anchor);

	image_shader(res.border, border_1px);
	link_image(source, res.anchor);
	order_image(res.border, 1);

	show_image({res.border, source, res.anchor});

-- insertion modes may need some more work when we consider subclass,
-- particularly for popups etc.
	if (wm.spaces[wm.space_ind].insert == "level" or not wm.selected) then
		table.insert(wm.spaces[wm.space_ind].children, res);
		res.parent = wm.spaces[wm.space_ind];
	else
		table.insert(wm.selected.children, res);
		res.parent = wm.selected;
	end

	wm.spaces[wm.space_ind]:resize(wnd, wm.space_ind);
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

function tiler_create(width, height, opts)
	opts.font_sz = (opts.font_sz ~= nil) and opts.font_sz or 12;
	opts.font = (opts.font ~= nil) and opts.font or "default.ttf";

	local clh = height - opts.font_sz - 2;
	assert(clh > 0);

	local res = {
-- null surfaces for clipping / moving / drawing
		client_area = null_surface(width, clh);
		anchor = null_surface(1, 1),
		statusbar = null_surface(width, opts.font_sz - 2),
		border_color = fill_surface(1, 1, 32, 32, 32),
		active_border_color = fill_surface(1, 1, 255, 255, 255),

		add_window = wnd_create,
		find_window = tiler_find,
		error_message = tiler_message,
		previous = tiler_previous,

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

function tiler_find(source)
	for i=1,#windows do
		if (windows[i].source == source) then
			return windows[i];
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
