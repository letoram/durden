-- Copyright: 2015-2017, Björn Ståhl
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
			else
				warning("couldn't load atype: " .. v);
			end
		end
	end
end

function extevh_archetype(atype)
	return archetypes[atype];
end

load_archetypes();

-- check / manage external window creation interception
local extevh_track = {};
function extevh_intercept(path, data, set)
	if (set) then
		extevh_track[path] = data;
	else
		if (extevh_track[path]) then
			extevh_track[path](data);
			return true;
		end
	end
end

local function cursor_handler(wnd, source, status)
-- for cursor layer, we reuse some events to indicate hotspot
-- and implement local warping..
end

local function default_reqh(wnd, source, ev)
	local normal = {
		"lwa", "multimedia", "game", "vm",
		"application", "remoting", "browser"
	};

-- early out if the type is not permitted
	if (wnd.allowed_segments and
		not table.find_i(wnd.allowed_segments, ev.segkind)) then
		return;
	end

-- special handling, cursor etc. maybe we should permit subtype handler override
	if (ev.segkind == "titlebar") then
		if (valid_vid(wnd.titlebar_id)) then
			delete_image(wnd.titlebar_id);
		end
		wnd.titlebar_id = accept_target(wnd.w, gconfig_get("tbar_sz"));
		if (valid_vid(wnd.titlebar_id)) then
			target_updatehandler(wnd.titlebar_id, function(src, stat) end);
			link_image(wnd.titlebar_id, wnd.anchor); -- link for autodel
			image_sharestorage(wnd.titlebar_id, wnd.titlebar.anchor);
		end
		return;
	elseif (ev.segkind == "cursor") then
		if (valid_vid(wnd.cursor_id)) then
			delete_image(wnd.cursor_id);
		end
		local sz = mouse_state().size;
		local cursor = accept_target(sz[1], sz[2]);
		if (valid_vid(cursor)) then
			target_updatehandler(cursor, function(a, b)
				cursor_handler(wnd, a, b);
			end);
			wnd.custom_cursor = {
				vid = cursor,
				active = true,
				width = sz[1], height = sz[2],
				hotspot_x = 0, hotspot_y = 0,
			};
-- something to activate if we are already over? just mouse_xy test against
-- selected canvas?
			link_image(cursor, wnd.anchor);
		end
		return;
	elseif (ev.segkind == "icon") then
-- reject for now, can later be used for status icon and for hint
	else
-- something that should map to a new / normal window?
		if (wnd.allowed_segments or
			(not wnd.allowed_segments and table.find_i(normal, ev.segkind))) then
			local vid = accept_target();
			durden_launch(vid, "", "external", nil);
		end
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
-- FIXME: need multipart concatenation of message, and forwarding
-- to a notification listener (if any)
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

-- got updated ramps from a client, still need to decide what to
-- do with them, i.e. set them as active on window select and remove
-- on window deselect.
defhtbl["ramp_update"] =
function(wnd, source, stat)
	print("ramp update!");
	local ramps = video_displaygamma(source, stat.index);
end

defhtbl["proto_change"] =
function(wnd, source, stat)
	wnd.color_controls = stat.cm;

-- send the ramps for the display the client is active on, repeat if we
-- get migrated to another display
	if (stat.cm) then
		for disp in all_displays_iter() do
			if (disp.ramps) then
				print("send ramps");
				video_displaygamma(source, disp.active_ramps, disp.id);
			end
		end
	end
end

defhtbl["resized"] =
function(wnd, source, stat)
	if (wnd.ws_attach) then
		wnd:ws_attach();
	end
	wnd.source_audio = stat.source_audio;
	audio_gain(stat.source_audio, (gconfig_get("global_mute") and 0 or 1) *
		gconfig_get("global_gain") * wnd.gain);
	wnd.origo_ll = stat.origo_ll;
	image_set_txcos_default(wnd.canvas, stat.origo_ll == true);
	wnd.ext_resize = true;
	wnd.space:resize(true);
end

defhtbl["message"] =
function(wnd, source, stat)
-- FIXME: no multipart concatenation
	wnd:set_message(stat.message, gconfig_get("msg_timeout"));
end

defhtbl["ident"] =
function(wnd, source, stat)
	wnd:set_ident(stat.message);
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

-- some odd archetype handlers (clipboard, ...) want to evaluate and
-- intercept the normal creation process
	if (atbl.intercept) then
		if (not atbl:intercept(wnd, source, stat)) then
			wnd:destroy();
		end
		return;
	end

-- note that this can be emitted multiple times, it is just the
-- segment kind that can't / wont change
	wnd:set_title(stat.title);
	if (wnd.registered) then
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

-- very rarely needed
	for k,v in ipairs(wnd.handlers.register) do
		v(wnd, stat.segkind, stat);
	end
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
		if (not valid_vid(wnd.clipboard)) then
			return;
		end
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
