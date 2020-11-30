-- This is a quick-hack draft of the real 'initial config' tool that will come
-- eventually. At the moment it is simply a series of modal popups that lets
-- you pick UI scheme and default bindings, security level and possibly rebind
-- keys. On-Load it also drops the default keybindings.

-- list of schemes to run on load, initially empty and wiped on activation
local deploy_schemes = {};

local function list_wm_schemes()
	local schemes = ui_scheme_menu();
	return schemes;
end

-- should really be a grid of preview shots
local function list_color_schemes()
	local schemes = ui_scheme_menu();
	return schemes;
end

local policies = {
	client = {
		"/global/settings/system/cpath=durden",
	},
	display = {
		"/global/settings/system/source_color=all",
	},
	tray = {
		"/global/settings/statusbar/buttons/right/add_external=tray"
	},
	ipc = {
		"/global/settings/system/control=control"
	},
	gpu = {
		"/global/settings/system/gpuauth=none"
	},
	clipboard = {
		"/global/settings/system/bridgeclip=full",
	},
	norate = {
		"/global/settings/system/rate_limit/rlimit=0",
		"/global/settings/system/rate_limit/start_delay=0",
		"/global/settings/system/rate_limit/extwndlim=0",
		"/global/settings/system/rate_limit/subseglimit=0",
	},
	slowrate = {
		"/global/settings/system/rate_limit/rlimit=1",
		"/global/settings/system/rate_limit/start_delay=100",
		"/global/settings/system/rate_limit/extwndlim=70",
		"/global/settings/system/rate_limit/subseglimit=40",
	},
	paranoid = {
		"/global/settings/system/bridgeclip=none",
		"/global/settings/system/control=:disabled",
		"/global/settings/system/bridgeclip=none",
		"/global/settings/system/gpuauth=none",
		"/global/settings/system/cpath=:disabled",
		"/global/settings/system/rate_limit/rlimit=3",
		"/global/settings/system/rate_limit/start_delay=500",
		"/global/settings/system/rate_limit/extwndlim=20",
		"/global/settings/system/rate_limit/subseglimit=10",
	}
};

-- could be defined as schemas in themselves, but swapping policies runtime
-- likely won't provide any real form of protection so keep it here for now
local function security_level()
	local run =
	function(tbl)
		for _,v in ipairs(tbl) do
			for _,p in ipairs(policies[v]) do
					dispatch_symbol(p);
			end
		end
	end

	return
	{
		{
			name = "dontcare",
			label = "Don't Care",
			description = "All features (IPC, Display, Clipboard, Clients, Direct GPU)",
			kind = "action",
			handler = function()
				run({"paranoid", "client", "tray", "ipc", "display", "clipboard", "gpu", "norate"});
		end
		},
		{
			name = "basic",
			label = "Careful",
			description = "Block Control IPC, soft Rate-limit",
			kind = "action",
			handler = function()
				run({"paranoid", "client", "tray", "norate", "gpu", "slowrate"});
			end
		},
		{
			name = "careful",
			label = "Careful",
			description = "Blocks Control IPC, Direct GPU access",
			kind = function()
				run({"paranoid", "client", "slowrate", "tray"});
			end,
		},
		{
			name = "security_paranoid",
			label = "Paranoid",
			description = "No IPC, No External Clients, No Subprotocols, Rate-Limiting, Block GPU access",
			kind = "action",
			handler = function()
				run({"paranoid"});
			end
		}
	};
end

local function meta_bind()
	return {
		{
			kind = "action",
			name = "meta_1",
			label = "Meta 1",
			description = "Key used for main UI actions",
			submenu = true,
			handler = function()
-- bind then continue with our popup-chain
				return meta_bind()
			end
		},
		{
			kind = "action",
			name = "meta_2",
			label = "Meta 2",
			description = "Key to use for secondary meta action, double-tap to toggle locking",
			submenu = true,
			handler = function()
				return meta_bind()
			end
		},
		{
			kind = "action",
			name = "continue",
			label = "Continue",
			description = "Leave meta keys in their current state",
			handler = function()
			end
		}
	};
end

local function cleanup()
-- save the options for wm, color and security - apply on load
end

-- list schemes that has entries for bindings and/or on_install
-- list schemes that has entries for color
local function config()
	deploy_schemes = {};
	local stages =
	{
		list_wm_schemes,
		last_color_schemes,
		security_level,
		meta_bind,
		cleanup
	};

-- while we have entries in popup, run the modal selector
	local run_stage;
	run_stage = function()
		local stage = table.remove(stages, 1);
		if not stage then
			return;
		end

		local tbl = stage();
		if tbl and #tbl > 0 then
			uimap_popup(tbl,
				math.floor(active_display().width * 0.5),
				math.floor(active_display().height * 0.5),
				active_display().order_anchor,
				run_stage,
				{
					block_cancel = true
				}
			);
		end
	end

	run_stage();
end

-- disable for now, some more testing needed here
-- menus_register("global", "settings/tools",
-- {
--	name = "profile_picker",
--	label = "Profile Picker",
--	kind = "action",
--	description = "Reconfigure system basics, e.g. startup schemes and keys",
--	handler = config
-- });
