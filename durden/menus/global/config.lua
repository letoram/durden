hint_lut = {
	none = 0,
	mono = 1,
	light = 2,
	normal = 3,
	subpixel = 4 -- need to specify +1 in the case of rotated display
};

TERM_HINT_RLUT = {};
for k,v in pairs(hint_lut) do TERM_HINT_RLUT[v] = k; end

-- populated on tool loading
local tools_conf = {
};

local durden_font = {
	{
		name = "size",
		label = "Size",
		kind = "value";
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
		set = {"none", "mono", "light", "normal", "subpixel"},
		initial = function() return TERM_HINT_RLUT[gconfig_get("font_hint")]; end,
		handler = function(ctx, val)
			gconfig_set("font_hint", hint_lut[val]);
		end
	},
	{
		name = "name",
		label = "Font",
		kind = "value",
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

local durden_bars = {
	{
		name = "sb_top",
		label = "Pad Top",
		kind = "value",
		initial = function() return gconfig_get("sbar_tpad"); end,
		validator = function() return gen_valid_num(0, gconfig_get("sbar_sz")); end,
		handler = function(ctx, val)
			gconfig_set("sbar_tpad", tonumber(val));
			gconfig_set("tbar_tpad", tonumber(val));
			gconfig_set("lbar_tpad", tonumber(val));
		end
	},
	{
		name = "sb_bottom",
		label = "Pad Bottom",
		kind = "value",
		initial = function() return gconfig_get("sbar_bpad"); end,
		validator = function() return gen_valid_num(0, gconfig_get("sbar_sz")); end,
		handler = function(ctx, val)
			gconfig_set("sbar_bpad", tonumber(val));
			gconfig_set("tbar_bpad", tonumber(val));
			gconfig_set("lbar_bpad", tonumber(val));
		end
	},
	{
		name = "tb_pattern",
		label = "Titlebar(Pattern)",
		kind = "value",
		initial = function() return gconfig_get("titlebar_ptn"); end,
		hint = "%p (tag) %t (title.) %i (ident.)",
		validator = function(str)
			return string.len(str) > 0 and not string.find(str, "%%", 1, true);
		end,
		handler = function(ctx, val)
			gconfig_set("titlebar_ptn", val);
			for tiler in all_tilers_iter() do
				for i, v in ipairs(tiler.windows) do
					v:set_title();
				end
			end
		end
	},
	{
		name = "tb_hide",
		label = "Hide Titlebar",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return
			gconfig_get("hide_titlebar") and LBL_YES or LBL_NO end,
		handler = function(ctx, val)
			gconfig_set("hide_titlebar", val == LBL_YES);
		end
	},
	{
		name = "sbar_pos",
		label = "Statusbar Position",
		kind = "value",
		set = {"top", "bottom"},
		initial = function()
			return gconfig_get("sbar_pos");
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_pos", val);
			active_display():tile_update();
		end
	},
	{
		name = "sbar_hud",
		label = "Stautsbar HUD mode",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return gconfig_get("sbar_hud") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_hud", val == LBL_YES);
			active_display():tile_update();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	}
};

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

local function run_group(group, ch, wnd)
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
			if (type(v) == "string" and string.sub(v, 1, 1) == ch) then
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
	run_group(group, "!", nil);
	if (set) then
-- need a copy to survive UAF- self modification
		local lst = {};
		for k,v in ipairs(set) do
			table.insert(lst, v);
		end
		for i,wnd in ipairs(lst) do
			if (wnd.canvas) then
				run_group(group, "#", wnd);
			end
			apply_scheme(pal, wnd);
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
					for wnd in all_windows() do
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

local durden_visual = {
-- thickness is dependent on area, make sure the labels and
-- constraints update dynamically
	{
		name = "font",
		label = "Font",
		kind = "action",
		submenu = true,
		handler = durden_font
	},
	{
		name = "bars",
		label = "Bars",
		kind = "action",
		submenu = true,
		handler = durden_bars
	},
	{
		name = "border_vsz",
		label = "Border Thickness",
		kind = "value",
		hint = function() return
			string.format("(0..%d)", gconfig_get("borderw")) end,
		validator = function(val)
			return gen_valid_num(0, gconfig_get("borderw"))(val);
		end,
		initial = function() return tostring(gconfig_get("bordert")); end,
		handler = function(ctx, val)
			local num = tonumber(val);
			gconfig_set("bordert", tonumber(val));
			active_display():rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "border_area",
		label = "Border Area",
		kind = "value",
		hint = "(0..20)",
		inital = function() return tostring(gconfig_get("borderw")); end,
		validator = gen_valid_num(0, 20),
		handler = function(ctx, val)
			gconfig_set("borderw", tonumber(val));
			active_display():rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "shaders",
		label = "Shaders",
		kind = "action",
		submenu = true,
		handler = system_load("menus/global/shaders.lua")();
	},
	{
		name = "mouse_scale",
		label = "Mouse Scale",
		kind = "value",
		hint = "(0.1 .. 10.0)",
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
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_out")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_out", val);
		end
	},
};

local float_menu = {
	{
		name = "tbaroverride",
		label = "Force-Titlebar",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return
			gconfig_get("float_tbar_override") and LBL_YES or LBL_NO end,
		handler = function(ctx, val)
			gconfig_set("float_tbar_override", val == LBL_YES);
		end
	}
};

local durden_workspace = {
	{
		name = "autodel",
		label = "Autodelete",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return
			gconfig_get("ws_autodestroy") and LBL_YES or LBL_NO end,
		handler = function(ctx, val)
			gconfig_set("ws_autodestroy", val == LBL_YES);
		end
	},
	{
		name = "defmode",
		label = "Default Mode",
		kind = "value",
		set = {"tile", "tab", "vtab", "float"},
		initial = function() return tostring(gconfig_get("ws_default")); end,
		handler = function(ctx, val)
			gconfig_set("ws_default", val);
		end
	},
	{
		name = "float",
		label = "Float",
		submenu = true,
		kind = "action",
		handler = float_menu
	},
	{
		name = "adopt",
		label = "Autoadopt",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		eval = function() return gconfig_get("display_simple")
			and LBL_YES or LBL_NO; end,
		initial = function() return tostring(gconfig_get("ws_autoadopt")); end,
		handler = function(ctx, val)
			gconfig_set("ws_autoadopt", val == LBL_YES);
		end
	}
};

local rate_menu = {
	{
		name = "rlimit",
		label = "Rate Limit",
		initial = function() return gconfig_get("extcon_rlimit"); end,
		kind = "value",
		hint = "(0: disabled .. 1000)",
		validator = gen_valid_num(0, 1000),
		handler = function(ctx, val)
			gconfig_set("extcon_rlimit", tonumber(val));
		end
	},
	{
		name = "startdelay",
		label = "Grace Period",
		kind = "value",
		hint = "(0: disabled .. 1000)",
		initial = function() return gconfig_get("extcon_startdelay"); end,
		validator = gen_valid_num(0, 1000),
		handler = function(ctx, val)
			gconfig_set("extcon_startdelay", tonumber(val));
		end
	},
	{
		name = "extwndlim",
		label = "External Windows Limit",
		kind = "value",
		initial = function() return gconfig_get("extcon_wndlimit"); end,
		validator = gen_valid_num(0, 1000),
		hint = "(0: disabled .. 1000)",
		handler = function(ctx, val)
			gconfig_set("extcon_wndlimit", tonumber(val));
		end
	},
	{
		name = "subseglimit",
		label = "Window Subsegment Limit",
		kind = "value",
    hint = "(0: disabled, .. 100)",
		initial = function() return gconfig_get("subwnd_limit"); end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			gconfig_set("subwnd_limit", tonumber(val));
		end
	}
};

local durden_system = {
	{
		name = "cpath",
		label = "Connection Path",
		kind = "value",
		hint = "(a..Z_)",
		validator = strict_fname_valid,
		initial = function() local path = gconfig_get("extcon_path");
			return path == ":disabled" and "[disabled]" or path;
		end,
		handler = function(ctx, val)
			gconfig_set("extcon_path", val, true);
			if (valid_vid(INCOMING_ENDPOINT)) then
				delete_image(INCOMING_ENDPOINT);
				INCOMING_ENDPOINT = nil;
			end
			if (string.len(val) == 0) then
				val = ":disabled";
			else
				durden_new_connection(BADID, {key = val});
			end
		end
	},
	{
		name = "rate_limit",
		label = "Rate Limiting",
		kind = "action",
		submenu = true,
		handler = rate_menu
	},
	{
		name = "ctrlpipe",
		label = "Control Pipe",
		kind = "value",
		hint = "(a..Z_)",
		validator = strict_fname_valid,
		initial = function() local path = gconfig_get("control_path");
			return path == ":disabled" and "[disabled]" or pth;
		end,
		handler = function(ctx, val)
			if (CONTROL_CHANNEL) then
				CONTROL_CHANNEL:close();
				zap_resource(gconfig_get("control_path"));
				CONTROL_CHANNEL = nil;
			end

			if (string.len(val) == 0) then
				val = ":disabled";
			else
				COMMAND_CHANNEL = open_nonblock("<ipc/" .. val);
			end
			gconfig_set("control_path", val, true);
		end
	},
	{
		name = "ctrlwhitelist",
		label = "Whitelist",
		kind = "value",
		initial = function() return
			gconfig_get("whitelist") and LBL_YES or LBL_NO;
		end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("whitelist", val == LBL_YES);
		end
	},
	{
		name = "bridgegamma",
		label = "Gamma Bridge",
		kind = "value",
		initial = function() return gconfig_get("gamma_access"); end,
		set = {"none", "full"},
		handler = function(ctx, val)
			gconfig_set("gamma_access", val);
		end
	},
	{
		name = "gpuauth",
		label = "GPU delegation",
		kind = "value",
		initial = function() return gconfig_get("gpu_auth"); end,
		eval = function() return TARGET_ALLOWGPU ~= nil; end,
		set = {"none", "full"},
		handler = function(ctx, val)
			gconfig_set("gpu_auth", val);
		end
	},
	{
		name = "bridgeclip",
		label = "Clipboard Bridge",
		kind = "value",
		initial = function() return gconfig_get("clipboard_access"); end,
		set = {"none", "full", "passive", "active"},
		handler = function(ctx, val)
			gconfig_set("clipboard_access", val);
		end
	},
	{
		name = "statpipe",
		label = "Status Pipe",
		kind = "value",
		hint = "(a..Z_)",
		validator = strict_fname_valid,
		initial = function() local path = gconfig_get("status_path");
			return path == ":disabled" and "[disabled]" or path;
		end,
		handler = function(ctx, val)
			if (STATUS_CHANNEL) then
				STATUS_CHANNEL:close();
				zap_resource(gconfig_get("status_path"));
				STATUS_CHANNEL = nil;
			end

			if (string.len(val) == 0) then
				val = ":disabled";
			else
				STATUS_CHANNEL = open_nonblock("<ipc/" .. val);
			end

			gconfig_set("status_path", val);
		end
	},
	{
		name = "outpipe",
		label = "Output Pipe",
		kind = "value",
		hint = "(a..Z_)",
		validator = strict_fname_valid,
		initial = function() local path = gconfig_get("output_path");
				return path == ":disabled" and "[disabled]" or path;
		end,
		handler = function(ctx, val)
			if (OUTPUT_CHANNEL) then
				OUTPUT_CHANNEL:close();
				zap_resource(gconfig_get("output_path"));
				OUTPUT_CHANNEL = nil;
			end

			if (string.len(val) == 0) then
				val = ":disabled";
			else
				OUTPUT_CJANNEL = open_nonblock("<ipc/" .. val, true);
			end

			gconfig_set("output_path", val);
		end
	},
	{
		name = "dispmode",
		label = "Display Mode",
		kind = "value",
		set = {"Simple", "Normal"},
		initial = function() return gconfig_get("display_simple") and
			"Simple" or "Normal"; end,
		handler = function(ctx, val)
			gconfig_set("display_simple", val == "Simple");
			active_display():message("Switching Displaymode, Reset Required.");
		end
	}
};

local recmenu = {
	{
	name = "fps",
	label = "Framerate",
	kind = "value",
	hint = "(10..60)",
	validator = gen_valid_num(10, 60),
	initial = function() return tostring(gconfig_get("enc_fps")); end,
	handler = function(ctx, val)
		gconfig_set("enc_fps", tonumber(val));
	end
	},
	{
	name = "preset",
	label = "Video Quality Preset",
	kind = "value",
	hint = "(0:disable..10:max, overrides bitrate)",
	validator = gen_valid_num(0, 10),
	initial = function() return tostring(gconfig_get("enc_vpreset")); end,
	handler = function(ctx, val)
		gconfig_set("enc_vpreset", tonumber(val));
		gconfig_set("enc_vbr", tonumber(val) == 0 and 800 or 0);
	end
	},
	{
	name = "vbr",
	label = "Video Bitrate",
	kind = "value",
	hint = "(kbit/s, overrides preset)",
	validator = gen_valid_num(100, 10000),
	initial = function() return tostring(gconfig_get("enc_vbr")); end,
	handler = function(ctx, val)
		gconfig_set("enc_vpreset", 0);
		gconfig_set("enc_vbr", tonumber(val));
	end
	},
	{
	name = "presilence",
	label = "Audio Presilence",
	kind = "value",
	hint = "(samples)",
	validator = gen_valid_num(0, 16384),
	initial = function() return tostring(gconfig_get("enc_presilence")); end,
	handler = function(ctx, val) gconfig_set("enc_presilence", tonumber(val)); end
	}
};

local config_terminal_font = {
	{
		name = "font_sz",
		label = "Size",
		kind = "value",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("term_font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("term_font_sz", tonumber(val));
		end
	},
	{
		name = "font_hint",
		label = "Hinting",
		kind = "value",
		eval = function() return gconfig_get("term_bitmap") ~= true; end,
		set = {"none", "mono", "light", "normal", "subpixel"},
		initial = function() return TERM_HINT_RLUT[
		gconfig_get("term_font_hint")]; end,
		handler = function(ctx, val)
			gconfig_set("term_font_hint", hint_lut[val]);
		end
	},
	{
		name = "force_bitmap",
		label = "Force Bitmap",
		kind = "value",
		hint = "(new terminals only)",
		initial = function() return gconfig_get("term_bitmap") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("term_bitmap", val == LBL_YES);
		end
	},
-- should replace with some "font browser" but we don't have asynch font
-- loading etc. and no control over cache size
	{
		name = "font_name",
		label = "Name",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			table.insert(set, "BUILTIN");
			return set;
		end,
		initial = function() return gconfig_get("term_font"); end,
		handler = function(ctx, val)
			gconfig_set("term_font", val == "BUILTIN" and "" or val);
		end
	}
};

local config_terminal = {
	{
		name = "alpha",
		label = "Background Alpha",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_float(0, 1),
		initial = function() return tostring(gconfig_get("term_opa")); end,
		handler = function(ctx, val)
			gconfig_set("term_opa", tonumber(val));
		end
	},
	{
		name = "palette",
		label = "Palette",
		kind = "value",
		set = {"default", "solarized", "solarized-black", "solarized-white"},
		initial = function() return gconfig_get("term_palette"); end,
		handler = function(ctx, val)
			gconfig_set("term_palette", val);
		end
	},
	{
		name = "font",
		label = "Font",
		kind = "action",
		submenu = true,
		handler = config_terminal_font
	}
};

local allmenu = {
	{
		name = "all_susp",
		label = "Suspend All",
		kind = "action",
		handler = grab_global_function("all_suspend")
	},
	{
		name = "all_media_susp",
		label = "Suspend Media",
		kind = "action",
		handler = grab_global_function("all_media_suspend")
	},
	{
		name = "all_susp",
		label = "Resume All",
		kind = "action",
		handler = grab_global_function("all_resume")
	},
	{
		name = "all_media_resume",
		label = "Resume Media",
		kind = "action",
		handler = grab_global_function("all_media_resume")
	},
};

return {
	{
		name = "visual",
		label = "Visual",
		kind = "action",
		submenu = true,
		handler = durden_visual
	},
	{
		name = "wspaces",
		label = "Workspaces",
		kind = "action",
		submenu = true,
		handler = durden_workspace
	},
	{
		name = "timers",
		label = "Timers",
		kind = "action",
		submenu = true,
		handler = system_load("menus/global/timer.lua")()
	},
	{
		name = "led",
		label = "LEDs",
		kind = "action",
		submenu = true,
		eval = function()
			return #ledm_devices("passive") > 0;
		end,
		handler = system_load("menus/global/led.lua")()
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		handler = durden_system
	},
	{
		name = "recording",
		label = "Recording",
		kind = "action",
		submenu = true,
		handler = recmenu
	},
	{
		name = "allwnd",
		label = "All-Windows",
		kind = "action",
		submenu = true,
		handler = allmenu,
	},
	{
		name = "terminal",
		label = "Terminal",
		kind = "action",
		submenu = true,
		eval = function()
			return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
		end,
		handler = config_terminal
	},
	{
		name = "scheme",
		label = "Scheme",
		kind = "action",
		submenu = true,
		eval = function()	return #(ui_scheme_menu()) > 0; end,
		handler = function() return ui_scheme_menu("global"); end
	},
	{
		name = "tools",
		label = "Tools",
		kind = "action",
		submenu = true,
		handler = tools_conf
	}
};
