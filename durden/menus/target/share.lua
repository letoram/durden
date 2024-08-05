local function setup_sharing(...)
	suppl_setup_sharing(active_display().selected, ...)
end

local function gen_recdst_wnd(nosound)
	local lst = {};
-- enumerate all windows and add the external ones that aren't the source
	for wnd in all_windows() do
		if (wnd ~= active_display().selected and
-- also need check type again due to window being lost while waiting for selection
			valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			table.insert(lst, {
				name = wnd.name,
				label = wnd:get_name(),
				kind = "action",
				handler = function(ctx, val)
					setup_sharing("", -1, nosound, wnd.external, false, "rec_" .. wnd.name);
				end
			});
		end
	end

	return lst;
end

local function valid_portpass(val)
-- allow default, empty
	if not val or #val == 0 then
		return true;
	end

	local tbl = string.split(val, ":");
-- no ':'
	if not tbl or not tbl[2] then
		return false;
	end

	local port = tonumber(tbl[1]);
-- invalid  type (abc not 123)
	if port == nil then
		return false;
	end

	if #tbl[2] == 0 then
		return false;
	end

-- we'll reuse the validator to extract the arg below
	return true, tonumber(tbl[1]), tbl[2];
end

local function merge_step(steptbl, stat)
	local x2 = steptbl.x + steptbl.width;
	local y2 = steptbl.y + steptbl.height;
	if stat.x < steptbl.x then
		steptbl.x = stat.x;
	end
	if stat.y < steptbl.y then
		steptbl.y = stat.y;
	end

	local sx2 = stat.x + stat.width;
	local sy2 = stat.y + stat.height;
	if x2 < sx2 then
		x2 = sx2;
	end
	if y2 < sy2 then
		y2 = sy2;
	end
	steptbl.width = x2 - steptbl.x;
	steptbl.height = y2 - steptbl.y;
end

local function build_framefun(buf)
-- One optimization missing here still and that is that any dirty rectangle state
-- is actually lost when the client updates due to the rendertarget indirection
-- and readback not being able to track those kinds of details. The fix should
-- be in the engine by modifying stepframe_target to accept a scissor region,
-- and propagate the dirty- update details in the frame delivery event.
--
-- For a12 specifically shmif and it can/will diff against previous frames, but
-- that is costly and adds latency compared to if you already have the correct
-- information.
	local fun;
	fun = function(wnd, stat, from_timer)
		if not wnd.drop_handler or not wnd.name then
			return;
		end

-- already have an update queued, wait for that one, this will automatically rate-
-- limit updates to the 25Hz click when saturated - might want this as a frame hook
-- instead. merging is necessary or we will lose partial updates.
		if wnd.pending_step and not from_timer then
			merge_step(wnd.pending_step, stat);
			return;
		end

		if not valid_vid(buf, TYPE_FRAMESERVER) then
			wnd:drop_handler("frame", fun);
			return;
		end

		rendertarget_forceupdate(buf);

-- edge condition, we are producing frames too fast, set a timer and call into
-- ourselves with the from_timer condition set
		if (stepframe_target(buf, 1, false,
			stat.x, stat.y, stat.width, stat.height) == false) then
			if not from_timer then
				wnd.pending_step = {
					x = stat.x,
					y = stat.y,
					width = stat.width,
					height = stat.height
				};
			end

			timer_add_periodic("share_step_" .. wnd.name, 1, true,
				function()
					fun(wnd, stat, true);
				end, nil, true
			);
		else
			wnd.pending_step = nil;
		end
	end

	return fun;
end

local function gen_sharemenu(label, proto, active, defport, defpass)
return
{
	name = proto,
	label = label,
	kind = "value",
	description = "Share the window contents remotely",
	initial = function()
		return tostring(defport .. ":" .. defpass);
	end,
	hint = "(port:pass)",
	validator = valid_portpass,
	handler =
	function(ctx, val)
		local port = defport;
		local pass = defpass;

		if #val > 0 then
			_, port, pass = ctx.validator(val);
		end

		local argstr = string.format("protocol=%s:port=%d:pass=%s", proto, port, pass);
		local name = proto .. (active and "_act" or "_pass") .. "_" .. tostring(port);

-- we don't have access to the refined list of groups so just set all of them
		if DEBUGLEVEL > 0 then
			argstr = "trace=4095:" .. argstr
		end

-- note that this is 'on-demand' clocked for external sources
		local wnd, buf = setup_sharing(argstr,
			active_display().selected.external and 0 or -1, true,
			"stream", active, proto .. (active and "_active" or "_inactive")
		);

-- registering a frame handler event incs the event-handler refcount and enables
-- the TARGET_VERBOSE that is required to get frame delivery events, we then use
-- those events as a clock to update the rendertarget.
		if wnd and wnd.add_handler then
			wnd:add_handler("frame", build_framefun(buf));
		end
	end
};
end

local function gen_pushmenu(label, name, active)
-- layering violation compared to the other tools, but we have no dispatch for
-- dynamically discovered A12 sources
	return
	{
		name = name,
		label = label,
		kind = "value",
		description = "Push a sharing context to an A12 sink",
		hint = "(tag@ | tag@host | host:port)",
		set = function()
			local tbl = a12net_list_tags("sink");
			local set = {};
			for _,v in ipairs(tbl) do
				table.insert(set, v.tag .. "@" .. v.host);
			end
			return set;
		end,
		eval = function()
			return a12net_list_tags and #a12net_list_tags("sink") > 0;
		end,
		validator = function(str)
			return str and #str > 0;
		end,
		handler = function(ctx, val)
			local argstr = "container=stream:protocol=a12";
			local tag, host = string.split_first(val, "@");
			if #tag > 0 then
				argstr = argstr .. ":tag=" .. tag;
			end
			argstr = argstr .. ":host=" .. host;

			local wnd, buf =
				setup_sharing(argstr,
					active_display().selected.external and 0 or -1, true,
					"stream", active,
					string.format("a12-%s(%s)", active and "active" or "passive",
					val)
				);

			if wnd and wnd.add_handler then
				wnd:add_handler("frame", build_framefun(buf));
			end
		end
	}
end

local function gen_share_menu(active)
	return {
		gen_sharemenu("VNC", "vnc", active, 5900, "guest"),
		gen_sharemenu("A12-inbound", "a12_in", active, 6680, "guest"),
		gen_pushmenu("A12-outbound", "a12_out", active)
	};
end

local function gen_recdst_menu(nosound)
return {
{
	label = "Stream",
	name = "stream",
	kind = "value",
	hint = "rtsp://",
	description = "Stream to an external source",
	handler =
	function(ctx, val)
		local recstr, srate = suppl_build_recargs(true)
		setup_sharing(recstr, srate, nosound, val,
			true, "stream_" .. active_display().selected.name);
	end
},
{
	name = "client",
	kind = "action",
	label = "Client",
	submenu = true,
	description = "Stream to a connected client",
	handler =
	function()
		return gen_recdst_wnd(nosound);
	end
},
{
	name = "file",
	kind = "value",
	label = "File",
	hint = "(output/*.mkv)",
	description = "Record to a file",
	validator = suppl_valid_name,
	handler =
	function(ctx, val)
		local recstr, srate = suppl_build_recargs(false);
		setup_sharing(recstr, srate, nosound,
			"output/" .. val .. ".mkv", false, "rec_" .. active_display().selected.name);
	end
},
{
	name = "custom",
	kind = "value",
	label = "Custom",
	description = "Specify custom (raw) encode arguments",
	hint = "(file=fname:arg1=val1:arg2:arg3=val4...) -> (output/fname)",
	validator = function(a) return a and #a > 0 end,
	handler =
	function(ctx, val)
		local fn = ""
		local prefix = string.sub(val, 1, 5)
		if prefix == "file=" then
			local splitp = string.find(val, ":")
			if splitp then
				fn = "output/" .. string.sub(val, 6, splitp - 1)
				val = string.sub(val, splitp + 1)
			end
		end
		local srate = gconfig_get("enc_srate");
		setup_sharing(val, srate, nosound, fn, false, "custom_" .. active_display().selected.name);
	end
}};
end

local record_menu = {
{
	name = "full",
	label = "Full",
	kind = "action",
	description = "Record, stream or forward both audio and video contents",
	submenu = true,
	handler = function()
		return gen_recdst_menu(false);
	end
},
{
	name = "video",
	kind = "action",
	label = "Video",
	description = "Record, stream or forward video contents",
	submenu = true,
	handler = function()
		return gen_recdst_menu(true);
	end,
}
};

local share_menu = {
{
	name = "passive",
	label = "Passive",
	kind = "action",
	description = "Start a view-only passive sharing session",
	submenu = true,
	handler = function()
		return gen_share_menu(false);
	end
},
{
	name = "active",
	label = "Active",
	kind = "action",
	description = "Start a full sharing session (external input)",
	submenu = true,
	handler = function()
		return gen_share_menu(true);
	end
}
};

local function gen_sessions_menu()
	local res = {};
	local wnd = active_display().selected;
	for k,v in pairs(wnd.share_sessions) do
		table.insert(res, {
			label = v,
			name = k,
			kind = "action",
			handler = function()
				if valid_vid(k) then
					delete_image(k);
				end
				wnd.share_sessions[k] = nil;
			end
		});
	end
	return res;
end

-- Lots of options to possibly expose here and elsewhere, though possibly
-- better to expose a full 'composited tool' similar to the old awb- demo
-- and an alias to that from here. Then we can at least use wnd-tag drag
-- etc.
return {
{
	name = "record",
	label = "Record/Stream",
	kind = "action",
	description = "Record to a file or stream to a remote destination",
	submenu = true,
	handler = record_menu
},
{
	name = "remoting",
	label = "Remoting",
	description = "Share the window contents with an external source",
	kind = "action",
	submenu = true,
	handler = share_menu,
},
-- tools/a12net will override this entry with metadata
{
	name = "migrate",
	label = "Migrate",
	kind = "value",
	hint = "(connpoint)",
	description = "Request that the client connects to a different server",
	eval = function()
		return valid_vid(active_display().selected.external, TYPE_FRAMESERVER);
	end,
	validator = function(val)
		return string.len(val) > 0 and string.len(val) < 31;
	end,
	handler = function(ctx, val)
		target_devicehint(active_display().selected.external, val, true);
	end
},
{
	name = "close",
	label = "Close",
	description = "Terminate an existing sharing session",
	kind = "action",
	submenu = true,
	eval = function()
		local wnd = active_display().selected;

		if not wnd.share_sessions then
			return false;
		end

		for i,v in pairs(wnd.share_sessions) do
			return true;
		end

		return false;
	end,
	handler = gen_sessions_menu
}
};
