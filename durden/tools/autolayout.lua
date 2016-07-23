-- returning true means we took responsibility for attaching to parent
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

local function center_setup(space)
	local lin = space:linearize();
-- nothing in focus region? then use selected window
	local focus = space.children[2];
	if (not focus) then
		focus = space.selected;
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
		lin[i].vweight = 1.0;
		if (lin[i] ~= focus) then
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

-- set horizontal weight to be 10 80 10 or 10 [80 yet expand to 90]
	space.children = {left[1], focus, right[1]};
	focus.children = {};
	focus.weight = right[1] and 2.4 or 1.8;
	focus.parent = space;

	left[1].parent = space;
	left[1].weight = 0.3;
	left[1].children = {};

	if (right[1]) then
		right[1].weight = 0.3;
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

	if (space.selected == dst) then
		return;
	end

	if (space.selected) then
		space.selected:deselect();
	end

	dst:select();
end

-- return true? then we take responsibility for marking selected and insertion
local function center_added(space, wnd)
	if (#space.children ~= 3) then
		table.insert(space.children, wnd);
		wnd.parent = space;
		center_setup(space);
		center_focus(space);
		space:resize();
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
	center_focus(space);
	space:resize();
	return true;
end

local function center_lost(space, wnd, destroy)
-- priority is balance the first entry
	if (#space.children ~= 3) then
		center_setup(space);
		center_focus(space);
		space:resize();
		return true;
	end

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

	center_focus(space);
	space:resize();
	return true;
end

local function center_resize(space, lin, evblock)
	if (evblock) then
-- always forward the dimensions of the center space
	end
-- just forward to the next layer
end

local function swap_focus(sel)
	local sp = active_display().active_space;
	local sw = active_display().selected;
	local dw = sp.children[2];
	if (not sp or #sp.children <= 2 or not sw) then
		return;
	end

	dw.center_focus = false;
	if (sw ~= dw) then
		sw.last = dw;
		sw:swap(dw, false, true);
		sw.center_focus = true;

	elseif (dw.last and dw.last.swap) then
		dw.last.last = dw;
		dw.last.center_focus = true;
		dw:swap(dw.last, false, true);
	end

	if (sel) then
		sp.children[2]:select();
	end
	sp:resize();
end

local function center_free(space)
	local lst = space:linearize();
	for k,v in ipairs(lst) do
		v.weight = 1.0;
		v.vweight = 1.0;
	end

	space.layouter = nil;
	space:resize();
end

-- ONLY REGISTRATION / MENU SETUP BOILERPLATE BELOW --

local function copy(intbl)
	local res = {};
	for k,v in pairs(intbl) do res[k] = v; end
	return res;
end

local cfl = {
	resize = center_resize,
	added = center_added,
	lost = center_lost,
	cleanup = center_free,

-- control all "normal" operations
	block_grow = true,
	block_merge = true,
	block_collapse = true,
	block_swap = true
};

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
			space.layouter = copy(cfl);
			center_setup(space);
			space:resize();
		end
	end,
},
-- {
--	name = "center_scale",
--	label = "Center Focus (Force-Scale)",
--	kind = "action",
--	eval = function()
--		return active_display().active_space ~= nil;
--	end,
--	handler = function()
--		local space = active_display().active_space;
--		if (space) then
--			space.layouter = copy(cfl);
--			space.layouter.block_rzevent = true;
--			center_setup(space);
--			space:resize();
--		end
--	end
--},
{
	name = "none",
	label = "Default",
	kind = "action",
	eval = function()
		local d = active_display();
		return d.active_space and d.active_space.layouter;
	end,
	handler = function()
		local space = active_display().active_space;
		space.layouter.cleanup(space);
	end
}
}

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
	handler = function() swap_focus(); end
});

shared_menu_register("window/swap",
{
	name = "swap_sel",
	label = "Swap-Select(Focus)",
	kind = "action",
	handler = function()
		swap_focus(true);
	end
});
