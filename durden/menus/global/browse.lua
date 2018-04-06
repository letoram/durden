local prev_cache = {};
local function imgwnd(fn, pctx)
	if (pctx and valid_vid(pctx.vid)) then
-- if finished, just take new window and take ownership of vid
-- otherwise update vid with new handler that spawns window on activation
		local st = image_state(pctx.vid);
		if (st == "asynchronous state") then
			pctx.spawn = pctx.vid;
			pctx.title = "image:" .. fn;
			pctx.vid = BADID;
		else
			pctx.vid = BADID;
		end
	else
		load_image_asynch(fn, function(src, stat)
			if (stat.kind == "loaded") then
				wnd = active_display():add_window(src, {scalemode = "aspect"});
				wnd:set_title("image:" .. fn);
			elseif (valid_vid(src)) then
				delete_image(src);
				active_display():message("couldn't load " .. fn);
			end
		end);
	end
end

local function setup_prev(src, anchor, xofs, basew)
	local time = gconfig_get("animation");
	link_image(src, anchor);
	resize_image(src, basew, 0);
	local props = image_surface_properties(src);
	resize_image(src, 8, 8);
	move_image(src, xofs + basew * 0.5, 0);
	resize_image(src, basew, 0, time);
	blend_image(src, 1.0, time);
	nudge_image(src, -basew * 0.5, -props.height, time);
	image_inherit_order(src, true);
end

local function vidprev(path, name, space, anchor, xofs, basew, mh)
	local fn = path .. "/" .. name;
	if (not resource(fn, space)) then
		return;
	end

	for k,v in pairs(prev_cache) do
		if (valid_vid(v)) then
			instant_image_transform(v);
			blend_image(v, k == fn and 1.0 or 0.3, gconfig_get("animation"));
		end
	end

	if (prev_cache[fn]) then
		return;
	end

	launch_avfeed("", "decode",
	function(source, status)
		if (status.kind == "resized") then
			setup_prev(src, anchor, xofs, basew);
			if (mh) then
				mh.child = src;
			end
		end
	end);
end

local function imgprev(path, name, space, anchor, xofs, basew, mh)
-- cache loaded paths, on trigger we know we are "focused" and
-- should be a bit larger
	local fn = path .. "/" .. name;
	if (not resource(fn, space)) then
		return;
	end

	for k,v in pairs(prev_cache) do
		if (valid_vid(v)) then
			instant_image_transform(v);
			blend_image(v, k == fn and 1.0 or 0.3, gconfig_get("animation"));
		end
	end

	if (prev_cache[fn]) then
		return;
	end

	local vid = load_image_asynch(fn,
	function(src, stat)
		if (stat.kind == "loaded") then
			setup_prev(src, anchor, xofs, basew);
			if (mh) then
				mh.child = src;
			end
		end
-- death is easy, destroy will be called by lbar
		end
	);
	prev_cache[fn] = vid;
	return {
		vid = vid,
		name = name,
		destroy = function(ctx)
			prev_cache[fn] = nil;
			if (valid_vid(ctx.vid)) then
				delete_image(vid);
			end
		end,
		activate = function(ctx)
			imgwnd(fn, ctx);
		end
	};
end

-- track lastpath so we can meta-launch browse internal and resume old path
local lastpath = "";
local function decwnd(fn, path)
	lastpath = path;
	local vid = launch_decode(fn, function() end);
	if (valid_vid(vid)) then
		durden_launch(vid, "", fn);
		durden_devicehint(vid);
	else
		active_display():message("decode- frameserver broken or out-of-resources");
	end
end

return function()
	local imghnd = { run = imgwnd, col = HC_PALETTE[1],
		selcol = HC_PALETTE[1], preview = imgprev };
	local audhnd = { run = decwnd, col = HC_PALETTE[2],
		selcol = HC_PALETTE[2] };
	local dechnd = { run = decwnd, col = HC_PALETTE[3],
		selcol = HC_PALETTE[3], preview = decprev };

-- decode- frameserver doesn't have a way to query type and extension for
-- a specific resource, and running probes on all files in a folder with
-- 10k entries might be a little excessive
	local ffmts = {jpg = imghnd, png = imghnd, bmp = imghnd,
		ogg = audhnd, m4a = audhnd, flac = audhnd, mp3 = audhnd,
		mp4 = dechnd, wmv = dechnd, mkv = dechnd, avi = dechnd,
		flv = dechnd, mpg = dechnd, mpeg = dechnd, mov = dechnd,
		webm = dechnd
	};

	browse_file(nil, ffmts, SHARED_RESOURCE, nil, nil, {});
end
