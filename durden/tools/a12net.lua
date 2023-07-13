-- track active a12_directory connections, used to generate
-- the open/a12_directory/active menu
local log, fmt = suppl_add_logfn("tools");

local active_dir = {};
local active_kind = {};

local known = {};
local scanner_active = false;
local trust_mode = TRUST_KNOWN;

local function gen_dhandler(mode)
	return
	function(source, status)
		if status.kind == "terminated" then
			log(fmt("discover:mode=%s:terminated:reason=%s", mode, status.last_words));
			delete_image(source);
			active_kind[mode] = nil;
		elseif kind ~= "status" then
			return;
		end
	end
end

local function add_discover(mode, vid)
	if not valid_vid(vid) then
		log("discover:deep:launch fail");
		return;
	end
	target_flags(vid, TARGET_BLOCKADOPT);
	active_kind[mode] = vid;
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

local function gen_stop_menu()
	local keys = {"passive", "sweep", "brodcast", "test", "dir_src", "dir_sink"};
	local res = {};
	for _,v in ipairs(keys) do
		if active_kind[v] then
			table.insert(res,
				{
					name = v,
					kind = "action",
					label = v,
					description = "Stop " .. v .. " discovery",
					handler = function()
						if not valid_vid(active_kind[v]) then
							return;
						end
						delete_image(active_kind[v]);
						active_kind[v] = nil;
					end,
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
			handler = function()
				add_discover("broadcast",
					net_discover(DISCOVER_BROADCAST, trust_model, gen_dhandler("broadcast")));
			end,
		},
		{
			name = "dir_src",
			kind = "value",
			label = "Directory-Source",
			description = "Become discoverable as a source through a third party",
			validator = a12_dirstr,
			handler = function(ctx, val)
				add_discover("dir_src",
					net_discover(DISCOVER_DIRECTORY,
						trust_model, "mode=source:" .. val, gen_dhandler("dir_source")));
			end
		},
		{
			name = "dir_sink",
			kind = "value",
			label = "Directory-Sink",
			description = "Become discoverable as a source through a third party",
			validator = a12_dirstr,
			handler = function(ctx, val)
				add_discover("dir_sink",
					net_discover(DISCOVER_DIRECTORY,
						trust_model, "mode=sink:" .. val, gen_dhandler("dir_sink")));
			end
		},
		{
			name = "stop",
			kind = "action",
			label = "Stop",
			description = "Stop ongoing discovery process",
			eval = function()
				for _, v in pairs(active_kind) do
					return true;
				end
			end,
			submenu = true,
			handler = gen_stop_menu
		}
	};

	if DEBUGLEVEL > 1 and DISCOVER_TEST ~= nil then
		table.insert(set,
		{
			name = "test",
			kind = "action",
			label = "Test",
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
		return known;
	end,
	handler = function(ctx, val)
		target_devicehint(active_display().selected.external, val, true);
	end
}
)

-- enforice [a12net_on_initial, a12net_on_update] triggers for when a
-- directory server connection is established.
local function dir_list_trigger(dir, key)
	if dir.known then
		return;
	end

-- button is slightly more annoying, we lack an indirection for keeping
-- track over when
	local mode = gconfig_get("a12net_on_initial");
	if mode == "button_left" or mode == "button_right" then

	elseif mode == "popup" then
		dispatch_symbol("/global/tools/popup/menu=/global/open/a12/active/ent_" .. tostring(key));
	elseif mode == "menu" then
		dispatch_symbol("/global/open/a12/active/ent_" .. tostring(key));
	end

	dir.closure =
	function()
	end

	dir.known = true;
end

local function get_dir_cbh(key, dtbl)
	return
	function(source, status)
		if status.kind == "terminated" then
			delete_image(source);
			if active_dir[source].closure then
				active_dir[source].closure();
			end
			active_dir[source] = nil;

--
-- Should track launch / expected, the other special thing here is that state
-- management is split in two, arcan-net/afsrv_net handles it in one way, but
-- if the directory server dies things we need a better strategy, including
-- some way to re-establish the connection.
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

			if not status.multipart then
				dir_list_trigger(active_dir[source], source);
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

				local vid = net_open(val, get_dir_cbh(nil));
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
		set = {"alert", "event", "ignore"},
		handler = function(ctx, val)
			gconfig_set("a12net_on_update", val);
		end
	}
};

gconfig_register("a12net_on_initial", "button_left");
gconfig_register("a12net_on_update", "alert");

menus_register("global", "settings",
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
