-- track all our VIDs in this one
local active = {};
local ddisplay = nil;

-- and global state that may override per- item opacity
local hidden = false;

-- to cover all basics and invariants we just rerun this function,
-- costs a bit more than the most efficient solution but this really
-- doesn't matter here
local function relayout()
	local yofs = 0;
	if (not ddisplay) then
		ddisplay = active_display();
	end

	local maxw = ddisplay.width * gconfig_get("overlay_size");
	local maxh = ddisplay.height * gconfig_get("overlay_size");
	local cy = 0;
	for i=1,#active do
		local props = image_storage_properties(active[i]);
		link_image(active[i], active_display().order_anchor);
		image_inherit_order(active[i], true);
		rendertarget_attach(ddisplay.rtgt_id, active[i], RENDERTARGET_DETACH);
		blend_image(active[i], hidden and 0.0 or gconfig_get("overlay_opacity"));
		local ar = props.width / props.height;
		local wr = props.width / maxw;
		local hr = props.height/ maxh;
		local outw = hr > wr and maxh * ar or maxw;
		local outh = hr < wr and maxw / ar or maxh;
		shader_setup(active[i], "simple", gconfig_get("overlay_shader"));
		resize_image(active[i], outw, outh);
		move_image(active[i], gconfig_get("overlay_corner") == "left"
			and 0 or ddisplay.width - outw, cy);
		cy = cy + outh;
	end
end

local function delete_overlay(ind)
	if (active[ind] == nil) then
		return;
	end

	delete_image(active[ind]);
	table.remove(active[ind]);
	if (#active == 0) then
		ddisplay = nil;
	end
	relayout();
end

local function add_overlay(wnd)
-- don't permit overallocation of space
	if (#active >= math.floor(1.0 / gconfig_get("overlay_size"))) then
		return;
	end

-- can't assume there's VIDs left
	local overlay = null_surface(wnd.width, wnd.height);
	if (not valid_vid(overlay)) then
		return;
	end

-- share the backend, append and place/show
	image_sharestorage(wnd.canvas, overlay);
	table.insert(active, overlay);
	show_image(overlay);
	relayout();
end

-- config system hooks so the values get saved
gconfig_register("overlay_opacity", 1.0);
gconfig_register("overlay_corner", "left");
gconfig_register("overlay_shader", "noalpha");
gconfig_register("overlay_size", 0.1);

-- and trigger relayout of the user reconfigures
gconfig_listen("overlay_opacity", "overlay", relayout);
gconfig_listen("overlay_corner", "overlay", relayout);
gconfig_listen("overlay_shader", "overlay", relayout);
gconfig_listen("overlay_size", "overlay", relayout);

local overlay_cfg = {
{
	name = "corner",
	label = "Corner",
	kind = "value",
	initial = function()
		return gconfig_get("overlay_corner");
	end,
	set = {"Left", "Right"},
	handler = function(ctx, val)
		gconfig_set("overlay_corner", val);
	end
},
{
	name = "opacity",
	label = "Opacity",
	kind = "value",
	initial = function()
		return gconfig_get("overlay_opacity");
	end,
	validator = gen_valid_num(0.1, 1.0),
	handler = function(ctx, val)
		gconfig_set("overlay_opacity", tonumber(val));
	end
},
{
	name = "shader",
	label = "Shader",
	kind = "value",
	initial = function()
		return gconfig_get("overlay_shader");
	end,
	set = function()
		return shader_list({"effect", "simple"});
	end,
	handler = function(ctx, val)
		local key, dom = shader_getkey(val, {"effect", "simple"});
		gconfig_set("overlay_shader", key);
	end
},
-- slightly worse as we need to drop the overflow
{
	name = "size",
	label = "Size(%)",
	kind = "value",
	initial = function()
		return gconfig_get("overlay_size");
	end,
	hint = "0.05 .. 0.5",
	validator = gen_valid_num(0.05, 0.5),
	handler = function(ctx, val)
		gconfig_set("overlay_size", tonumber(val));
	end
}
};

local function gen_delete_menu()
	local res = {};
	for i=1,#active do
		table.insert(res,
		{
			name = tostring(i),
			label = tostring(i),
			kind = "action",
			handler = function(ctx)
				if (active[i]) then
					delete_image(active[i]);
					table.remove(active, i);
					relayout();
				end
			end
		});
	end
	return res;
end

local function gen_migrate_menu()
	local res = {};
	local cur = active_display(false, true).name;

	for d in all_displays_iter() do
		table.insert(res, {
			name = "migrate_" .. hexenc(d.name),
			label = d.name,
			kind = "action",
			handler = function()
				ddisplay = d.tiler;
				relayout();
			end
		});
	end

	return res;
end

local overlays =
{
	{
		name = "toggle",
		kind = "action",
		label = "Toggle",
		handler = function()
			hidden = not hidden;
			relayout();
		end
	},
	{
		name = "delete",
		kind = "action",
		label = "Delete",
		submenu = true,
		eval = function() return #active > 0; end,
		handler = function() return gen_delete_menu(); end
	},
	{
		name = "migrate",
		kind = "action",
		label = "Migrate",
		submenu = true,
		eval = function()
			return gconfig_get("display_simple") == false;
		end,
		handler = function()
			return gen_migrate_menu();
		end
	}
};

-- hook config, content control and the target- window
global_menu_register("settings/tools",
{
	name = "overlays",
	label = "Overlays",
	submenu = true,
	kind = "action",
	handler = overlay_cfg
});

global_menu_register("tools",
{
	name = "overlays",
	label = "Overlays",
	submenu = true,
	eval = function() return #active > 0; end,
	kind = "action",
	handler = overlays
});

shared_menu_register("window",
{
	name = "to_overlay",
	label = "Overlay",
	kind = "action",
	handler = function(ctx) add_overlay(active_display().selected); end
}
);
