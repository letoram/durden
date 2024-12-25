-- track active a12_directory connections, used to generate
-- the open/a12_directory/active menu
local log, fmt = suppl_add_logfn("tools");

-- track references to known sinks and substitute that set into target/migrate
local known_sink = {};

local known_beacon = {}; -- should autoprune based on CLOCK

local active_dir = {};
local active_kind = {};

-- this relies on passive being the only mode that need multipart pairing now
local pending_multipart;

local scanner_active = false;
local trust_model = TRUST_KNOWN;

local function gen_dhandler(mode)
	return
	function(source, status)
		if status.kind == "terminated" then
			log(fmt("discover:mode=%s:terminated:reason=%s", mode, status.last_words));
			delete_image(source);
			notification_add("networking", nil,
				string.format("Discover (%s) died", mode),
				status.last_words, 2, "/global/tools/networking/discover")

			if active_kind[mode] and active_kind[mode].button then
				active_kind[mode].button:destroy();
			end
			active_kind[mode] = nil;
			return;

		elseif status.kind ~= "state" then
			return;
		end

		if mode == "passive" or mode == "sweep" then
			if status.multipart then
				pending_multipart = status;
				return;
			end

-- new that appeared or a ping from an old known source?
			local kb = known_beacon[status.name];
			if not kb then
				kb = {tags = {}, probed = 0, last_seen = CLOCK};
				known_beacon[status.name] = kb;
			end

-- mark for re-probe if we haven't seen this source make a beacon for a while
			kb.last_seen = CLOCK;

-- tag + ipv4,6 or just ipv4,ipv6
			if pending_multipart then
				local tag = pending_multipart.name;
				pending_multipart = nil;

				for i,v in ipairs(kb.tags) do
					if v == tag then
						return;
					end
				end

				table.insert(kb.tags, tag);
				kb.name = status.name;
			end

-- trigger button alert, but cap it - we latch it to probe completions or other
-- network conditions will make things too noisy regardless
			local last_alert;
			local trigger_update =
			function()
				if not last_alert or CLOCK - last_alert > 5000 then
					last_alert = CLOCK;
					if active_kind["passive"].button then
						active_kind["passive"].button:switch_state("alert");
					end
				end
			end

-- probe is net_open in ? mode with the specified tag and a host override
			if mode == "passive" and kb.probed < #kb.tags then
				kb.probed = kb.probed + 1;
				log(fmt("probe:tag=%s:source=%s", kb.tags[kb.probed], kb.name));

				net_open("?" .. kb.tags[kb.probed], kb.name,
					function(source, status)
						if status.kind == "terminated" then
							delete_image(source);
							log(fmt("discover:probe=%s:fail", kb.name));

-- if we set a rule for the passive, e.g. 'auto-connect new sources' here is the
-- point to trigger for that.
						elseif status.kind == "message" then
							delete_image(source);
							if status.message == "directory" then
								kb.directory = kb.tags[kb.probed];
							end
							if status.message == "source" then
								kb.source = kb.tags[kb.probed];
							end
							if status.message == "sink" then
								kb.sink = kb.tags[kb.probed];
							end
							kb.probed = #kb.tags;
							trigger_update();
							log(fmt("discover:probe=%s:message=%s", kb.name, status.message));
						end
					end
				)
			end

			log(fmt("discover:mode=%s:space=%s:key=%s:name=%s:tag=%s",
				mode,
				status.namespace,
				status.pubk and status.pubk or "unknown",
				status.name,
				kb.tag and kb.tag or "no_tag"
			));
		end

-- other interesting bits: source, sink or directory set (if known)
-- for directory we get tag or ipv4/ipv6 (understands the format but unknown key)
	end
end

local function button_factory(side, label, path, altpath)
	local side = side == "button_left" and "left" or "right";

	local wm = active_display();
	local bar = wm:get_dock();
	local sbh = math.clamp(
		math.ceil(gconfig_get("sbar_sz") * wm.scalef),
		math.ceil(gconfig_get("sbar_min_sz") * wm.scalef)
	);
	local res =
		bar:add_button(side,
				"sbar_item_bg", "sbar_item",
				label,
				gconfig_get("sbar_tpad") * wm.scalef,
				wm.font_resfn,
				nil,
				nil,
				mouse_handler_factory.statusbar_icon(wm, path, altpath)
			);
	res:switch_state("inactive");
	wm:tile_update();
	return res;
end

local function get_tag_host(mode, cb)
	local res = {};

	for k,v in pairs(known_beacon) do
		if v[mode] then
			table.insert(res,
				{
					label = string.format("%s @ (%s)", v[mode], v.name),
					name = mode .. "_" .. tostring(#res+1),
					kind = "action",
					handler = function()
						cb(v, v[mode]);
					end
				}
			)
		end
	end

	return res;
end

function a12net_list_tags(role)
	local res = {};
	for k,v in pairs(known_beacon) do
		if v[role] then
			table.insert(res, {tag = v[role], host = v.name});
		end
	end
	return res;
end

local function dir_data_handler(arg, closure)
	local eof

	arg.instate.input:read(
		function(line, alive)
			table.insert(arg.instate.buffer, line)
			if not alive then
				die = true
			end
		end
	)

	if die then
		log(fmt("net:directory_index:over:items=%s", #arg.instate.buffer))
		arg.instate.input:close()
		local header = table.remove(arg.instate.buffer, 1)
		if header then
			local harg = string.unpack_shmif_argstr(header)
			if not harg.directory_index then
				log(fmt("net:kind=error:bad_index=%s", header))
				return false
			end

-- future revisions should have keywords, type and other metadata here
			local set = {}
			for i,v in ipairs(arg.instate.buffer) do
				local file = string.unpack_shmif_argstr(v)
				if file.file then
					table.insert(set, file.file)
				end
			end

			closure(set)
		end

		return false
	end

	return true
end

local function synch_index(source, arg, closure)
	log("net:kind=status:directory_index:fetch")
	local inf = open_nonblock(source, false, ".index")
	if not inf then
		log("net:kind=error:directory_index:open_fail")
		return
	end

	inf:lf_strip(true, "\n")
	arg.instate = {input = inf, buffer = {}}

	inf:data_handler(function()
		return dir_data_handler(arg, closure)
	end)
end

local function add_discover(mode, vid)
	if not valid_vid(vid) then
		log("discover:deep:launch fail");
		return;
	end

	local tbl = {vid = vid};
	local dmode = gconfig_get("a12net_on_initial");

	if dmode == "button_left" or dmode == "button_right" then
		tbl.button = button_factory(dmode,
			"Discover:" .. mode,
			"/global/tools/popup/menu=/global/tools/networking/discovery/active/" .. mode,
			""
		);

		if mode == "passive" or mode == "sweep" then
			tbl.button.drag_command =
			function(wnd)
				local x, y = mouse_xy()
				uimap_popup({{
					name = "migrate",
					label = "Migrate/Redirect",
					kind = "action",
					submenu = true,
					handler = function()
						return get_tag_host("sink",
							function(ent, tag)
								local path =
									string.format("/target/share/migrate=%s@%s", tag, ent.name);
								dispatch_symbol_wnd(wnd, path);
							end
						)
					end
				},
	-- if we have the virtual display tool, here would be the path to add support
	-- for creating one that attaches to the device in question
				{
					name = "stream",
					label = "Stream/Share (Active)",
					kind = "action",
					submenu = true,
					handler = function()
						return get_tag_host("sink",
							function(ent, tag)
								local path =
									string.format("/target/share/remoting/active/a12_out=%s@%s", tag, ent.name);
								dispatch_symbol_wnd(wnd, path);
							end
						);
					end
				},
				{
					name = "stream",
					label = "Stream/Share (Passive)",
					kind = "action",
					submenu = true,
					handler = function()
						return get_tag_host("sink",
							function(ent, tag)
								local path =
									string.format("/target/share/remoting/passive/a12_out=%s@%s", tag, ent.name);
								log(path);
								dispatch_symbol_wnd(wnd, path);
							end
						);
					end
				},
			}, x, y)
			end
		end
	end

	target_flags(vid, TARGET_BLOCKADOPT);
	active_kind[mode] = tbl;
end

local function launch_appl(v, id)
	if not valid_vid(v, TYPE_FRAMESERVER) then
		log("directory:action=launch_appl:status=fail:message=connection_lost");
		return;
	end

	message_target(v, id);
end

local function attach_source(dir, v)
-- take dir.vid, message with |< or < depending on tunnel preference and append pubk
	log("attach=" .. v.name);
	message_target(dir.vid, "|<" .. v.pubk);
end

local function gen_decode_action(dir, name)
	local nbio = open_nonblock(dir.vid, false, name)

	local aid
	_, aid =
	launch_decode(fn, "protocol=media",
		function(source, status)
			if status.kind == "terminated" then
				if wnd then
					wnd:destroy()
				else
					delete_image(source)
				end
			elseif status.kind == "bchunkstate" then
				open_nonblock(source, false, name, nbio)

			elseif status.kind == "resized" then
				local wnd = durden_launch(source, "dir", dir.path)
				audio_gain(aid, gconfig_get("global_gain") * wnd.gain)
				target_updatehandler(source, extevh_default)
				extevh_default(source, status)
				if wnd.ws_attach then
					wnd:ws_attach()
				end
			end
		end
	)
end

-- this is just monkey patched in from menus/browse.lua
local function gen_cursortag_action(dir, name)
	local ms = mouse_state()
	local ct = ms.cursortag

-- we or someone else?
	if ct and ct.ref ~= "brower" then
		active_display():cancellation()
		ct = nil
	end

-- most of this should move to clipboard.lua or so and be shared as a
-- stack to allow mixing content in the stack
	local fontstr, _ = active_display():font_resfn()
	if not ct then
		local tag = render_text({fontstr, "Placeholder"})

		mouse_cursortag("browser", {},
		function(dst, accept, src)
-- draw the cursortag information, can swap with icon here if needed
-- other possible accept to check for is our own buttons, to drag and
-- drop from the one server to the other.
			if accept == nil then
				return dst and valid_vid(dst.external, TYPE_FRAMESERVER)

			elseif accept == false then
				for _, v in ipairs(src) do
					v.nbio:close()
				end
				return
			end

-- accept, i.e. initiate the transfer pairing
			for _,v in ipairs(src) do
				local nbio, id

				if v.path then
					nbio = open_nonblock(v.path, false)
					id = string.split(v.path, "/")
					id = string.sub(id[#id], -76)

				elseif v.name then
					nbio = open_nonblock(dir.vid, false, v.name)
					id = v.name
				end

				if nbio then
					open_nonblock(dst.external, false, name, nbio)
				else
					warning("browse: couldn't open " .. v.path)
				end
			end
		end, tag)

		ct = ms.cursortag
	end

	if not table.find_key_i(ct.src, "name", name) then
		table.insert(ct.src, {name = name})
		local suffix = #ct.src > 1 and " Files" or " File"
		render_text(ct.vid, {fontstr, tostring(#ct.src) .. suffix})
	end
end

local function gen_action_menu(dir, set, fn)
	local menu = {}
	for i,v in ipairs(set) do
		table.insert(menu, {
			name = "run_ " .. tostring(i),
			label = v,
			kind = "action",
			handler =
			function()
				fn(dir, v)
			end
		})
	end
	return menu
end

local function popup_file_menu(dir, set)
	local menu = {
		{
			name = "open",
			label = "Open",
			description = "Open the file in a designated viewer",
			kind = "action",
			submenu = true,
			handler =
			function()
				return gen_action_menu(dir, set, gen_decode_action)
			end
		},
		{
			name = "cursortag",
			label = "Cursortag",
			description = "Attach the file to the cursor",
			kind = "action",
			submenu = true,
			handler =
			function()
				return gen_action_menu(dir, set, gen_cursortag_action)
			end
		}
	}

	local x, y = mouse_xy()
	uimap_popup(menu, x, y)
end

local function get_dirmenu(k,v)
	local res = {
		{
		name = "disconnect",
		kind = "action",
		label = "Disconnect",
		description = "Close the directory connection",
		handler = function()
			if valid_vid(k) then
				delete_image(k);
			end
			if v.closure then
				v:closure();
			end
			active_dir[k] = nil;
		end,
		}
	};

	if not active_dir[k] then
		return res;
	end

	table.insert(res, {
		name = "sep_del",
		kind = "action",
		label = "--------",
		separator = true,
		eval = function() return false; end,
		handler = function() end
	});

	table.insert(res, {
		name = "files",
		label = "Files",
		kind = "action",
		description = "Access files in the private directory store",
		handler = function()
			synch_index(k, active_dir[k],
				function(set)
					popup_file_menu(active_dir[k], set)
				end
			)
		end
	})

	table.insert(res, {
		name = "sep_del_2",
		kind = "action",
		label = "--------",
		eval = function() return false; end,
		separator = true,
		handler = function()
		end
	})

-- there should also be the option to directly source it
	for i,v in ipairs(active_dir[k].dirs) do
		table.insert(res, {
			name = "open_" .. tostring(v),
			kind = "action",
			label = v .. "/",
			description = "Open the linked " .. v .. " directory",
			handler = function()
				open_dir(k, v);
			end
		});
	end

	if #active_dir[k].dirs > 0 then
		table.insert(res, {
			name = "sep_dir",
			kind = "action",
			label = "--------",
			separator = true,
			eval = function() return false; end,
			handler = function() end
		});
	end

	for i,v in ipairs(active_dir[k].sources) do
		table.insert(res, {
			name = "sink_" .. tostring(v.name),
			kind = "action",
			label = "< " .. v.name,
			description = "Request to sink the " .. v.name .. " source",
			handler = function()
				attach_source(active_dir[k], v);
			end
		});
	end

	if #active_dir[k].sources > 0 then
		table.insert(res, {
			name = "sep_src",
			kind = "action",
			label = "--------",
			separator = true,
			eval = function() return false; end,
			handler = function() end
		});
	end

	for i,v in pairs(active_dir[k].appls) do
		table.insert(res, {
			name = "run_" .. tostring(v),
			kind = "action",
			description = "Download/Synch and run " .. i,
			label = i,
			handler = function()
				launch_appl(k, v);
			end,
		});
	end

	return res;
end

local function gen_a12dir_active()
	local res = {};

	for k,v in pairs(active_dir) do
		table.insert(res, {
			name = "ent_" .. tostring(k),
			label = v.path,
			kind = "action",
			submenu = true,
			handler = function()
				return get_dirmenu(k, v);
			end,
		});
	end
	return res;
end

local function gen_discover_menu(v)
	local res =
	{
		{
			name = "stop",
			label = "Stop",
			kind = "action",
			handler = function()
				if not active_kind[v] then
					return;
				end

	-- flush completely
				if v == "passive" then
					known_beacon = {};
				end

				delete_image(active_kind[v].vid);
				if active_kind[v].button then
					active_kind[v].button:destroy();
				end
				active_kind[v] = nil;
			end
		}
	};

-- add the 'openables'
	for i,v in pairs(known_beacon) do
		if not v.sink then
			for _, tag in ipairs(v.tags) do
				table.insert(res,
					{
						name = "open_tag_" .. #res,
						label = tag .. v.directory and "/" or "",
						kind = "action",
						handler = function()
							dispatch_symbol("/global/open/a12/connect=@" .. tag)
						end
					}
				)
			end
		end
	end

	return res;
end

local function get_active_menu()
	local keys = {"passive", "sweep", "broadcast", "test"};
	local res = {};

	for _,v in ipairs(keys) do
		if active_kind[v] then
			table.insert(res,
				{
					name = v,
					kind = "action",
					label = v,
					submenu = true,
					description = "Stop or view " .. v .. " discover process",
					handler = gen_discover_menu(v)
				}
			);
		end
	end

	return res;
end

local function discover_menu()
	local set =
	{
		{
			name = "passive",
			kind = "action",
			label = "Passive",
			description = "Listen on the local network for known beacons",
			eval = function()
				return active_kind["passive"] == nil;
			end,
			handler = function()
				add_discover("passive",
					net_discover(DISCOVER_PASSIVE, trust_model, gen_dhandler("passive")));
			end,
		},
		{
			name = "sweep",
			kind = "action",
			label = "Sweep",
			description = "Periodically ping all tags in the keystore",
			eval = function()
				return active_kind["sweep"] == nil;
			end,
			handler = function()
				add_discover("sweep",
					net_discover(DISCOVER_SWEEP, trust_model, gen_dhandler("sweep")));
			end,
		},
		{
			name = "broadcast",
			kind = "action",
			label = "Broadcast",
			description = "Periodically broadcast a beacon making you discoverable by others",
			eval = function()
				return active_kind["broadcast"] == nil;
			end,
			handler = function()
				add_discover("broadcast",
					net_discover(DISCOVER_BROADCAST, trust_model, gen_dhandler("broadcast")));
			end,
		},
		{
			name = "active",
			kind = "action",
			label = "Active",
			description = "Control / View an ongoing discovery process",
			eval = function()
				for _,v in pairs(active_kind) do
					return true;
				end
			end,
			submenu = true,
			handler = get_active_menu
		},
	};

	if DEBUGLEVEL > 1 and DISCOVER_TEST ~= nil then
		table.insert(set,
		{
			name = "test",
			kind = "action",
			label = "Test",
			eval = function()
				return active_kind["test"] == nil;
			end,
			description = "Test discovery type which sends both valid and broken events at increasing intervals",
			handler = function()
				add_discover("test", net_discover(DISCOVER_TEST, dhandler));
			end
		});
	end

	return set;
end

local menu =
{
	{
	name = "discovery",
	label = "Discover",
	kind = "action",
	description = "Launch a new service discover process",
	submenu = true,
	handler = discover_menu
	},
};

-- override the migrate option with this one that provides suggestions from
-- our known/discovered tags
if API_VERSION_MAJOR > 0 or API_VERSION_MINOR >= 13 then
menus_register("target", "share", {
	name = "migrate",
	label = "Migrate",
	kind = "value",
	description = "Request that the client connects to a different display server",
	eval = function()
		return valid_vid(active_display().selected.external, TYPE_FRAMESERVER);
	end,
	validator = function(val)
		if #val == 0 then
			return false;
		end
		if string.sub(val, 1, 6) == "a12://" or
			string.sub(val, 1, 7) == "a12s://" then
			return #val < 76;
		else
			return #val < 31;
		end
	end,
	helpsel = function()
		return known_sink;
	end,
	handler = function(ctx, val)
		target_devicehint(active_display().selected.external, val, true);
	end
}
)

-- enforce [a12net_on_initial, a12net_on_update] triggers for when a
-- directory server connection is established.
local function dir_list_trigger(status, dir, key, host)
	if dir.known then
		local mode = gconfig_get("a12net_on_update");
		if mode == "alert" then

		elseif mode == "notify" then

		end
		return;
	end

	local mode = gconfig_get("a12net_on_initial");
	local popup_path =
		"/global/tools/popup/menu=/global/open/a12/active/ent_" .. tostring(key);
	local delta_path =
		"/global/tools/popup/menu=/global/open/a12/new/ent_" .. tostring(key);

	if mode == "button_left" or mode == "button_right" then
-- add the button and map to the same popup
		dir.button = button_factory(mode, host, popup_path, delta_path);
		dir.button:switch_state("alert");

-- compact the options into a popup, we don't want this to trigger on the drop
-- directly as a misdrop is quite dangerous - also need control over 'return
-- on exit' or not.
		dir.button.drag_command =
		function(wnd)
			local x, y = mouse_xy()
			local menu =
			{
				{
					name = "migrate_abandon",
					kind = "action",
					label = "Migrate/Abandon",
					handler =
					function()
						if valid_vid(wnd.external, TYPE_FRAMESERVER) then
							target_devicehint(wnd.external, "a12://" .. dir.path, true);
						else
						end
					end
				}
			}

			uimap_popup(menu, x, y)
		end

	elseif mode == "popup" then
		dispatch_symbol(popup_path);
	elseif mode == "menu" then
		dispatch_symbol("/global/open/a12/active/ent_" .. tostring(key));
	end

	dir.closure =
	function(self)
		if self.button then
			self.button:destroy();
		end
	end

	dir.vid = key;
	dir.known = true;
end

local function get_dir_cbh(key, host, arg)
	return
	function(source, status)
		if status.kind == "terminated" then
			delete_image(source);
			table.remove_match(known_sink, active_dir[source].path);

			if active_dir[source].closure then
				active_dir[source]:closure();
			end
			active_dir[source] = nil;

-- we have a new connection, grab our .index of files to integrate with browser
		elseif status.kind == "registered" and arg.fetch_index then
--			synch_index(source, arg)
--
-- Should track launch / expected, as well as progress on the transfer, the
-- other special thing here is that state management is split in two,
-- arcan-net/afsrv_net handles it in one way, but if the directory server dies
-- things we need a better strategy, including some way to re-establish the
-- connection.
--
-- The most likely solution would be to push a monitor socketpair as
-- bchunkevents and then forget about it ourselves.
--
		elseif status.kind == "segment_request" then
			if status.segkind == "handover" then
				local hover, _, cookie = accept_target(32, 32, function(source, stat) end);
				if valid_vid(hover) then
					durden_launch(hover, "", "external", nil, {});
				end
			end

	-- discovered a change to the directory set of linked connectiond
		elseif status.kind == "state" then
			if status.source then
				if status.name then
					local slist = active_dir[source].sources;

					if status.lost then
						log(fmt("a12net:source=%s:lost", status.name));
						for i,v in ipairs(slist) do
							if v.name == status.name then
								table.remove(slist, i)
								break
							end
						end
					else
						log(fmt("a12net:source=%s:key=%s:found", status.name, status.pubk));
						table.insert(active_dir[source].sources, status);
						if active_dir[source].button then
							active_dir[source].button:switch_state("alert")
						end
					end
				else
					log("a12net:pubk");
				end
			elseif status.sink then

			elseif status.directory then
				log("a12net:dir=%s", status.name);
			end

		elseif status.kind == "streamstatus" then

-- completion progress of appl-download (relevant until segment_request) show
-- as mouse cursor, button progress, ...

		elseif status.kind == "bchunkstate" then
			local tbl = string.split(status.extensions, ";");
			if #tbl ~= 2 then
				log("a12net:kind=error:message=malformed bchunkstate:raw=" .. status.extensions);
				return;
			else
				log("a12net:kind=appl:name=" .. tbl[1]);
				active_dir[source].appls[tbl[1]] = tonumber(tbl[2]);
				if key and tbl[1] == key then
					launch_appl(source, key);
				end
			end

-- don't run triggers when appl is specified
			if not status.multipart then
				if key then
-- the appl we were looking for wasn't there, notify and leave
					delete_image(source);
				else
					dir_list_trigger(status, active_dir[source], source, host);
				end
			end

		else
			log("net_open:" .. status.kind);
		end
	end
end

local function gen_a12dir()
	local res =
{
		{
			name = "connect",
			label = "Connect",
			kind = "value",
			description = "Specify a directory to connect to",
			hint = "(host or @tag)",
			helpsel = function()
	-- this should also cover discovered results
				local set = {}
				for k,v in pairs(known_beacon) do
					for _,tag in ipairs(v.tags) do
						table.insert(set, "@" .. tag)
					end
				end
				table.sort(set)
				table.insert(set, "arcan.divergent-desktop.org")
				return set
			end,
			handler =
			function(ctx, val)
				if not val or #val == 0 then
					return;
				end

				local arg = {
					appls = {},
					sources = {},
					dirs = {},
					files = {},
					path = val,
					fetch_index = string.sub(val, 1, 1) == "@"
				};

				local vid = net_open(val, get_dir_cbh(nil, val, arg));
				if valid_vid(vid) then
					target_flags(vid, TARGET_BLOCKADOPT);
					image_tracetag(vid, "net_discover");
					active_dir[vid] = arg
				end
			end
		},
		{
			name = "active",
			label = "Active",
			kind = "action",
			description = "Active connections",
			submenu = true,
			eval = function()
				for _,v in pairs(active_dir) do
					return true;
				end
			end,
			handler =
			function()
				return gen_a12dir_active();
			end,
		}
	};
	return res;
end

local network_opts = {
	{
		kind = "value",
		name = "dir_mgmt",
		label = "List Management",
		initial = function() return gconfig_get("a12net_on_initial"); end,
		description = "Set the default action for when a directory connection is established.",
		set = {"button_left", "button_right", "popup", "menu", "none"},
		handler = function(ctx, val)
			gconfig_set("a12net_on_initial", val);
		end,
	},
	{
		kind = "value",
		name = "dir_list",
		label = "List Updated",
		initial = function() return gconfig_get("a12net_on_update"); end,
		description = "Set the default action for when there are changes to the directory.",
		set = {"alert", "notify", "ignore"},
		handler = function(ctx, val)
			gconfig_set("a12net_on_update", val);
		end
	},
	{
		kind = "value",
		name = "discover",
		label = "On Discover",
		initial = function() return gconfig_get("a12net_on_discover"); end,
		description = "Set the default action for discovery processes.",
		set = {"button_left", "button_right", "notify"},
		handler = function(ctx, val)
			gconfig_get("a12net_on_discover", val);
		end
	}
};

gconfig_register("a12net_on_initial", "button_left");
gconfig_register("a12net_on_discover", "button_left");
gconfig_register("a12net_on_update", "alert");

timer_add_periodic(
	"a12net", 1000, false,
	function()
		local keys = {};
		for k,v in pairs(known_beacon) do
			if CLOCK - v.last_seen > 25 * 180 then
				table.insert(keys, k);
			end
		end
		for _,v in ipairs(keys) do
			known_beacon[v] = nil;
		end
	end,
	true
);

menus_register("global", "settings/tools",
{
	kind = "action",
	name = "networking",
	label = "Networking",
	description = "Settings for tools/Networking (open/a12, target/share/...)",
	submenu = true,
	handler = network_opts
});

menus_register("global", "open",
{
	name = "a12",
	label = "A12-Directory",
	kind = "action",
	submenu = true,
	description = "Connect to an a12 directory server",
	handler = function()
		return gen_a12dir();
	end,
});

-- while the symbols are there, the function behaviour wasn't defined
-- until a non-released version so block this out for the time being
menus_register("global", "tools",
{
	name = "networking",
	label = "Networking",
	submenu = true,
	description = "Arcan-a12 compatible service discovery",
	kind = "action",
	handler = menu
});
end
