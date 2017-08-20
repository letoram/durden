UI Schemes
============

These are presets of menu-paths that can be activated as part of some trigger,
such as a workspace switch or macro keybinding. Although they can be set to
activate any set of paths in sequence (security and stability risk, you are at
your own risk here), intent is that it is used for the config/visual- paths
though it is not enforced via some filter.

Be particularly careful with target prefix actions (#) that would cause some
destructive change, e.g. window deletion. The same goes for global action that
would change the setup being operated on, like reassignment etc. Doing

For normal 'my' startup actions, still use the autorun.lua mechanism.

Schemes in this folder are scanned at startup/reset time and can be found in
global/config/schemes/name, . it is expected to return a table with the following
format:

return {
	name = "scheme_name",

-- will be communicated to windows that support color-scheme
-- definitions (external) and for the scope it is activated
	palette = {
		primary = {0, 255, 0},
		secondary = {0, 127, 0},
		background = {0, 0, 0},
		label = {0, 255, 0},
		warning = {127, 0, 0},
		error = {255, 0, 0},
		alert = {255, 255, 0},
		inactive = {0, 127, 0},
	},

-- will be ran no matter what context the profile is activated in,
-- target actions (# prefix) apply to the currently selected window
	actions = {
		"!action/one",
		"!action/two"
	},

-- will be run if the profile is set globally (global/config/scheme)

-- will be ran if the profile is set on a display. Target actions
-- will be applied to all windows in all workspaces on the display.
	display = {
	};

-- will be ran if the profile is set on a workspace. Target actions
-- (#prefix) will be applied to all windows in the workspace by
-- a silent select action.
	workspace = {
		"!action/one",
		"!action/two"
	},

-- will be run if the profile is set on a window.
	window = {
	},
};

See the default.lua for an example file that can be used to build on. The
scheme- profiles are combined with the 'flair' tool for controlling visual
effects, and the "on start" ui profile that defines configuration scheme
on a higher level.
