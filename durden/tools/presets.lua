--
-- each query_...(state) is supposed to return a menu or [nil] when the
-- stage is over. The tool simply sweeps through these stages and picks
-- something.
--
local	log, fmt = suppl_add_logfn("tools")

-- some options need to control when the next step comes
local locked = false

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
	local welcome = "Welcome to Durden Setup. Use arrow keys to step options, return/enter to confirm"

	if state.a11y_menus then
		return state.a11y_menus[state.in_a11y]
	end

-- force-start tts
	dispatch_symbol(aud_profile)
	dispatch_symbol("/global/tools/tts/voices/default/speak=" .. welcome)

	state.in_a11y = 1
	state.a11y_menus = {}
	table.insert(
		state.a11y_menus,
		{
			name = "a11y",
			label = "Accessibility",
			description = "Do you need assistance with vision?",
			kind = "value",
			set = {LBL_YES, LBL_NO},
			handler =
			function(ctx, val)
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
			end
-- query voices for [set] and insert into set
	})

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
			end
		}
	)

	return state.a11y_menus[state.in_a11y]
end

-- we mirror global/settings/input here in order to chain into the rest of
-- the menu as well as query for the a11y key
local function rebind_meta(state, stepfn)
	local bwt = gconfig_get("bind_waittime");
	locked = true
	local m1 = "Press/Release key for 'Meta 1' Several Times"
	local m2 = "Press/Release key for 'Meta 2' Several Times"
	local a1 = "Press/Release key for 'Screen Reader Controls' Several Times"

	dispatch_symbol("/global/tools/tts/voices/default/speak=" .. m1)

	local bb =
		tiler_bbar(active_display(), m1, true, 0, nil, nil,
			function(sym, done)
				if not done then
					dispatch_symbol("/global/tools/tts/voices/default/beep")
					return
				end

				dispatch_system("meta_1", sym)
				dispatch_symbol("/global/tools/tts/voices/default/speak=" .. m2)

				tiler_bbar(active_display(), m2, true, 0, nil, nil,
					function(sym2, done)
						if sym2 == sym then
							dispatch_symbol("/global/tools/tts/voices/default/beep")
							return "Already bound to 'Meta 1"
						end

						if not done then
							dispatch_symbol("/global/tools/tts/voices/default/beep")
							return
						end

						dispatch_system("meta_2", sym2)
						dispatch_symbol("/global/tools/tts/voices/default/speak=" .. a1)
						if state.no_vision or state.low_vision then
							tiler_bbar(active_display(), a1, true, 0, nil, nil,
								function(sym, done)
									if not done then
										dispatch_symbol("/global/tools/tts/voices/default/beep")
										return
									end

									dispatch_symbol("/global/tools/tts/voices/default/flush")
									dispatch_system("a11y", sym)
									locked = false
									stepfn()
								end, 5
							)
						else
							locked = false
							stepfn()
						end
					end, 5
				)
			end, 5
		)
end

local function query_input(state, stepfn)

	if state.input_menus then
		return state.input_menus[state.in_input]
	end

	state.input_menus = {}

	table.insert(state.input_menus,
-- other schemes (meta+key gesture, defaults from other WMs)
			{
				name = "meta_key",
				label = "Meta Keys (Durden)",
				description = "Select bindings and keyboard controls for desktop",
				kind = "value",
				set = {"Durden (M1+M2)", "Mouse Only"},
				handler = function(ctx, val)
					if val == "Durden (M1+M2)" then
						rebind_meta(state, stepfn)
					end

					state.in_input = state.in_input + 1
-- if in a11y, add query for a11y key
				end
		}
	)

	local rate =
	{
		Normal = {4, 600},
		Fast = {3, 400},
		Fastest = {2, 300},
		Slow = {6, 800}
	}

	table.insert(state.input_menus,
		{
			name = "repeat_rate",
			label = "Repeat Rate",
			description = "Choose how fast held keys should repeat",
			kind = "value",
			set = {"Normal", "Slow", "Fast", "Fastest"},
			kind = "value",
			handler = function(ctx, val)
				state.in_input = state.in_input + 1
				gconfig_set("kbd_period", rate[val][1])
				gconfig_set("kbd_delay", rate[val][2])
				iostatem_repeat(rate[val][1], rate[val][2])
			end
		}
	)

-- check platform and see if we can use a known set of xkb maps + variants

-- meta bindings
-- key repeat
-- focus behavior
-- mouse acceleration
-- touch input
-- keymap

	state.in_input = 1
	return state.input_menus[state.in_input]
end

local function query_visual(state)
-- quick- pick presets
-- [ flashy ] [ balanced ] [ minimal ] [ custom ]
	if state.visual_menus then
		return state.visual_menus[state.in_visual]
	end

-- balanced:
--  moderate speed
--  hud blur
--  transitions
--  small gaps
--

-- excessive:
--  flair on startup
--  slowish animations
--  on-select flair shake
--  hud blur
--  transitions
--  large gaps
--  statusbar gaps
--  terminal transparency
--  hide scalea
--  dissolve destroy
--  automatic preview everything
--

-- minimal:
--  no shadows
--  no decorations
--  no padding
--  no animations
--

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

local function query_device(state)
	if state.in_device then
		return state.device_menus[state.in_device]
	end

	state.device_menus = {}
	state.in_device = 1

	table.insert(state.device_menus,
		{
			name = "performance",
			label = "Performance",
			description = "Device performance tuning",
			kind = "value",
			set = {"Fast", "Safe"},
			handler = function()
				state.in_device = state.in_device + 1
-- enable direct composition on displays
			end
		}
	)

	table.insert(state.device_menus,
		{
			name = "blanking",
			label = "Blanking",
			description = "Disable screen on idle?",
			kind = "value",
			hint = "(seconds, 0=off)",
			validator = gen_valid_num(0, 1000),
			handler = function()
				state.in_device = state.in_device + 1
-- add startup for idle timer
-- add entry for lock timer
			end,
		}
	)

-- touch screen behavior and calibration
-- trackpad behavior and calibration
-- performance

return state.device_menus[state.in_device]
end

local function query_security(state)
	if state.in_security then
		return state.security_menus[state.in_security]
	end

	state.security_menus = {}

	local sets = {
-- no external connections (breaks recovery)
		Paranoid = {
			"/global/settings/system/cpath=:disabled",
			"/global/settings/system/control=:disabled",
			"/global/settings/system/x11/clipboard_synch=no",
			"/global/settings/system/bridgeclip=none",
			"/global/settings/system/gpuauth=none",
		},
-- allow external connections but limit them, no clipboard bridge, no x11 bridging,
-- popup on paste
		Careful = {
			"/global/settings/system/cpath=durden",
			"/global/settings/system/control=:disabled",
			"/global/settings/system/rate_limit/rlimit=100",
			"/global/settings/system/rate_limit/startdelay=200",
			"/global/settings/system/rate_limit/extwndlim=100",
			"/global/settings/system/rate_limit/subseglimit=20",
			"/global/settings/x11/clipboard_synch=yes",
			"/global/settings/system/bridgeclip=none"
		},
		Permissive = {
			"/global/settings/system/cpath=durden",
			"/global/settings/system/control=control",
			"/global/settings/system/rate_limit/rlimit=0",
			"/global/settings/system/rate_limit/extwndlimit=0",
			"/global/settings/system/rate_limit/subseglimit=20",
			"/global/settings/x11/clipboard_synch=no",
			"/global/settings/statusbar/add/right/add_external=statusbar",
			"/global/settings/system/bridgeclip=full",
		}
-- allow clipboard synch, external button, external input, x11 synch
	}

	table.insert(
		state.security_menus,
		{
			name = "preset",
			kind = "value",
			label = "Preset",
			description = "Select a security preset",
			set = {"Permissive", "Paranoid", "Careful"}, -- custom: add each as separate
			handler = function(ctx, val)
				for i,v in ipairs(sets[val]) do
					dispatch_symbol(v)
				end

-- if careful / permissive we should also query for a lockscreen password
-- as well as swap paste behaviour for popup
				state.in_security = state.in_security + 1
			end
		}
	)

	state.in_security = 1

	return state.security_menus[state.in_security]
end

local function query_presets()
	drop_keys("autostart_%");
	gconfig_set("meta_lock", "none")

	local stages =
	{
		query_a11y,
-- language support would go here when we have translation oracle
		query_wm,
		query_visual,
		query_input,
		query_device,
		query_security,
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
		if locked then
			return
		end

		if #stages == 0 then
			if state.no_vision or state.low_vision then
				dispatch_symbol("/global/tools/tts/voices/basic_eng/speak=Configuration Done")
				dispatch_symbol("/global/tools/tts/voices/basic_eng/speak=Use meta-1 G for global menu")
				dispatch_symbol("/global/tools/tts/voices/basic_eng/speak=Use meta-1 H for target-window menu")
				dispatch_symbol("/global/tools/tts/voices/basic_eng/speak=Use meta-1 H to open a command line shell")

-- MISSING: with low vision, tell about the bindings to control magnification
--          typing assistant binding (?)
			end

			dispatch_symbol("/global/settings/commit")
			return
		end

		local menu = stages[1](state, step)
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
