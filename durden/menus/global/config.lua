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
		initial = function() return TERM_HINT_RLUT[gconfig_get("font_hint")]; end,
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

local config_browser = {
	{
		name = "preview_mode",
		label = "Preview",
		description = "Control what type of resources will be previewed",
		kind = "value",
		initial = function(ctx, val) return gconfig_get("browser_preview"); end,
		set = {"none", "image", "full"},
		handler = function(ctx, val)
			gconfig_set("browser_preview", val);
		end
	},
	{
		name = "preview_delay",
		label = "Timer",
		description = "The amount of 'hover' ticks before preview is activated",
		kind = "value",
		hint = "1..100",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("browser_timer")); end,
		handler = function(ctx, val)
			gconfig_set("browser_timer", tonumber(val));
		end
	},
	{
		name = "preview_position",
		label = "Position",
		kind = "value",
		hint = "(0..100)",
		description = "Relative preview starting position for media clips (%)",
		validator = gen_valid_num(0, 100),
		initial = function() return tostring(gconfig_get("browser_position")); end,
		handler = function(ctx, val)
			gconfig_set("browser_position", tonumber(val));
		end
	},
	{
		name = "preview_trigger",
		label = "Trigger",
		description = "The event that should trigger the preview to activate",
		kind = "value",
		set = {"selection", "visibility"},
		initial = function() return gconfig_get("browser_trigger"); end,
		handler = function(ctx, val)
			gconfig_set("browser_trigger", val);
		end
	}
};

local durden_visual = {
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
		name = "menu_helper",
		label = "Menu Descriptions",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("menu_helper") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("menu_helper")
	}
};

local durden_workspace = {
	{
		name = "autodel",
		label = "Autodelete",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		description = "Automatically destroy workspaces that do not have any windows",
		initial = function() return
			gconfig_get("ws_autodestroy") and LBL_YES or LBL_NO end,
		handler = suppl_flip_handler("ws_autodestroy")
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
		name = "adopt",
		label = "Autoadopt",
		kind = "value",
		description = "Let displays adopt orphaned workspaces automatically",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function()
			return gconfig_get("display_simple") and LBL_YES or LBL_NO;
		end,
		initial = function() return tostring(gconfig_get("ws_autoadopt")); end,
		handler = suppl_flip_handler("ws_autoadopt")
	}
};

local rate_menu = {
	{
		name = "rlimit",
		label = "Rate Limit",
		initial = function() return gconfig_get("extcon_rlimit"); end,
		kind = "value",
		hint = "(0: disabled .. 1000)",
		description = "Limit the number of external connections allowed per second",
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
		description = "Defer external connections until an initial grace period has elapsed",
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
		description = "Limit the number of windows with an external connection source",
		handler = function(ctx, val)
			gconfig_set("extcon_wndlimit", tonumber(val));
		end
	},
	{
		name = "subseglimit",
		label = "Window Subsegment Limit",
		kind = "value",
    hint = "(0: disabled, .. 100)",
		description = "Limit the number of subsegments a client may have active",
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
		description = "Change the name of the socket used to connect external clients",
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
		description = "Settings for rate limiting external resource allocations",
		handler = rate_menu
	},
	{
		name = "control",
		label = "Control",
		kind = "value",
		hint = "(a..Z_)",
		validator = strict_fname_valid,
		description = "Set the control socket name (ipc/XXX) for external UI control",
		initial = function() local path = gconfig_get("control_path");
			return path == ":disabled" and "[disabled]" or path;
		end,
		handler = function(ctx, val)
			if (string.len(val) == 0) then
				val = ":disabled";
			end
			gconfig_set("control_path", val, true);
		end
	},
	{
		name = "source_color",
		label = "Color/Gamma Sync",
		kind = "value",
		description = "Control permissions for external color managers",
		initial = function() return gconfig_get("gamma_access"); end,
		set = {"none", "trusted", "all"},
		handler = function(ctx, val)
			gconfig_set("gamma_access", val);
		end
	},
	{
		name = "gpuauth",
		label = "GPU delegation",
		kind = "value",
		description = "Control permission for external privileged GPU access",
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
		description = "Control permissions for external clipboard managers",
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
		description = "Set the fifo-name (ipc/XXX) used for statusbar control",
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
		description = "Set the fifo-name (ipc/XXX) used for IPC output feedback",
		handler = function(ctx, val)
			if (OUTPUT_CHANNEL) then
				OUTPUT_CHANNEL:close();
				zap_resource(gconfig_get("output_path"));
				OUTPUT_CHANNEL = nil;
			end

			if (string.len(val) == 0) then
				val = ":disabled";
			else
				OUTPUT_CHANNEL = open_nonblock("<ipc/" .. val, true);
			end

			gconfig_set("output_path", val);
		end
	},
	{
		name = "dispmode",
		label = "Display Mode",
		kind = "value",
		set = {"Simple", "Normal"},
		description = "(advanced/reset) Change display management mode",
		initial = function() return gconfig_get("display_simple") and
			"Simple" or "Normal"; end,
		handler = function(ctx, val)
			gconfig_set("display_simple", val == "Simple");
			active_display():message("Switching Displaymode, Reset Required.");
		end
	},
	{
		name = "debuglevel",
		label = "Debug Level",
		kind = "value",
		validator = gen_valid_num(0, 5),
		initial = function() return tostring(DEBUGLEVEL); end,
		hint = "(0=off, 5=max)",
		description = "(advanced/debug) Change the global debuglevel",
		handler = function(ctx, val)
			DEBUGLEVEL = tonumber(val);
		end
	}
};

local recmenu = {
	{
	name = "fps",
	label = "Framerate",
	kind = "value",
	hint = "(10..60)",
	description = "Change the nominal video encoding samplerate",
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
	description = "Change the targeted video quality approximation level",
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
	description = "Change the ideal video bitrate",
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
	description = "Prefill audio buffers with n samples of silence",
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
		description = "Change the default UI font pt size",
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
		description = "Change anti-aliasing hinting algorithm",
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
		description = "Force the use of a built-in bitmap only font",
		hint = "(new terminals only)",
		initial = function() return gconfig_get("term_bitmap") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		handler = suppl_flip_handler("term_bitmap")
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
		description = "Change the default terminal font",
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
		description = "Change the background opacity for all terminals",
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
		description = "Change palette used by terminal at startup",
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
		description = "Switch font-set used by all terminals",
		handler = config_terminal_font
	}
};

return {
	{
		name = "visual",
		label = "Visual",
		kind = "action",
		submenu = true,
		description = "UI elements, colors and effects",
		handler = durden_visual
	},
	{
		name = "wspaces",
		label = "Workspaces",
		kind = "action",
		submenu = true,
		description = "Workspace layout mode settings",
		handler = durden_workspace
	},
	{
		name = "timers",
		label = "Timers",
		kind = "action",
		submenu = true,
		description = "View / Manage active timers",
		handler = system_load("menus/global/timer.lua")()
	},
	{
		name = "notification",
		label = "Notification",
		kind = "action",
		submenu = true,
		description = "Control Notification Behavior",
		handler = system_load("menus/global/notification.lua")()
	},
	{
		name = "led",
		label = "LEDs",
		kind = "action",
		submenu = true,
		description = "LED device controls",
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
		description = "System and Security specific controls",
		handler = durden_system
	},
	{
		name = "recording",
		label = "Recording",
		kind = "action",
		description = "Media recording parameters (framerate, bitrate, ...)",
		submenu = true,
		handler = recmenu
	},
	{
		name = "terminal",
		label = "Terminal",
		kind = "action",
		submenu = true,
		description = "Command-Line Interface (CLI) options",
		eval = function()
			return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
		end,
		handler = config_terminal
	},
	{
		name = "browser",
		label = "Browser",
		kind = "action",
		submenu = true,
		description = "Resource browser options",
		handler = config_browser
	},
	{
		name = "scheme",
		label = "Scheme",
		kind = "action",
		submenu = true,
		description = "Select a color/UI scheme",
		eval = function()	return #(ui_scheme_menu()) > 0; end,
		handler = function() return ui_scheme_menu("global"); end
	},
	{
		name = "tools",
		label = "Tools",
		kind = "action",
		description = "Custom tool specific settings",
		submenu = true,
		handler = tools_conf
	},
	{
		name = "statusbar",
		label = "Statusbar",
		kind = "action",
		submenu = true,
		description = "Change Task/Statusbar look and feel",
		handler = system_load("menus/global/statusbar.lua")(),
	},
	{
		name = "hud",
		label = "HUD",
		kind = "action",
		submenu = true,
		description = "Change HUD look and feel",
		handler = system_load("menus/global/hud.lua")(),
	},
	{
		name = "commit",
		label = "Commit",
		kind = "action",
		description = "Store all pending configuration changes",
		handler = function()
			SYMTABLE:store_translation();
			gconfig_shutdown();
		end
	}
};
