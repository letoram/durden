-- track active a12_directory connections, used to generate
-- the open/a12_directory/active menu
local log, fmt = suppl_add_logfn("tools");

-- track references to known sinks and substitute that set into target/migrate
local known_sink = {};

local active_dir = {};
local active_kind = {};

local scanner_active = false;
local trust_mode = TRUST_KNOWN;

local function gen_dhandler(mode)
	return
	function(source, status)
		if status.kind == "terminated" then
			log(fmt("discover:mode=%s:terminated:reason=%s", mode, status.last_words));
			delete_image(source);
			if active_kind[mode] and active_kind[mode].button then
				active_kind[mode].button:destroy();
			end
			active_kind[mode] = nil;
		elseif kind ~= "status" then
			return;
		end
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
				nil, nil,
				mouse_handler_factory.statusbar_icon(wm, path, altpath)
			);
	wm:tile_update();
	return res;
end

local function add_discover(mode, vid)
	if not valid_vid(vid) then
		log("discover:deep:launch fail");
		return;
	end

	local tbl = {vid = vid};
	local dmode = gconfig_get("a12net_on_update");

	if dmode == "button_left" or dmode == "button_right" then
		button_factory(dmode, mode, "", "");
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

local function get_applmenu_dir(k)
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
			active_dir[k] = nil;
		end,
		}
	};

	if not active_dir[k] then
		return res;
	end

	for i,v in pairs(active_dir[k].appls) do
		table.insert(res, {
			name = "run_" .. tostring(v),
			kind = "action",
			description = "Download/Synch and run.",
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
				return get_applmenu_dir(k);
			end,
		});
	end
	return res;
end

local function gen_menu_for_known(ent, ind)
-- might be a multipart in progress
	if not ent.complete then
		return;
	end

-- preferred order:
	local names = {};
	local res = {};

	for _,v in ipairs({"tag", "ipv4", "ipv6", "dns", "a12pub"}) do
		if ent.names[v] then
			table.insert(names, v);
		end
	end

-- only consider sources and directories
	if not ent.source and not ent.directory then
		return;
	end

	if #names == 0 then
		log("kind=warning:source=a12net_discover:bad_entry");
		return;
	end

-- source / directory are still possible bitmasks, but directory takes priority
	local npref = (ent.source and "source_" or "") .. (ent.directory and "dir_" or "");
	local lpref = (ent.source and "Source:" or "") .. (ent.directory and "Directory:" or "");

	res.name = npref .. tostring(ind);
	res.description = table.concat(names, " / ");
	res.kind = "action";
	res.label = lpref .. names[i];

	if ent.directory then
	res.handler =
		function()

		end
	else

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
				delete_image(active_kind[v].vid);
				if active_kind[v].button then
					active_kind[v].button:destroy();
				end
				active_kind[v] = nil;
			end
		}
	};

	for i,v in ipairs(v.known) do
		local item = gen_menu_for_known(v, i);
		if item then
			table.insert(res, item);
		end
	end

	return res;
end

local function get_active_menu()
	local keys = {"passive", "sweep", "brodcast", "test"};
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
			description = "Transmit a challenge beacon in the local broadcast domain",
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
		return string.len(val) > 0 and string.len(val) < 31;
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
		dir.button = button_factory(side, host, popup_path, delta_path);
		dir.button:switch_state("alert");

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

	dir.known = true;
end

local function get_dir_cbh(key, host)
	return
	function(source, status)
		if status.kind == "terminated" then
			delete_image(source);

			if active_dir[source].closure then
				active_dir[source]:closure();
			end
			active_dir[source] = nil;

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

		elseif status.kind == "discovered" then

-- there is a new or lost relative directory, source or sink
--
--       this needs to convey connection options
--       and we need to tell the directory service what we want (relay, natpunch, direct)
--       then get the connection data in return
--
		elseif status.kind == "streamstatus" then

-- completion progress of appl-download (relevant until segment_request)
--  show as mouse cursor, button progress, ...

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
			helpsel = function() return {"arcan.divergent-desktop.org"}; end,
			handler =
			function(ctx, val)
				if not val or #val == 0 then
					return;
				end

				local vid = net_open(val, get_dir_cbh(nil, val));
				if valid_vid(vid) then
					target_flags(vid, TARGET_BLOCKADOPT);
					image_tracetag(vid, "net_discover");
					active_dir[vid] = {appls = {}, path = val};
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
