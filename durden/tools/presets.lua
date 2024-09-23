--
-- each query_...(state) is supposed to return a menu or [nil] when the
-- stage is over. The tool simply sweeps through these stages and picks
-- something.
--
local	log, fmt = suppl_add_logfn("tools")

local function build_state_stepper(state, key, path)
	local menu = table.copy(menu_resolve(path))
	local oh = menu.handler

	menu.handler =
	function(ctx, val)
		oh(ctx, val)
		state[key] = state[key] + 1
	end

	return menu
end

local function query_a11y(state)
	local a11y_menus = {}
	local aud_profile = "/global/tools/tts/open=basic_eng"

	table.insert(
		a11y_menus,
		{
			name = "a11y",
			label = "Accessibility",
			hint = "(Accessibility)",
			kind = "value",
			set = {LBL_YES, LBL_NO},
			handler = function(ctx, val)
				state.in_a11y = state.in_a11y + 1
				if val == LBL_NO then
					dispatch_symbol(
						"/global/tools/tts/voices/basic_eng/destroy=yes")
					state.in_a11y = #a11y_menus + 1
				else
					dispatch_bindtarget(aud_profile)
					dispatch_symbol(
						"/global/settings/tools/autostart/add")
				end
-- query voices for [set] and insert into set
			end,
		}
	)

	table.insert(
		a11y_menus,
		{
			name = "vision",
			label = "Vision",
			hint = "(Vision):",
			kind = "value",
			set = {"No Vision", "Low Vision"}, -- colour-blindness options
			handler = function(ctx, val)
				state.no_vision = val == "No Vision"
				state.low_vision = val == "Low Vision"
				state.in_a11y = state.in_a11y + 1

-- switch to low-vision friendly font (hyperlegible)
-- add mouse binding to zoom and pan and step
-- set larger font size (18 or 22)
-- increase cursor scale (200%)
				if state.low_vision then

				end

-- queue input request about mouse cursor feedback
-- queue messages about keybindings
			end
		}
	)

-- extra a11y stages if TTS is desired
-- (add voice profile until done, tool need to expose an accessor)

	if not state.in_a11y then
-- force-start tts
		dispatch_symbol(aud_profile)
		state.in_a11y = 1
	end

	return a11y_menus[state.in_a11y]
end

local function query_input(state)
	if not state.in_input then
		state.in_input = 1
	end

	local input_menus = {
-- meta bindings
-- key repeat
-- focus behavior
-- mouse acceleration
-- touch input
	}

	return input_menus[state.in_input]
end

local function query_visual(state)
	if not state.in_visual then
		state.in_visual = 1
	end

-- quick- pick presets
-- [ flashy ] [ balanced ] [ minimal ] [ custom ]
	local state_menus = {}
	local paths = {
		"/global/settings/visual/font/size",
		"/global/settings/visual/colors/hc_palette/schemes",
		"/global/settings/terminal/colorscheme",
		"/global/settings/terminal/alpha",
		"/global/settings/terminal/font/font_sz",
	}

	for i,v in ipairs(paths) do
		table.insert(state_menus,
			build_state_stepper(state, "in_visual", v))
	end

-- padding, opacity
-- decorations (border / shadow)
-- animation speeds
-- autohide statusbar
-- colour or imagea
-- flair (blurred HUD)

	return state_menus[state.in_visual]
end

local function query_wm(state)
	if not state.in_wm then
		state.in_wm = 1
	end

	local wm_menus =
	{
-- tiling or floating
--   -> i3 (affect default bindings), scrolling, bsp, tabbed
-- tiling: custom
-- floating: mouse_regions, desktop icons
-- focus behaviour
	}

	return wm_menus[state.in_wm]
end

local function query_security(state)
	if not state.in_security then
		state.in_security = 1
	end

	local security_menus =
	{
-- paranoid
--  (no control socket, no external connection point, colored windows)
-- careful
--  (no control socket, rate limited external connections,
-- dontcare
-- custom (add each thing as a separate option)
	}

	return security_menus[state.in_security]
end

local function query_shell(state)

end

local function query_presets()
	drop_keys("autostart_%");

	local stages =
	{
		query_a11y,
		query_wm,
		query_visual,
		query_input,
		query_security,
		query_shell
	}

-- make a copy of the current config in order to cancel / revert,
-- as well as the current autorun settings,
-- keybindings and status/menu buttons

	local state = {}
	local step

-- we just recurse-step this as even though we don't get tail-call
-- the lua-lua stack is 32k entries or so.
	step =
	function()
		if #stages == 0 then
			return
		end

		local menu = stages[1](state)
		if not menu then
			table.remove(stages, 1)
			return step()
		end

		local value = menu.kind and menu.kind == "value"
		if value then
			local ch = menu.handler
			local val = menu.validator
			menu.handler =
			function(ctx, val)
				ch(ctx, val)
				return step()
			end

-- grab the on_accept handler
			local ictx = menu_query_value(menu, false, true, {block_cancel = true})
			local initial = menu.initial
			if initial and not menu.set then
				if type(initial) == "function" then
					initial = initial()
				end
				ictx.inp:set_str(tostring(initial))
			end

		else
			menu_launch(
				active_display(),
				{
					list = menu
				},
				{
					block_cancel = true,
					force_completion = true
				},
				""
			)
		end
	end

	step()
end

menus_register("global", "settings/tools", {
	name = "presets",
	label = "Presets",
	description = "Query settings presets",
	kind = "action",
	handler = query_presets
}
)
