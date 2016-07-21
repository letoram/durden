-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main event-handlers for different external connections
-- and their respective subsegments. Handles registering new windows,
-- hinting default sizes, update timers etc.

-- Every connection can get a set of additional commands and configurations
-- based on what type it has. Supported ones are registered into this table.
-- init, bindings, settings, commands
local archetypes = {};

-- source-id-to-window-mapping
local swm = {};

local function load_archetypes()
-- load custom special subwindow handlers
	local res = glob_resource("atypes/*.lua", APPL_RESOURCE);
	if (res ~= nil) then
		for k,v in ipairs(res) do
			local tbl = system_load("atypes/" .. v, false);
			tbl = tbl and tbl() or nil;
			if (tbl and tbl.atype) then
				archetypes[tbl.atype] = tbl;
			end
		end
	end
end

function extevh_archetype(atype)
	return archetypes[atype];
end

load_archetypes();

local function cursor_handler(wnd, source, status)
-- for cursor layer, we reuse some events to indicate hotspot
-- and implement local warping..
end

local function default_reqh(wnd, source, ev)
	local normal = {"lightweight arcan",
		"multimedia", "game", "vm", "application", "remoting", "browser"};

-- we have a different default handler for these or else we could have
-- wnd_subseg->req[icon] icon_subseg->req[icon] etc.

	local blacklist = {
		"hmd-l", "sensor", "hmd-r", "hmd-sbs-lr", "encoder",
		"accessibility"
	};

	if (blacklist[ev.segkind]) then
		return;
	end

	if (normal[ev.segkind]) then
		accept_target(source, default_handler);
		target_updatehandler(source, default_handler);
		return;
	end

	if (ev.segkind == "titlebar") then
		if (valid_vid(wnd.titlebar_id)) then
			delete_image(wnd.titlebar_id);
		end
		local props = image_surface_properties(wnd.titlebar);
		wnd.titlebar_id = accept_target(props.width, props.height);
		target_updatehandler(wnd.titlebar_id, function() end);
		link_image(wnd.titlebar_id, wnd.anchor); -- link for autodel
		image_sharestorage(wnd.titlebar_id, wnd.titlebar);
		return;
	elseif (ev.segkind == "cursor") then
		if (valid_vid(wnd.cursor_id)) then
			delete_image(wnd.cursor_id);
		end
		local sz = mouse_state().size;
		wnd.cursor_id = accept_target(sz[1], sz[2]);
		target_updatehandler(wnd.cursor_id, function(a, b)
			cursor_handler(wnd, a, b);
		end);
		if (wnd.wm.selected == wnd) then
			mouse_custom_cursor({
				vid = wnd.cursor_id,
				width = sz[1], height = sz[2],
				hotspot_x = 0, hotspot_y = 0
			});
		end
		link_image(wnd.cursor_id, wnd.anchor);
		return;
	elseif (ev.segkind == "icon") then
-- reject for now, can later be used for status icon and for hint
	end
end

function extevh_clipboard(wnd, source, status)
	if (status.kind == "terminated") then
		delete_image(source);
		if (wnd) then
			wnd.clipboard = nil;
		end
	elseif (status.kind == "message") then
-- got clipboard message, if it is multipart, buffer up to a threshold (?)
		CLIPBOARD:add(source, status.message, status.multipart);
	end
end

local defhtbl = {};

defhtbl["framestatus"] =
function(wnd, source, stat)
-- don't do any state / performance tracking right now
end

defhtbl["alert"] =
function(wnd, source, stat)
-- FIXME: need multipart concatenation of message
end

defhtbl["cursorhint"] =
function(wnd, source, stat)
	wnd.cursor = stat.cursor;
end

defhtbl["viewport"] =
function(wnd, source, stat)
-- need different behavior for popup here (invisible, parent, ...),
-- FIXME:	wnd:custom_border(ev->viewport.border);
end

defhtbl["resized"] =
function(wnd, source, stat)
	wnd.source_audio = stat.source_audio;
	audio_gain(stat.source_audio, (gconfig_get("global_mute") and 0 or 1) *
		gconfig_get("global_gain") * wnd.gain);
	wnd.origo_ll = stat.origo_ll;
	image_set_txcos_default(wnd.canvas, stat.origo_ll == true);

-- only block after FIRST (need initial dimensions)
	if (not wnd.resize_block or not wnd.ext_resize) then
		wnd:resize_effective(stat.width, stat.height);
	end
	wnd.ext_resize = true;
-- special case, we mark the resize as 'reposition only'
	wnd.space:resize(true);
end

defhtbl["message"] =
function(wnd, source, stat)
-- FIXME: no multipart concatenation
	wnd:set_message(stat.message, gconfig_get("msg_timeout"));
end

defhtbl["ident"] =
function(wnd, source, stat)
	wnd.ident = stat.message;
	wnd:set_title(stat.message);
end

defhtbl["terminated"] =
function(wnd, source, stat)
	EVENT_SYNCH[source] = nil;

-- if the target menu is active on the same window that is being
-- destroyed, cancel it so we don't risk a tiny race
	local ictx = active_display().input_ctx;
	if (active_display().selected == wnd and ictx and ictx.destroy and
		LAST_ACTIVE_MENU == grab_shared_function("target_actions")) then
		ictx:destroy();
	end
	wnd:destroy();
end

defhtbl["registered"] =
function(wnd, source, stat)
	local atbl = archetypes[stat.segkind];
	if (atbl == nil or wnd.atype ~= nil) then
		return;
	end

-- note that this can be emitted multiple times, it is just the
-- segment kind that can't / wont change
	if (wnd.registered) then
		if (stat.title and string.len(stat.title) > 0) then
			wnd:set_title(stat.title, true);
		end
		return;
	end

-- project / overlay archetype specific toggles and settings
	wnd.actions = atbl.actions;
	if (atbl.props) then
		for k,v in pairs(atbl.props) do
			wnd[k] = v;
		end
	end

-- can either be table [tgt, cfg] or [guid]
	if (not wnd.config_tgt) then
		wnd.config_tgt = stat.guid;
	end

	wnd.bindings = atbl.bindings;
	wnd.dispatch = merge_dispatch(shared_dispatch(), atbl.dispatch);
	wnd.labels = atbl.labels and atbl.labels or {};
	wnd.source_audio = stat.source_audio;
	wnd.atype = atbl.atype;

-- should always be true but ..
	if (active_display().selected == wnd) then
		if (atbl.props.kbd_period) then
			iostatem_repeat(atbl.props.kbd_period);
		end

		if (atbl.props.kbd_delay) then
			iostatem_repeat(nil, atbl.props.kbd_delay);
		end
	end

-- specify default shader by properties (e.g. no-alpha, fft) or explicit name
	if (atbl.default_shader) then
		shader_setup(wnd.canvas, unpack(atbl.default_shader));
	end

	if (atbl.init) then
		atbl:init(wnd, source);
	end

	if (stat.title and string.len(stat.title) > 0) then
		wnd:set_title(stat.title, true);
	end
--	wnd:load_config(wnd.config_tgt);
end

--  stateinf is used in the builtin/shared
defhtbl["state_size"] =
function(wnd, source, stat)
	wnd.stateinf = {size = stat.state_size, typeid = stat};
end

-- simple key / preset-val store of options that could persist between
-- execution runs (if we have a way to identify target, so primary for when we
-- can trust ident or, better, store in target/config slots.
defhtbl["coreopt"] =
function(wnd, source, stat)
	if (not wnd.coreopt) then
		wnd.coreopt = {};
	end

	local dtbl = wnd.coreopt[stat.slot];
	if (not dtbl) then
		dtbl = {
			values = {}
		};
		wnd.coreopt[stat.slot] = dtbl;
	end

	if (string.len(stat.argument) == 0) then
		return;
	end

	if (stat.type == "key") then
		dtbl.key = stat.argument;
	elseif (stat.type == "description") then
		dtbl.description = stat.argument;
	elseif (stat.type == "value") then
-- ARBITRARY LIMIT
		if (#dtbl.values < 64) then
			table.insert(dtbl.values, stat.argument);
		end
	elseif (stat.type == "current") then
		dtbl.current = stat.argument;
	end
end

-- support timer implementation (some reasonable limit), we rely on internal
-- autoclock handling for non-dynamic / periodic
defhtbl["clock"] =
function(wnd, source, stat)
	if (not stat.once) then
		return;
	end
	-- FIXME:
	-- value, id; add to window timer and tick handler will work with it
end

defhtbl["content_state"] =
function(wnd, source, stat)
-- FIXME: map to window scroll-bars (rel_x, rel_y, x_size, y_size)
end

defhtbl["segment_request"] =
function(wnd, source, stat)
-- eval based on requested subtype etc. if needed
	if (stat.segkind == "clipboard") then
		if (wnd.clipboard ~= nil) then
			delete_image(wnd.clipboard)
		end
		wnd.clipboard = accept_target();
		link_image(wnd.clipboard, wnd.anchor);
		target_updatehandler(wnd.clipboard,
			function(source, status)
				extevh_clipboard(wnd, source, status)
			end
		);
	else
		default_reqh(wnd, source, stat);
	end
end

function extevh_register_window(source, wnd)
	if (not valid_vid(source, TYPE_FRAMESERVER)) then
		return;
	end
	swm[source] = wnd;

	target_updatehandler(source, extevh_default);
	wnd:add_handler("destroy",
	function()
		extevh_unregister_window(source);
		CLIPBOARD:lost(source);
	end);
end

function extevh_unregister_window(source)
	swm[source] = nil;
end

function extevh_get_window(source)
	return swm[source];
end

function extevh_default(source, stat)
	local wnd = swm[source];

	if (not wnd) then
		warning("event on missing window");
		return;
	end

	if (DEBUGLEVEL > 0 and active_display().debug_console) then
		active_display().debug_console:target_event(wnd, source, stat);
	end

-- window handler has priority
	if (wnd.dispatch[stat.kind]) then
		if (DEBUGLEVEL > 0 and active_display().debug_console) then
			active_display().debug_console:event_dispatch(wnd, stat.kind, stat);
		end

-- and only forward if the window handler accepts
		if (wnd.dispatch[stat.kind](wnd, source, stat)) then
			return;
		end
	end

	if (defhtbl[stat.kind]) then
		defhtbl[stat.kind](wnd, source, stat);
	else
	end
end
