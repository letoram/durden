-- font hint translation tables
local hint_lut = {
	none = 0,
	mono = 1,
	light = 2,
	normal = 3,
	subpixel = 4 -- need to specify +1 in the case of rotated display
};
local hint_rlut = {};
for k,v in pairs(hint_lut) do
	hint_rlut[v] = k;
end

local function run_group(group, prefix, wnd)
	local ad = active_display();
	local as = ad.selected;

-- hack around the problem with many menu paths written using the dumb
-- active_display().selected
	if (wnd) then
		ad.selected = wnd;
	end

-- this doesn't check / account for reattachments/migrations etc.
	if (group and type(group) == "table") then
		for k,v in ipairs(group) do
			if (type(v) == "string" and string.starts_with(v, prefix)) then
				dispatch_symbol(v);
			end
		end
	end

-- and restore if we didn't destroy something, but this method isn't safe
-- from modification, and that's mentioned in the documentation
	if (as and as.canvas) then
		ad.selected = as;
	end
end

local function run_domain(group, pal, set)
	run_group(group, "/global/", nil);
	if (set) then
-- need a copy to survive UAF- self modification
		local lst = {};
		for k,v in ipairs(set) do
			table.insert(lst, v);
		end
		for i,wnd in ipairs(lst) do
			if (wnd.canvas) then
				run_group(group, "/target/", wnd);
			end
			apply_scheme(pal, wnd);
		end
	end
end

local function tryload_scheme(v)
	local res = system_load(v, 0);
	if (not res) then
		warning(string.format("devmaps/schemes, system_load on %s failed", v));
		return;
	end

	local okstate, tbl = pcall(res);
	if (not okstate) then
		warning(string.format("devmaps/schemes, couldn't parse/extract %s", v));
		return;
	end

-- FIXME: [a_Z,0-9 on name]
	if (type(tbl) ~= "table" or not tbl.name or not tbl.label) then
		warning(string.format("devmaps/schemes, no name/label field for %s", v));
		return;
	end

-- pretty much all fields are optional as it stands
	return tbl;
end

local schemes;
local function scan_schemes()
	schemes = {};
	local list = glob_resource("devmaps/schemes/*.lua", APPL_RESOURCE);
	for i,v in ipairs(list) do
		local res = tryload_scheme("devmaps/schemes/" .. v);
		if (res) then
			table.insert(schemes, res);
		end
	end
end


function ui_scheme_menu(scope, tgt)
	local res = {};
	if (not schemes) then
		scan_schemes();
		if (not schemes) then
			return;
		end
	end

	for k,v in ipairs(schemes) do
		table.insert(res, {
			name = v.name,
			label = v.label,
			kind = "action",
			handler = function()
				if (scope == "global") then
					local lst = {};
					for wnd in all_windows(true) do
						table.insert(lst, wnd);
					end
					run_domain(v.actions, v.palette, lst);
				elseif (scope == "display") then
					local lst = {};
					for i, wnd in ipairs(tgt.windows) do
						table.insert(lst, wnd);
					end
					run_domain(v.actions, nil, lst);
					run_domain(v.display, v.palette, lst);
				elseif (scope == "workspace") then
					local lst = {};
					for i,v in ipairs(tgt.children) do
						table.insert(lst, v);
					end
					run_domain(v.actions, nil, lst);
					run_domain(v.workspace, v.palette, lst);
				elseif (scope == "window") then
					run_domain(v.actions, nil, {tgt});
					run_domain(v.window, v.palette, {tgt});
				end
			end
		});
	end

	return res;
end

local durden_font = {
	{
		name = "size",
		label = "Size",
		kind = "value",
		description = "Change the default UI font pt size",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("font_sz", tonumber(val));
		end
	},
	{
		name = "hinting",
		label = "Hinting",
		kind = "value",
		description = "Change anti-aliasing hinting algorithm",
		set = {"none", "mono", "light", "normal", "subpixel"},
		initial = function() return hint_lut[gconfig_get("font_hint")]; end,
		handler = function(ctx, val)
			gconfig_set("font_hint", hint_lut[val]);
		end
	},
	{
		name = "name",
		label = "Font",
		kind = "value",
		description = "Set the default font used for UI elements",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		initial = function() return gconfig_get("font_def"); end,
		handler = function(ctx, val)
			gconfig_set("font_def", val);
		end
	},
	{
		name = "fbfont",
		label = "Fallback",
		kind = "value",
		description = "Set the fallback font used for missing glyphs (emoji, symbols)",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		initial = function() return gconfig_get("font_fb"); end,
		handler = function(ctx, val)
			gconfig_set("font_fb", val);
		end
	}
};

-- (1 is used for alpha, the k/v mapping comes from tui
local function key_to_graphmode(k)
	local tbl = {
		primary = 2,
		secondary = 3,
		background = 4,
		text = 5,
		cursor = 6,
		altcursor = 7,
		highlight = 8,
		label = 9,
		warning = 10,
		error = 11,
		alert = 12,
		inactive = 13
	};
	return tbl[k];
end

local function append_color_menu(v, tbl, update_fun)
	local r = tonumber(string.sub(v, 3, 4), 16);
	local g = tonumber(string.sub(v, 5, 6), 16);
	local b = tonumber(string.sub(v, 7, 8), 16);
	tbl.kind = "value";
	tbl.hint = "(r g b)(0..255)";
	tbl.initial = string.format("%.0f %.0f %.0f", r, g, b);
	tbl.validator = suppl_valid_typestr("fff", 0, 255, 0);
	tbl.handler = function(ctx, val)
		local tbl = suppl_unpack_typestr("fff", val, 0, 255);
		if (not tbl) then
			return;
		end
		update_fun(string.format("\\#%02x%02x%02x", tbl[1], tbl[2], tbl[3]));
	end
end

local function gen_palette_menu()
	local list = {};
	for i,v in ipairs(HC_PALETTE) do
		local tbl = {
			name = "hc_ind_" .. tostring(i),
			format = HC_PALETTE[i],
			label = "COLOR_" .. tostring(i)
		};
		append_color_menu(v, tbl, function(new)
			HC_PALETTE[i] = new;
		end);
		table.insert(list, tbl);
	end
	return list;
end

local color_menu = {
{
	name = "hc_palette",
	kind = "action",
	label = "Palette",
	submenu = true,
	description = "High contrast palette, used for file browser and widgets",
	handler = gen_palette_menu()
},
{
-- text color
-- label color
-- alertstr
-- labelstr
-- menulblstr
-- menulblselstr
-- helperstr
-- errstr
-- seltextstr
-- pretiletext_color
-- tbar_textstr
}
};

local function apply_scheme(palette, wnd)
	if (palette and valid_vid(wnd.external, TYPE_FRAMESERVER)) then
-- used to convey alpha, color scheme, etc. primarily for TUIs
		for k,v in ipairs(palette) do
			local ind = key_to_graphmode(k);
			if (ind and type(v) == "table" and #v == 3) then
				target_graphmode(wnd.external, ind, v[1], v[2], v[3]);
			else
				warning("apply_scheme(), broken key " .. k);
			end
		end
-- commit
		target_graphmode(wnd.external, 0);
	end
end

return {
-- thickness is dependent on area, make sure the labels and
-- constraints update dynamically
	{
		name = "font",
		label = "Font",
		kind = "action",
		submenu = true,
		description = "Generic UI font settings",
		handler = durden_font
	},
	{
		name = "bars",
		label = "Bars",
		kind = "action",
		submenu = true,
		description = "Controls/Settings for titlebars and the statusbar",
		handler = system_load("menus/global/bars.lua")
	},
	{
		name = "border",
		label = "Border",
		kind = "action",
		submenu = true,
		description = "Global window border style and settings",
		handler = system_load("menus/global/border.lua")
	},
	{
		name = "shaders",
		label = "Shaders",
		kind = "action",
		submenu = true,
		description = "Control/Tune GPU- accelerated UI and display effects",
		handler = system_load("menus/global/shaders.lua")();
	},
	{
		name = "mouse_scale",
		label = "Mouse Scale",
		kind = "value",
		hint = "(0.1 .. 10.0)",
		description = "Change the base scale factor used for the mouse cursor",
		initial = function() return tostring(gconfig_get("mouse_scalef")); end,
		handler = function(ctx, val)
			gconfig_set("mouse_scalef", tonumber(val));
			display_cycle_active(true);
		end
	},
	{
		name = "anim_speed",
		label = "Animation Speed",
		kind = "value",
		hint = "(1..100)",
		description = "Change the animation speed used for UI elements",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("animation")); end,
		handler = function(ctx, val)
			gconfig_set("animation", tonumber(val));
		end
	},
	{
		name = "trans_speed",
		label = "Transition Speed",
		kind = "value",
		hint = "(1..100)",
		description = "Change the animation speed used in state transitions",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("transition")); end,
		handler = function(ctx, val)
			gconfig_set("transition", tonumber(val));
		end
	},
	{
		name = "wnd_speed",
		label = "Window Animation Speed",
		kind = "value",
		hint = "(0..50)",
		description = "Change the animation speed used with window position/size",
		validator = gen_valid_num(0, 50),
		initial = function() return tostring(gconfig_get("wnd_animation")); end,
		handler = function(ctx, val)
			gconfig_set("wnd_animation", tonumber(val));
		end
	},
	{
		name = "anim_in",
		label = "Transition-In",
		kind = "value",
		description = "Change the effect used when moving a workspace on-screen",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_in")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_in", val);
		end
	},
	{
		name = "anim_out",
		label = "Transition-Out",
		kind = "value",
		description = "Change the effect used when moving a workspace off-screen",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_out")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_out", val);
		end
	},
	{
		name = "colors",
		label = "Colors",
		description = "Special colors that are not shader- defined or decorations",
		kind = "action",
		submenu = true,
		handler = color_menu
	},
	{
		name = "menu_helper",
		label = "Menu Descriptions",
		description = "Set if this helper text should be shown or not",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("menu_helper") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("menu_helper")
	}
};
