-- simple "take constraints + list of nodes" (x, y, w, h),
-- update x, y positions and mark if it was used (fitted) or not
-- https://codeincomplete.com/posts/bin-packing/
local function simple_solver(nodes, w, h)
	table.sort(nodes, function(a, b) return a.h > b.h; end);

	local get_node;
	get_node = function(n, w, h)
		if (n.used) then
			local r = get_node(n.r, w, h);
			if (r) then
				return r;
			else
				return get_node(n.d, w, h);
			end
		elseif (w <= n.w and h <= n.h) then
			n.used = true;
			n.d = {x = n.x,     y = n.y + h, w = n.w,     h = n.h - h};
			n.r = {x = n.x + w, y = n.y,     w = n.w - w, h = h      };
			return n;
		end
	end

	local root = {x = 0, y = 0, w = w, h = h};
	for _, v in ipairs(nodes) do
		local n = get_node(root, v.w, v.h);
		if (n) then
			v.x = n.x; v.y = n.y;
		end
	end
	return nodes;
end

local function run_layouter(method)
	local wm = active_display();
	local space = wm.spaces[wm.space_ind];
	local lst = {};

-- special cases, windows with an assigned 'toplevel' (wayland..)
	for _,wnd in ipairs(space:linearize()) do
		table.insert(lst, {src = wnd,
			x = wnd.x, y = wnd.y, w = wnd.width, h = wnd.height});
	end
	if (#lst == 0) then
		return;
	end
	if (not method) then
		for _, v in ipairs(lst) do
			if (v.src.autolay_last) then
				v.src:move(
					v.src.autolay_last.x * v.src.wm.width,
					v.src.autolay_last.y * v.src.wm.height, false, true
				);
				v.src.autolay_last = nil;
			end
		end
		return;
	end

	lst = method(lst, wm.effective_width, wm.effective_height);
	local props = image_surface_resolve(wm.anchor);
	for _, v in ipairs(lst) do
		v.src.autolay_last =
		{
			x = v.src.x / v.src.wm.width,
			y = v.src.y / v.src.wm.height
		};
		v.src:move(v.x + props.x, v.y + props.y, false, true);
	end
end

return {
{
	kind = "action",
	name = "simple",
	label = "Simple",
	description = "Sort by height and recursive binary fill",
	handler = function()
		run_layouter(simple_solver);
	end
},
{
	kind = "action",
	name = "revert",
	label = "Revert",
	description = "Restore window positions to before last layouting operation",
	handler = function()
		run_layouter();
	end
}
};
