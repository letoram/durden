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
	local aud_profile = "/global/tools/tts/open=basic_eng"
	local curs_profile = "/global/tools/tts/open=cursor_eng"

	if state.a11y_menus then
		return state.a11y_menus[state.in_a11y]
	end

-- force-start tts
	dispatch_symbol(aud_profile)
	state.in_a11y = 1

	state.a11y_menus = {}
	table.insert(
		state.a11y_menus,
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
					state.in_a11y = #state.a11y_menus + 1
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
		state.a11y_menus,
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
				if state.low_vision then
					dispatch_symbol("/global/settings/visual/font/name=hyperlegible.otf")

-- add mouse binding to zoom and pan and step

-- set larger font size (22) then query later
					dispatch_symbol("/global/settings/visual/font/size=22")

-- increase cursor scale (200%)
					if state.low_vision then
						dispatch_symbol("/global/settings/visual/mouse_scale=2")
					end
				end

-- queue input request about mouse cursor feedback
				if state.no_vision or state.low_vision then
					table.insert(state.a11y_menus,
					{
						name = "cursor",
						label = "Mouse Cursor",
						description = "Use sounds to annotate mouse cursors?",
						kind = "value",
						set = {LBL_YES, LBL_NO},
						handler =
						function(ctx, val)
							if val == LBL_YES then
								dispatch_symbol(curs_profile)
								dispatch_bindtarget(curs_profile)
								dispatch_symbol("/global/settings/tools/autostart/add")
							end
							state.in_a11y = state.in_a11y + 1
						end
					}
				)

-- should have an extended profile here that swaps out basic for minimal, then
-- have another extended for notification/alerts etc. that uses a different
-- synthesis engine
				end

-- queue messages about keybindings
			end
		}
	)

	return state.a11y_menus[state.in_a11y]
end

local function query_input(state)
	if state.input_menus then
		return state.input_menus[state.in_input]
	end

	state.input_menus = {
-- meta bindings
-- key repeat
-- focus behavior
-- mouse acceleration
-- touch input
	}

	state.in_input = 1
	return state.input_menus[state.in_input]
end

local function query_visual(state)
-- quick- pick presets
-- [ flashy ] [ balanced ] [ minimal ] [ custom ]
	if state.visual_menus then
		return state.visual_menus[state.in_visual]
	end

	state.visual_menus = {
		{
			name = "preset",
			kind = "value",
			label = "Preset",
			description = "Pick a preset animation/effects scheme",
			set = {"Balanced", "Minimal", "Excessive", "Custom"},
			handler = function(ctx, val)
				state.in_visual = state.in_visual + 1
				if val == "Custom" then
					local paths = {}
-- padding / opacity
-- decorations (border / shadow)
-- animation speeds
-- autohide statusbar
-- colour or image
-- flair
-- padding, opacity
-- decorations (border / shadow)
-- animation speeds
-- autohide statusbar
-- colour or image
-- flair (blurred HUD)
-- [done]

					for i,v in ipairs(paths) do
						table.insert(state_menus,
							build_state_stepper(state, "in_visual", v))
					end
				end
			end
		}
	}

	local paths =
	{
		"/global/settings/visual/font/size",
		"/global/settings/visual/colors/hc_palette/schemes",
		"/global/settings/terminal/colorscheme",
		"/global/settings/terminal/alpha",
		"/global/settings/terminal/font/font_sz",
	}

-- for no vision we don't really have use for this
	if state.no_vision then
		state.in_visual = #paths + 1
	else
		state.in_visual = 1
	end

	return state.visual_menus[state.in_visual]
end

local function query_wm(state)
	if state.wm_menus then
		return state.wm_menus[state.in_wm]
	end

	local substates = {
		{
-- BSD, Toplevel Cap
		},
	}

	state.in_wm = 1
	state.wm_menus =
	{
		{
			name = "style",
			label = "Style",
			kind = "value",
			description = "Pick a default window management scheme",
			set = {
				"Tiling",
				"Tabbed",
				"Floating / Stacked",
			},
			handler =
			function(ctx, val)
				if val == "Tiling" then
					table.insert(state.wm_menus,
					{
						name = "kind",
						label = "Kind",
						kind = "value",
						description = "How do you want the tiling to behave?",
						set = {
							"manual",
							"BSP",
							"paper"
						},
						handler =
						function(ctx, val)
							if val == "manual" then
								dispatch_symbol("/global/settings/workspaces/defmode=tile")
							elseif val == "BSP" then
								dispatch_symbol("/global/settings/workspaces/defmode=tile_bsp")
							elseif val == "paper" then
								dispatch_symbol("/global/settings/workspaces/defmode=tile")
								dispatch_symbol("/global/settings/workspaces/breadth_cap=3")
							end
							state.in_wm = state.in_wm + 1
						end
					}
					)

				elseif val == "Tabbed" then
					dispatch_symbol("/global/settings/workspaces/defmode=tab")
				elseif val == "Floating / Stacked" then
					dispatch_symbol("/global/settings/workspaces/defmode=float")
					dispatch_symbol("/global/workspace/layout/float")
					state.got_float = true -- input menus for draw2spawn/cursreg
	-- other special bits, desktop icons
				end
				state.in_wm = state.in_wm + 1
			end
		},
	}

	return state.wm_menus[state.in_wm]
end

local function query_security(state)
	if state.in_security then
		return state.security_menus[state.in_security]
	end

	state.security_menus =
	{
-- paranoid
--  (no control socket, no external connection point, colored windows)
-- careful
--  (no control socket, rate limited external connections,
-- dontcare
-- custom (add each thing as a separate option)
	}
	state.in_security = 1

	return state.security_menus[state.in_security]
end

local function query_presets()
	drop_keys("autostart_%");

	local stages =
	{
		query_a11y,
		query_wm,
		query_input,
		query_visual,
		query_security,
--  query_device
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
			if state.no_vision or state.low_vision then
			end
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
