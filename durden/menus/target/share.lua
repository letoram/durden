local function build_recargs(streaming, argstr)
-- grab the defaults
	local vcodec = gconfig_get("enc_vcodec");
	local fps = gconfig_get("enc_fps");
	local vbr = gconfig_get("enc_vbr");
	local vqual = gconfig_get("enc_vqual");
	local container = streaming and "stream" or gconfig_get("enc_container");
	local srate = gconfig_get("enc_srate");

-- extract 'overrides' from argstr

-- compose into argument string
	argstr = string.format(
		"vcodec=%s:fps=%.3f:container=%s%s",
		vcodec, fps, container,
		vqual > 0 and (":vpreset=" .. tostring(vqual)) or (":vbitrate=" .. tostring(vbr))
	);

	return argstr, srate;
end

suppl_recarg_hint = "(stored in output/name.mkv)";

-- function is actually used both for record, stream and vnc, just different args.
local function share_input(wnd, allow_input, source, status, iotbl)
	if status.kind == "terminated" then
		if #status.last_words > 0 then
			notification_add(wnd.title, wnd.icon, "Sharing Died", status.last_words, 2);
		end

		delete_image(source);
		wnd.share_sessions[source] = nil;

	elseif status.kind == "input" and allow_input then
		wnd:input_table(iotbl);
	end
end

local function setup_sharing(argstr, srate, nosound, destination, allow_input, name)
	local wnd = active_display().selected;
	local props = image_storage_properties(wnd.canvas);

	if not wnd.ignore_crop and wnd.crop_values then
		props.width = (wnd.crop_values[4] - wnd.crop_values[2]);
		props.height = (wnd.crop_values[3] - wnd.crop_values[1]);
	end

-- notice: some cases we would want to align to divisible/2,/16 something.
	local storew = props.width % 2 ~= 0 and props.width + 1 or props.width;
	local storeh = props.height % 2 ~= 0 and props.height + 1 or props.height;

-- grab intermediate buffer (direct sharing rather than blt- would open priority inversion)
	local surf = alloc_surface(storew, storeh);
	if not valid_vid(surf) then
		return;
	end

-- and 'container' for the canvas
	local nsrf = null_surface(props.width, props.height);
	if not valid_vid(nsrf) then
		delete_image(surf);
		return;
	end
	image_sharestorage(wnd.canvas, nsrf);
	show_image(nsrf);
	link_image(surf, wnd.anchor);

-- later we'd want a bigger set with windows that have multiple sources
	local sset = {};
	if nosound or not wnd.source_audio then
		argstr = argstr .. ":nosound";
	else
		sset[1] = wnd.source_audio;
	end

	define_recordtarget(surf, destination, argstr, {nsrf}, sset,
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, srate,
		function(...)
			share_input(wnd, allow_input, ...);
		end
	);

-- don't let this one survive script error recovery
	target_flags(surf, TARGET_BLOCKADOPT);

-- want to keep track of all window sharing (can be many) for manual removal
	if not wnd.share_sessions then
		wnd.share_sessions = {};
	end
	wnd.share_sessions[surf] = name;
	return wnd, surf;
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
	handler = function(ctx, val)
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

-- one optimization missing here still and that is that any dirty rectangle state
-- is actually lost when the client updates due to the rendertarget indirection
-- and readback not being able to track those kinds of details. The fix should be
-- in the engine by modifying stepframe_target to accept a scissor region, and
-- propagate the dirty- update details in the frame delivery event
		local fun;
		fun = function(wnd, stat, from_timer)
			if not wnd.drop_handler then
				return;
			end

-- already have an update queued, wait for that one, this will automatically rate-
-- limit updates to the 25Hz click when saturated - might want this as a frame hook
-- instead. merging is necessary or we will lose partial updates.
			if wnd.pending_step and not from_timer then
				merge_step(wnd.pending_step, stat);
				return;
			end

			if valid_vid(buf, TYPE_EXTERNAL) then
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

					timer_add_periodic("share_step_" .. wnd.name, 1, true, function()
						fun(wnd, stat, true);
					end, nil, true);
				else
					wnd.pending_step = nil;
				end
			else
				wnd:drop_handler("frame", fun);
			end
		end

-- registering a frame handler event incs the event-handler refcount and enables
-- the TARGET_VERBOSE that is required to get frame delivery events, we then use
-- those events as a clock to update the rendertarget.
		if wnd and wnd.add_handler then
			wnd:add_handler("frame", fun);
		end
	end
};
end

local function gen_share_menu(active)
	return {
		gen_sharemenu("VNC", "vnc", active, 5900, "guest"),
		gen_sharemenu("A12", "a12", active, 6680, "guest")
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
		local recstr, srate = build_recargs(true)
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
		local recstr, srate = build_recargs(false);
		setup_sharing(recstr, srate, nosound,
			"output/" .. val .. ".mkv", false, "rec_" .. active_display().selected.name);
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
{
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
