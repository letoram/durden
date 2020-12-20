-- Copyright: 2015-2020, Björn Ståhl
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

-- special window overrides (intended for tools)
local guid_handler_table = {};

local client_log, fmt = suppl_add_logfn("client");

-- notice that logging server to client commands are done elsewhere as
-- the hook is quite costly and we only want to enable it when in an IPC
-- monitor.

function extevh_lookup(source)
	return swm[source];
end

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

local function cursor_handler(wnd, source, status)
-- for cursor layer, we reuse some events to indicate hotspot
-- and implement local warping..
end

local function default_reqh(wnd, source, ev)
	local normal = {
		"lwa", "multimedia", "game", "vm",
		"application", "remoting", "browser",
		"handover", "tui", "terminal"
	};

-- early out if the type is not permitted
	if (wnd.allowed_segments and
		not table.find_i(wnd.allowed_segments, ev.segkind)) then
		client_log("segreq:name=" .. wnd.name ..
			":kind=" .. ev.segkind .. ":state=rejected");
		return;
	end

-- clients want to negotiate a connection on behalf of a new process,
	if (ev.segkind == "handover") then
		local hover = accept_target(32, 32, function(source, stat) end);
		if (not valid_vid(hover)) then
			client_log("segreq:name=" .. wnd.name .. ":kind=handover:state=oom");
			return;
		end

		client_log("segreq:name=" .. wnd.name .. ":state=handover");
		durden_launch(hover, "", "external", nil, {attach_parent = wnd});

-- special handling, cursor etc. maybe we should permit subtype handler override
	elseif (ev.segkind == "cursor") then
		if (wnd.custom_cursor and valid_vid(wnd.custom_cursor.vid)) then
			delete_image(wnd.custom_cursor.vid);
		end

		local sz = mouse_state().size;
		local cursor = accept_target(sz[1], sz[2]);
		if (not valid_vid(cursor)) then
			client_log("segreq:name=" .. wnd.name .. ":kind=mouse_cursor:state=oom");
			return;
		end

		client_log("segreq:name=" .. wnd.name .. ":kind=cursor:state=ok");
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
		return;

	else
-- something that should map to a new / normal window?
		if (wnd.allowed_segments or
			(not wnd.allowed_segments and table.find_i(normal, ev.segkind))) then
			local vid = accept_target();
			if (not valid_vid(vid)) then
				client_log("segreq:name=" .. wnd.name
					.. ":kind=" .. ev.segkind .. ":state=oom");
				return
			end
			client_log("segreq:name=" .. wnd.name
				.. ":kind=" .. ev.segkind .. ":state=ok");

-- inherit workspace if that is set
			local opts;
			if (gconfig_get("ws_child_default") == "parent" or
				gconfig_get("tile_insert_child") == "child") then
				opts = {
					default_workspace = wnd.default_workspace,
					attach_parent = wnd
				};
			end

-- inherit the attached workspace for the child (vid, prefix, title, wnd, wargs)
			durden_launch(vid, "", "external", nil, opts);
		else
			client_log("segreq:name=" .. wnd.name
				.. ":kind=" .. ev.segkind .. ":state=blocked");
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
defhtbl["input_label"] =
function(wnd, source, tbl)
-- reset or first call? there is a synchronization issue here in that the reset
-- and update can come periodically. If that ever becomes an actual problem, using
-- frame delivery as an indicator that the burst is over works.
	client_log(fmt(
		"input_label:name=%s:type=%s:sym=%s", tbl.labelhint, tbl.datatype, tbl.vsym));
	if (not wnd.input_labels or #tbl.labelhint == 0) then
		wnd.input_labels = {};
		if (#tbl.labelhint == 0) then
			return;
		end
	end

-- NOTE: this does not currently respect:
-- a. "description update to language switch response"
	if (#wnd.input_labels > 100) then
		return;
	end

	local ent = {
		label = tbl.labelhint,
		datatype = tbl.idatatype,
		description = tbl.description,
		symbol = tbl.vsym and tbl.vsym or "",
		input = ""
	};

-- add the default as binding unless there's a collision
	if (tbl.initial > 0 and type(SYMTABLE[tbl.initial]) == "string" and
		(tbl.idatatype == "translated" or tbl.idatatype == "digital")) then
		local sym = SYMTABLE[tbl.initial];
		if (tbl.modifiers > 0) then
			sym = table.concat(decode_modifiers(tbl.modifiers), "_") .. "_" .. sym;
		end

-- keep track of the translated string as we might want to present it
		if (not wnd.labels[sym]) then
			wnd.labels[sym] = tbl.labelhint;
			ent.input = sym;
		end
	end

-- we don't have a means of knowing 'when' the hints are over, as they can
-- be part of a dynamically expanding set, so at least track the last time
-- something was changed so that other handlers can take a look at that.
	wnd.label_update = CLOCK;
	table.insert(wnd.input_labels, ent);
end

defhtbl["frame"] =
function(wnd, source, stat)
	if (wnd.shader_frame_hook) then
		wnd:shader_frame_hook();
	end

-- tag with batch and with the incremental engine counter
	client_log("frame");
	wnd.last_frame = stat.framenumber;
	wnd.last_frame_clock = CLOCK;

	wnd:run_event("frame", stat);
end

defhtbl["alert"] =
function(wnd, source, stat)
	local msg;

-- do we need to concatenate a longer message?
	if (wnd.alert_multipart) then
		wnd.alert_multipart.message = wnd.alert_multipart.message .. stat.message;
		wnd.alert_multipart.count = wnd.alert_multipart.count + 1;
		if (wnd.alert_multipart.count > 3 or not stat.multipart) then
			msg = wnd.alert_multipart.message;
			wnd.alert_multipart = nil;
		end
-- first of a multipart text message?
	elseif (stat.multipart) then
		wnd.alert_multipart = {
			message = stat.message,
			count = 1
		};
		return;
	else
		msg = stat.message;
	end

-- actual alert message or just a hint that the client wants some attention
	if (msg and #msg > 0) then
		wnd:set_message(msg);
	else
		wnd:alert();
	end
end

defhtbl["cursorhint"] =
function(wnd, source, stat)
	wnd.cursor = stat.cursor;
end

defhtbl["viewport"] =
function(wnd, source, stat)
-- need different behavior for popup here (invisible, parent, ...),
end

-- got updated ramps from a client, still need to decide what to
-- do with them, i.e. set them as active on window select and remove
-- on window deselect.
defhtbl["ramp_update"] =
function(wnd, source, stat)
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
				video_displaygamma(source, disp.active_ramps, disp.id);
			end
		end
	end
end

defhtbl["resized"] =
function(wnd, source, stat)
	if (wnd.ws_attach) then
-- edge conditions could fail to attach depending on the window type and
-- certain widgets which hijack attachment, like draw-to-spawn modes
		local attach = wnd:ws_attach();
		if (not attach) then
			return;
		end
	end
	wnd.source_audio = stat.source_audio;
	audio_gain(stat.source_audio,
		(gconfig_get("global_mute") and 0 or 1) *
		gconfig_get("global_gain") * wnd.gain
	);

	wnd.origo_ll = stat.origo_ll;
	image_set_txcos_default(wnd.canvas, wnd.origo_ll == true);
	if (wnd.shader_hook) then
		wnd.shader_hook();
	end

-- need to nudge the window with the size delta based on the mask
	if wnd.in_drag_rz then
		local dt = wnd.drag_sz_ack;
		local dw = wnd.effective_w - stat.width;
		local dh = wnd.effective_h - stat.height;
		local dx = dw * dt.pos_x;
		local dy = dh * dt.pos_y;
		wnd:move(dx, dy, false, false, true)
	end

-- this will force a resize
	wnd:resize_effective(stat.width, stat.height, true, true);
	wnd.space:resize(true);
end

defhtbl["bchunkstate"] =
function(wnd, source, stat)
-- if clients are allowed to popup open/close dialogs,
	client_log(
		string.format("bchunk_state:input=%d:stream=%d:hint=%d:ext=%s",
			stat.input and 1 or 0, stat.stream and 1 or 0,
			stat.hint and 1 or 0, stat.wildcard and "*" or stat.extensions
		)
	);

-- this means we have a oneshot request for immediate data
--
-- so respond to that y either immediately triggering the proper
-- target/state/open,save with the temporary set of extensions
--
	if not stat.hint then
		wnd.ephemeral_ext = stat.extensions and stat.extensions or "*";
		local fun =
		function()
			dispatch_symbol_wnd(wnd,
				"/target/state/" .. (stat.input and "open" or "save"));
			wnd.ephemeral_ext = nil;
		end

-- 	go immediately?
		if active_display().selected == wnd then
			fun();
			return;
		end

-- mark alert and set handler
		local fwrap;
		fwrap =
		function()
			fun()
			wnd:drop_handler("select", fwrap);
		end

-- and set temporary on-select handler
		wnd:add_handler("select", fwrap);
		wnd:alert();
		return;
	end

	local dst = stat.input and "input_extensions" or "output_extensions"

	if stat.disable then
		wnd[dst] = nil
		return
	end

-- if someone already set wildcard or we reverted to it
	if stat.wildcard or wnd[dst] == true then
		wnd[dst] = true
		return
	end

-- merge, but we don't really care as we won't probe / filter types
-- for the time being, everything will be exposed as wildcard until
-- the launcher gets the controls to toggle between filter set and
-- wildcard
	if not wnd[dst]	then
		wnd[dst] = stat.extensions

-- expand the set, but if it is too spammy, just switch to wildcard
	else
		wnd[dst] = wnd[dst] .. ";" .. stat.extensions
		if #wnd[dst] > 256 then
			wnd[dst] = true
		end
	end
end

defhtbl["message"] =
function(wnd, source, stat)
-- only archetype specific messaegs permitted here so far
end

defhtbl["ident"] =
function(wnd, source, stat)
	wnd:set_ident(stat.message);
end

defhtbl["terminated"] =
function(wnd, source, stat)
	EVENT_SYNCH[source] = nil;

-- FIXME: check if the terminated window is the one intended when
-- last spawning an interactive menu, and in that case, return out
	wnd:destroy(stat.last_words);
end

function extevh_apply_atype(wnd, atype, source, stat)
	local atbl = archetypes[atype];
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

-- make copies of these so custom overrides/extensions won't be shared
	wnd.bindings = table.copy(atbl.bindings);
	wnd.dispatch = table.copy(atbl.dispatch);
	wnd.labels = table.copy(atbl.labels);

	wnd.source_audio = (stat and stat.source_audio) or BADID;
	wnd.atype = atype;

-- only apply for the selected window, weird edge-case
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

defhtbl["registered"] =
function(wnd, source, stat)
-- ignore 0- value (b64), we also (ab)use injected registered event to get
-- the same path for internal launch via target/cfg where the guid can be
-- tracked in the database.

	local logged = false;
	if (type(stat.guid) == "string") then
		if (stat.guid == "AAAAAAAAAAAAAAAAAAAAAA==") then
-- redirect if an external tool has registered a handler for a specific guid
		else
			logged = true;
			client_log(string.format(
				"registered:name=%s:kind=%s:guid=%s", wnd.name, stat.segkind, stat.guid));
			if (guid_handler_table[stat.guid]) then
				guid_handler_table[stat.guid](wnd, source, stat);
				return;
			end
		end
	end

	if not logged then
		client_log(string.format(
			"registered:name=%s:kind=%s", wnd.name, stat.segkind));
	end
	extevh_apply_atype(wnd, stat.segkind, source, stat);
	wnd:set_title(stat.title);
	wnd:set_guid(stat.guid);
end

--  stateinf is used in the builtin/shared
defhtbl["state_size"] =
function(wnd, source, stat)
	client_log("state_size:name=" ..
		wnd.name .. ":size=" .. tostring(stat.state_size));
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

-- support timer implementation (some reasonable limit),
-- we rely on internal autoclock handling for non-dynamic / periodic
defhtbl["clock"] =
function(wnd, source, stat)
	if (not stat.once) then
		return;
	end
	client_log("clock:unhandled:name=" .. wnd.name);
end

defhtbl["content_state"] =
function(wnd, source, stat)
	client_log("content_state:unhandled:name=" .. wnd.name);
end

defhtbl["segment_request"] =
function(wnd, source, stat)
-- eval based on requested subtype etc. if needed
	if (stat.segkind == "clipboard") then
		client_log("segment_request:name=" .. wnd.name .. ":kind=clipboard");
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

function extevh_register_guid(guid, source, handler)
	if (guid_handler_table[guid]) then
		client_log("guid_override:kind=error:message=EEXIST:source=" .. source ..":guid=" .. guid);
		return;
	else
		client_log("guid_override:kind=registered:source=" .. source .. ":guid=" .. guid);
		guid_handler_table[guid] = handler;
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
		client_log(string.format("source=%d:message=no matching window", source));
		return;

-- tool/plugin bug not registering a valid window
	elseif (not wnd.set_title) then
		swm[source] = nil
		return
	end

-- window handler has priority
	if (wnd.dispatch[stat.kind]) then

-- and if it absorbs the event, break the chain
		local disp = wnd.dispatch[stat.kind];
		local res = false;

-- 1:1 or 1:many
		if (type(disp) == "function") then
			res = disp(wnd, source, stat);
		elseif (type(disp) == "table") then
			for i,v in ipairs(disp) do
				res = v(wnd, source, stat) or res;
			end
		end

		if (res) then
			return;
		end
	end

-- or use the default handler if provided
	if (defhtbl[stat.kind]) then
		defhtbl[stat.kind](wnd, source, stat);
	else
		client_log(string.format("source=%d:message=unhandled:kind=%s", source, stat.kind));
	end
end
