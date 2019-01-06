-- populated on tool loading
local tools_conf = {
};

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
				durden_eval_respawn(true);
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

return {
	{
		name = "visual",
		label = "Visual",
		kind = "action",
		submenu = true,
		description = "UI elements, colors and effects",
		handler = system_load("menus/global/visual.lua")()
	},
	{
		name = "wspaces",
		label = "Workspaces",
		kind = "action",
		submenu = true,
		description = "Workspace layout mode settings",
		handler = system_load("menus/global/workspaces.lua")()
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
		name = "notifications",
		label = "Notifications",
		kind = "action",
		submenu = true,
		description = "Controls for the notification subsytem",
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
		handler = system_load("menus/global/terminal.lua")()
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
		name = "titlebar",
		label = "Titlebar",
		kind = "action",
		submenu = true,
		description = "Change Window titlebar defaults",
		handler = system_load("menus/global/titlebar.lua")()
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
