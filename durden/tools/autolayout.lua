local function center_focus(space, mode, lin, neww)
	if (mode ~= "tile") then
		return;
	end

-- nothing to do
	if (#lin <= 1) then
		return;
	end

-- nothing in focus region? then use selected window
	local focus = space.children[2];
	if (not focus) then
		focus = space.selected;
	end

-- new "fair" window division
	local left = {};
	local right = {};
	local ctr = 1;
	for i=1,#lin do
		if (lin[i] ~= focus) then
			if (ctr % 2 == 0) then
				table.insert(left, lin[i]);
			else
				table.insert(right, lin[i]);
			end
			ctr = ctr + 1;
		end
	end

	local lvweight = #left > 0 and 1.0 / #left or 1.0;
	local rvweight = #right > 0 and 1.0 / #right or 1.0;

-- set horizontal weight to be 10 80 10
	space.children = {};
	focus.children = {};

	local ind = 1;
	if (left[1] == nil) then
		ind = ind - 1;
		focus.weight = 1.7;
	else
		space.children[ind] = left[1];
		space.children[ind].parent = space;
		left[1].weight = 0.3;
		left[1].vweight = lvweight;
		focus.weight = 2.4;
	end
	focus.parent = space;
	space.children[ind+1] = focus;
	space.children[ind+2] = right[1];
	if (right[1]) then
		right[1].weight = 0.3;
		right[1].vweight = rvweight;
		right[1].parent = space;
	end

	last = space.children[1];
	for i=2,#left do
		left[i].parent = last;
		last.children = {left[i]};
		left[i].vweight = lvweight * (i-1);
		left[i].weight = 1.0;
		last = left[i];
	end
	if (last) then
		last.children = {};
	end

	last = space.children[3];
	if (last) then
		for i=2,#right do
			right[i].parent = last;
			last.children = {right[i]};
			rvweight = rvweight + rvweight;
			right[i].vweight = last.vweight + rvweight;
			right[i].weight = 1.0;
			last = right[i];
		end
		last.children = {};
	end

-- return false will have the space resize continue
end

local function swap_focus(sel)
	local sp = active_display().active_space;
	local sw = active_display().selected;
	local dw = sp.children[2];
	if (not sp or #sp.children <= 2 or not sw) then
		return;
	end

	if (sw ~= dw) then
		sw.last = dw;
		sw:swap(dw);

	elseif (dw.last and dw.last.swap) then
		dw.last.last = dw;
		dw:swap(dw.last);
	end

	if (sel) then
		sp.children[2]:select();
	end

	sp:resize();
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
			space.layouter = center_focus;
			space:resize();
		end
	end,
},
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
		if (space) then
			local lst = space:linearize();
			for k,v in ipairs(lst) do
				v.weight = 1.0;
				v.vweight = 1.0;
			end
			space.layouter = nil;
			space:resize();
		end
	end,
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
