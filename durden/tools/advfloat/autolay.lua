-- simple "take constraints + list of nodes" (x, y, w, h),
-- update x, y positions and mark if it was used (fitted) or not
-- https://codeincomplete.com/posts/bin-packing/
local function simple_solver(nodes, w, h, nrest)
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
			v.used = true;
		end
	end

-- repeat for those that didn't fit and treat as a new "layer"
	local rest = {};
	for _,v in ipairs(nodes) do
		if (not v.used) then
			table.insert(rest, v);
		end
	end

-- avoid endless recursion with #rest != nrest
	if (#rest > 0 and (nrest == nil or nrest > #rest)) then
		w = w - 20; h = h - 20;
		local nodes = simple_solver(rest, w, h, #rest);
		for _,j in ipairs(nodes) do
			j.x = j.x + 20;
			j.y = j.y + 20;
			j.src:to_front();
		end
	end

	return nodes;
end

-- Find the nearest screen edge and move window out of the way, this has
-- the not-so-subtle bug that if the window or the display resizes while we
-- are "hidden" ore a window at the left/top edges resize, it will become
-- more visible. The more thorough solution would be to add display_
-- change hooks and resize handlers for each window, offsetting if the
-- window belong to the wrong edge
local function hide(nodes, w, h)
	for _,v in ipairs(nodes) do
-- find the nearest edge
		local nnx = -v.x - v.w;
		local npx = w - v.x;
		local nny = -v.y - v.h;
		local npy = h - v.y;
		local dx = math.abs(nnx) < math.abs(npx) and math.abs(nnx) or math.abs(npx);
		local dy = math.abs(nny) < math.abs(npy) and math.abs(nny) or math.abs(npy);

		local pad = 10 * v.src.wm.scalef;

-- reposition outside, add padding, disable clamping
		if (dx < dy) then
-- left
			if (math.abs(nnx) < math.abs(npx)) then
				v.x = 0 - v.w + pad + v.src.pad_right;
			else
				v.x = w - pad - v.src.pad_left;
			end
		else
-- top
			if (math.abs(nny) < math.abs(npy)) then
				v.y = 0 - v.h + pad + v.src.pad_bottom;
-- bottom
			else
				v.y = h - pad - v.src.pad_top +
					(v.src.titlebar.hidden and 0 or v.src.titlebar.height);
			end
		end
		v.noclamp = true;
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
			x = wnd.x,
			y = wnd.y,
			w = wnd.width,
			h = wnd.height,
		 ew = wnd.effective_w,
		 eh = wnd.effective_h
		}
	);
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
	for _, v in ipairs(lst) do
		if (not v.src.autolay_last) then
			v.src.autolay_last =
			{
				x = v.src.x / v.src.wm.width,
				y = v.src.y / v.src.wm.height,
			};
		end
		v.src:move(v.x, v.y + wm.yoffset, false, true, false, v.noclamp);
	end
end

local last_hide = false;
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
	name = "hide",
	label = "Hide",
	description = "Hide the windows around the edges of the screen",
-- actually acts as a flip-flop
	handler = function()
		if (last_hide) then
			run_layouter();
			last_hide = false;
		else
			run_layouter(hide);
			last_hide = true;
		end
	end
},
{
	kind = "action",
	name = "revert",
	label = "Revert",
	description = "Restore window positions to before last layouting operation",
	handler = function()
		last_hide = false;
		run_layouter();
	end
}
};
