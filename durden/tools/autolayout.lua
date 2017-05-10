-- returning true means we took responsibility for attaching to parent
local swap_focus;

local function save_wnd(wnd)
	wnd.old = {
		autocrop = wnd.autocrop,
		shader = image_shader(wnd.canvas),
		scalemode = wnd.scalemode,
		hidetbar = wnd.hide_titlebar
	};
end

local function restore_wnd(wnd)
	if (not wnd.old) then
		return;
	end

	if (wnd.old.shader > 0) then
		image_shader(wnd.canvas, wnd.old.shader);
	else
		image_shader(wnd.canvas, "DEFAULT");
	end

	wnd.scalemode = wnd.old.scalemode;
	wnd.autocrop = wnd.old.autocrop;
	wnd.hide_titlebar = wnd.old.hidetbar;
	wnd.displayhint_block_wh = false;
	show_image(wnd.anchor);
	wnd:set_title();
end

-- "center" means normal behavior and the active shader for the window
local function center_imgcfg(wnd)
	show_image(wnd.anchor);
	if (wnd.space and not wnd.space.layouter) then
		print("dangling layouter", debug.traceback());
	end

	if (wnd.space and not wnd.space.layouter.scaled) then
		return;
	end

	wnd.displayhint_block_wh = true;
	if (not wnd.old) then
		save_wnd(wnd);
	end

	restore_wnd(wnd);
end

-- "side" means stretch, optional blend and a normal shader
local function side_imgcfg(wnd)
	blend_image(wnd.anchor, gconfig_get("autolay_sideopa"));
	if (wnd.space and not wnd.space.layouter.scaled) then
		return;
	end

-- first cache original values so we can restore when reassigning
	if (not wnd.old) then
		save_wnd(wnd);
	end
	wnd.scalemode = "stretch";
	wnd.autocrop = false;
	wnd.displayhint_block_wh = true;

	image_set_txcos_default(wnd.canvas, wnd.origo_ll);
	if (gconfig_get("autolay_shader")) then
		shader_setup(wnd.canvas, "simple", gconfig_get("autolay_sideshdr"));
	end

-- swap to side, maybe disable titlebar
	wnd.hide_titlebar = not gconfig_get("autolay_sidetbar");
	wnd:set_title();
end

local function sel_h(wnd, mouse)
	if (mouse and not dispatch_locked()) then
		if (gconfig_get("autolay_selswap")) then
			swap_focus(wnd);
		end
	end
end

-- trigger if window baseclass changes
local function reg_h(wnd)
	if (not wnd.space) then
		return;
	end

	save_wnd(wnd);
	if (wnd.space.children[2] == wnd) then
		center_imgcfg(wnd);
	else
		side_imgcfg(wnd);
	end
end

local function center_setup(space)
	local lin = space:linearize();
-- nothing in focus region? then use selected window
	local focus = space.children[2];
	if (space.children[1]) then
		if (space.children[1].center_focus) then
			focus = space.children[1];
		end
	end

	if (not focus) then
		focus = space.selected;
	end

	if (focus) then
		center_imgcfg(focus);
	end

-- nothing to do
	if (#lin <= 1) then
		return;
	end
	focus.center_focus = true;

-- new "fair" window division of the remaining windows
	local left = {};
	local right = {};
	local ctr = 1;
	for i=1,#lin do
		lin[i]:add_handler("register", reg_h);
		lin[i]:add_handler("select", sel_h);
		lin[i].vweight = 1.0;
		if (lin[i] ~= focus) then
			lin[i].center_focus = false;
			side_imgcfg(lin[i]);

			if (ctr % 2 == 1) then
				table.insert(left, lin[i]);
			else
				table.insert(right, lin[i]);
			end
			ctr = ctr + 1;
		end
	end

-- edge condition, ignore due to lost still left in structure can get us here
	if (0 == #left and 0 == #right) then
		return;
	end

	local ccount = right[1] and 3 or 2;
	local mw = ccount * gconfig_get("autolay_centerw");
	local rw = (ccount - mw) / (ccount - 1);
-- set horizontal weight to be 10 80 10 or 10 [80 yet expand to 90]
	space.children = {left[1], focus, right[1]};
	focus.children = {};
	focus.weight = mw;
	focus.parent = space;

	left[1].parent = space;
	left[1].weight = rw;
	left[1].children = {};

	if (right[1]) then
		right[1].weight = rw;
		right[1].parent = space;
		right[1].children = {};
	end

	for i=2,#left do
		left[i].parent = left[i-1];
		left[i].parent.children[1] = left[i];
		left[i].children = {};
	end

	for i=2,#right do
		right[i].parent = right[i-1];
		right[i].parent.children[1] = right[i];
		right[i].children = {};
	end

	space.children[2]:select();
end

-- all the edge cases to make sure center area is priority-focus and not
-- running into multiple :select or :deselect calls on the same object
-- breaking state
local function center_focus(space)
	local dst = space.children[2] and space.children[2] or space.children[1];
	if (not dst) then
		return;
	end

	space.layouter.cw = dst.max_w;
	space.layouter.ch = dst.max_h;

	if (space.selected == dst) then
		return;
	end

	if (space.selected) then
		space.selected:deselect();
	end
end

-- find out how many levels of children a specific node has, needed to calc
-- fair vertical weight when doing column- relayouting
local function get_depth(node)
	local depth = 0;
	local last = node;

	while node do
		last = node;
		depth = depth + 1;
		node = node.children[1];
	end

	return depth, last;
end

-- return true? then we take responsibility for marking selected and insertion
local function center_added(space, wnd)
	if (not wnd.old) then
		save_wnd(wnd);
	end

	if (#space.children ~= 3) then
		table.insert(space.children, wnd);
		wnd.parent = space;
		center_setup(space);
		space:resize();
		center_focus(space);
		return true;
	end

-- find the least used column
	local ld = get_depth(space.children[1]);
	local rd = get_depth(space.children[3]);
	local dst;
	local ind = ld < rd and 1 or 3;

	local dst = space.children[ind];

-- go to the deepest slot
	while true do
		if (not dst.children[1]) then
			break;
		else
			dst = dst.children[1];
		end
	end

-- insert there
	dst.children[1] = wnd;
	wnd.parent = dst;

-- make sure sizes are fair
	side_imgcfg(wnd);
	wnd:add_handler("register", reg_h);
	wnd:add_handler("select", sel_h);
	center_focus(space);
	space:resize();
	return true;
end

local function center_lost(space, wnd, destroy)
-- priority is balance the first entry
	if (#space.children ~= 3) then
		center_setup(space);
		space:resize();
		center_focus(space);
		return true;
	end


-- rebalance columns if the number of nodes in each gets unevenly distributed
	local ld, ln = get_depth(space.children[1]);
	local rd, rn = get_depth(space.children[3]);

	if (ld > rd + 1) then
		ln.parent.children[1] = nil;
		rn.children[1] = ln;
		ln.parent = rn;
	elseif (rd > ld + 1) then
		rn.parent.children[1] = nil;
		ln.children[1] = rn;
		rn.parent = ln;
	end

	if (not destroy) then
		restore_wnd(wnd);
		wnd:drop_handler("register", reg_h);
		wnd:drop_handler("select", sel_h);
	end

	local mw = (3 - 3 * gconfig_get("autolay_centerw")) / 2;

-- ugly edge condition, if we migrate or destroy a child to the first
-- or last node, it can be promoted to first level with no event for us to
-- latch on to, therefore force- reset the weights.
	space.children[1].weight = mw;
	space.children[3].weight = mw;

	center_focus(space);
	space:resize();
	return true;
end

local function center_resize(space, lin, evblock, wnd, cb)

-- this layouter can only deal with tiling mode
	if (space.mode ~= "tile") then
		if (lin) then
			for i,v in ipairs(lin) do
				restore_wnd(v);
			end
		end
		return false;
	end

	if (evblock) then
-- always forward the dimensions of the center space, block if this
-- corresponds to last known "column" size as a catch all for some async. races
		if (space.children[2]) then
			local mw = space.children[2].max_w;
			local mh = space.children[2].max_h;
			local dw = space.children[2].width - space.children[2].effective_w;
			local dh = space.children[2].height - space.children[2].effective_h;

			if (not space.layouter.scaled or (not space.layouter.cw or
				(mw == space.layouter.cw and mh == space.layouter.ch))) then
				cb(mw, mh, mw - dw, mh - dh);
			end
		end
		return true;
	end
	if (not active_display().selected) then
		if (space.children[2]) then
			space.children[2]:select();
		elseif (space.children[1]) then
			space.children[1]:select();
		end
	end
-- just forward to the next layer
end

swap_focus = function(sel)
	local sp = active_display().active_space;
	local sw = active_display().selected;
	local dw = sp.children[2];
	if (not sp or #sp.children < 2 or not sw) then
		return;
	end

	local cw = dw.max_w;
	local ch = dw.max_h;
	local cx = dw.x;
	local cy = dw.y;
	dw.center_focus = false;

-- swap and maipulate allowed / perceived dimensions as the swap function
-- does not do that, otherwise we risk one additional space- resize
	if (sw ~= dw) then
		local rw = sw.max_w;
		local rh = sw.max_h;

		sw.last = dw;
		sw.center_focus = true;
		sw.max_w = cw; sw.max_h = ch;
		sw:swap(dw, false, true);
		center_imgcfg(sw);
		sw:resize(cw, ch);
		dw.x = sw.x; dw.y = sw.y;
		dw.max_w = rw; dw.max_h = rh;
		sw.x = cx; sw.y = cy;
		side_imgcfg(dw);

-- mask the event propagation if we're running in scaled- mode
		dw:resize(rw, rh, false, true);
		dw:reposition();

-- "swap-in", use [last] reference for the window to swap
	elseif (dw.last and dw.last.swap) then
		local newc = dw.last;
		newc.last = dw;
		newc.center_focus = true;
		dw.max_w = newc.max_w;
		dw.max_h = newc.max_h;
		newc.max_w = cw;
		newc.max_h = ch;
		dw:swap(newc, false, true);
		center_imgcfg(newc);
		newc:resize(cw, ch);
		dw.x = newc.x; dw.y = newc.y;
		newc.x = cx; newc.y = cy;
		side_imgcfg(dw);
		dw:resize(dw.max_w, dw.max_h, false, true);
	end

	if (sel) then
		sp.children[2]:select();
	end

 sp:resize(true);
end

local function center_free(space)
	local lst = space:linearize();
	for k,v in ipairs(lst) do
		restore_wnd(v);
		v.weight = 1.0;
		v.vweight = 1.0;
		v:drop_handler("register", reg_h);
		v:drop_handler("select", sel_h);
	end

	space.layouter = nil;
	space:resize();
end

-- book layouter is a horizontal/flat layout where a specific ration is
-- designated to the 'main' area (children[1]) and the rest will be 'evenly'
-- divided across the remaining area. Instad of scaling, we crop by
-- manipulating texture coordinates. The switch operation works like turning a
-- page. All pages are resized to fit the main area, so there are no resize
-- cascades.
local function book_resize(space, lin, evblock, wnd, cb)
end

local function book_added(space, wnd)
end

local function book_lost(space, wnd, destroy)
end

local function book_free(space)

end

-- ONLY REGISTRATION / MENU SETUP BOILERPLATE BELOW --

local function copy(intbl)
	local res = {};
	for k,v in pairs(intbl) do res[k] = v; end
	return res;
end

local book_layouter = {
	resize = book_resize,
	added = book_added,
	lost = book_lost,
	cleanup = book_free,
	block_grow = true,
	block_merge = true,
	block_collapse = true,
	block_swap = true
};

local centerscale_layouter = {
	resize = center_resize,
	added = center_added,
	lost = center_lost,
	cleanup = center_free,

-- control all "normal" operations
	block_grow = true,
	block_merge = true,
	block_collapse = true,
	block_swap = true,
	scaled = true,
	block_rzevent = true
};

local center_layouter = {
	resize = center_resize,
	added = center_added,
	lost = center_lost,
	cleanup = center_free,

-- control all "normal" operations
	block_grow = true,
	block_merge = true,
	block_collapse = true,
	block_swap = true,
	scaled = false,
	block_rzevent = false
};

local function set_layouter(space, layouter)
	space.layouter = copy(layouter);
	center_setup(space);
	space:resize();
	center_focus(space);
end

local layouters = {
{
	name = "center",
	label = "Center Focus",
	kind = "action",
	eval = function()
		return active_display().active_space ~= nil;
	end,
	handler = function()
		local space = active_display().active_space;
		if (space) then
			set_layouter(space, center_layouter);
		end
	end,
},
{
	name = "center_scale",
	label = "Center Focus (Force-Scale)",
	kind = "action",
	eval = function()
		return active_display().active_space ~= nil;
	end,
	handler = function()
		set_layouter(active_display().active_space, centerscale_layouter);
	end
},
{
	name = "book",
	label = "Book",
	kind = "action",
	eval = function()
		return false;
		--active_display().active_space ~= nil;
	end,
	handler = function()
		set_layouter(active_display().active_space, book_layouter);
	end
},
{
	name = "none",
	label = "Default",
	kind = "action",
	eval = function()
		local d = active_display().active_space;
		return d and d.layouter;
	end,
	handler = function()
		local space = active_display().active_space;
		space.layouter.cleanup(space);
	end
}
}

-- recurse down the side columns and make their properties reflect side-cfg
local function update_space(space)
	for i,v in ipairs({1, 3}) do
		local a = space.children[v];
		while (a) do
			side_imgcfg(a);
			a = a.children[1];
		end
	end
end

-- add new config-db keys
gconfig_register("autolay_sideopa", 0.5);
gconfig_register("autolay_selswap", true);
gconfig_register("autolay_centerw", 0.8);
gconfig_register("autolay_sidetbar", true);
gconfig_register("autolay_sideshdr", "noalpha");
gconfig_register("autolay_shader", false);

local function reconfig()
	for tiler in all_tilers_iter() do
-- for all workspaces that uses this layouter, rebuild the layout to
-- reflect changes in weights, titlebar, etc.
		for i=1, 10 do
			if (tiler.spaces[i] and tiler.spaces[i].layouter and
				tiler.spaces[i].layouter.scaled and
				tiler.spaces[i].layouter.resize == center_resize) then
				update_space(tiler.spaces[i]);
			end
		end
	end
end

-- and triggers for config change
gconfig_listen("autolay_sideshdr", "autolayshdr", reconfig);
gconfig_listen("autolay_sidetbar", "autolaytb", reconfig);
gconfig_listen("autolay_sideopa", "autolayh", reconfig);

-- and menu entries
local laycfg = {
{
	name = "sideopa",
	label = "Side-Opacity(Scaled)",
	kind = "value",
	initial = function() return gconfig_get("autolay_sideopa"); end,
	validator = gen_valid_float(0.0, 1.0),
	handler = function(ctx, val)
		gconfig_set("autolay_sideopa", tonumber(val));
	end
},
{
	name = "selswap",
	label = "Mouse-SelectSwap",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	initial = function()
		return gconfig_get("autolay_selswap") and LBL_YES or LBL_NO;
	end,
	handler = function(ctx, val)
		gconfig_set("autolay_selswap", val == LBL_YES);
	end
},
{
	name = "centersz",
	label = "Center Weight",
	kind = "value",
	initial = function()
		return gconfig_get("autolay_centerw");
	end,
	hint = "0.5 .. 0.9",
	validator = gen_valid_float(0.5, 0.9),
	handler = function(ctx, val)
		gconfig_set("autolay_centerw", tonumber(val));
	end
},
{
	name = "sidetbar",
	label = "Side Titlebar",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	initial = function()
		return gconfig_get("autolay_sidetbar") and LBL_YES or LBL_NO;
	end,
	handler = function(ctx, val)
		gconfig_set("autolay_sidetbar", val == LBL_YES);
	end
},
{
	name = "sideshader",
	label = "Side Shader",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	initial = function()
		return gconfig_get("autolay_shader") and LBL_YES or LBL_NO;
	end,
	handler = function(ctx, val)
		gconfig_set("autolay_shader", val == LBL_YES);
	end
},
{
	name = "sideshader_value",
	label = "Side Shader-Select",
	initial = function()
		return gconfig_get("autolay_sideshdr");
	end,
	eval = function()
		return gconfig_get("autolay_shader");
	end,
	kind = "value",
	set = function() return shader_list({"effect", "simple"}); end,
	handler = function(ctx, val)
		local key, dom = shader_getkey(val, {"effect", "simple"});
		if (key ~= nil) then
			gconfig_set("autolay_sideshdr", key);
		end
	end
}
};

global_menu_register("settings/tools",
{
	name = "autolayouts",
	label = "Auto Layouting",
	submenu = true,
	kind = "action",
	handler = laycfg
});

global_menu_register("tools",
{
	name = "autolayouts",
	label = "Auto Layouting",
	submenu = true,
	kind = "action",
	handler = layouters
});

shared_menu_register("window/swap",
{
	name = "swap",
	label = "Swap(Focus)",
	kind = "action",
	eval = function()
		return active_display().selected and
			active_display().selected.space.layouter;
	end,
	handler = function() swap_focus(); end
});

shared_menu_register("window/swap",
{
	name = "swap_sel",
	label = "Swap-Select(Focus)",
	kind = "action",
	eval = function()
		return active_display().selected and
			active_display().selected.space.layouter;
	end,
	handler = function()
		swap_focus(true);
	end
});
