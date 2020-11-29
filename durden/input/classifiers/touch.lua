local idevice_log, fmt = suppl_add_logfn("idevice");
local touchm_evlog = function(msg)
	idevice_log("submodule=touch:classifier=touch:" .. msg);
end

local function init(scaled, prof)
	prof.scaled = scaled;
end

local function sample(dev, io)
-- ignore other sample types for the time being
	if not io.touch then
		return true, dev.touch_only and nil or io;
	end

	if dev.autorange then
		touchm_update_range(dev, io);
	end

-- normalized
	local x = (io.x - dev.range[1]) / dev.range[3];
	local y = (io.y - dev.range[2]) / dev.range[4];

-- match to active display (assuming that the inputs come from there),
-- might want the option to pair this to a specific display (dynamically)
-- as there are use-cases for both, i.e. using one device as a preview
	local ad = active_display();
	local rt = active_display(true);
	local rx = x * ad.width;
	local ry = y * ad.height;

	if dev.in_mouse then
		mask_mouse_input(dev, io)
		return true, nil;
	end

-- missing: check if we have any preconfigured zones (cregions)
-- that accept touch action
	if scaled then
		local wnd = ad.selected;
		if not ad.selected then
			return;
		end
		io.x = x * wnd.effective_width;
		io.y = y * wnd.effective_height;
		wnd:input_table(io);
		return;
	end

-- open question here is if touch is allowed to modify selection status
-- based on its inputs or if that should be limited to the other navigation
-- controls, currently going with yes - but maybe make it into an option
	local lst = pick_items(rx, ry, 1, true, rt);
	local hit = lst[1]
	local wnd;

-- could be optimized for special cases by checking fullscreen state
	if hit then
		for i,v in ipairs(ad.windows) do
			if hit == v.canvas then
				wnd = v;
				break;
			end
		end

		if wnd then
-- window takes in surface sized pixels
			io.x = rx - wnd.x;
			io.y = ry - wnd.y;

			wnd:input_table(io)
		end
	end

-- still here? there might be some other UI element that could be emulated
-- through mouse but messing with those event handlers directly has some
-- problems, then it is better to switch to emulation mode - this will not
-- work if mouse input is provided simultaneously but that edge case can
-- probably be ignored for now
--	dev.in_mouse = true;
	return true, nil;
end

local function tick(dev)
-- there are new simpler models for gesture analysis here that we should
-- perhaps keep a part of this module, or have one that is touch-gesture?
end

return {
	touch =
	{
		init = function(...)
			init(false, ...);
		end,
		sample = sample,
		tick = tick,
		label = "Touch-Fit",
		description = "touch will be forwarded to the surfaces it touches without affecting selection",
		menu = nil,
		gestures = {}
	},
	touch_scaled =
	{
		init = function(...)
			init(true, ...);
		end,
		sample = sample,
		tick = tick,
		label = "Touch-Scaled",
		gestures = {},
		description = "touch samples will follow active selection and client will have full display resolution",
	}
}
