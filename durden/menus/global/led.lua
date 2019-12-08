local function get_ledent(rgb, devid, i)
	local validator, handler, hint;
	if (rgb) then
		validator = suppl_valid_typestr("fff", 0, 255, 0);
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			if (tbl) then
				set_led_rgb(devid, i-1, tbl[1], tbl[2], tbl[3], false);
			end
		end
		hint = "(r g b 0-255)";
	else
		validator = gen_valid_float(0, 1);
		handler = function(ctx, val)
			set_led(devid, i-1, tonumber(val) > 0.0 and 1 or 0);
		end
		hint = "(0..1)";
	end

	return {
			name = tostring(i),
			label = tostring(i),
			kind = "value",
			description = "Set LED " .. tostring(i) .. " to a specific value",
			hint = hint,
			validator = validator,
			handler = handler
	};
end

local function get_led_menu(dev)
	local nled, var, rgb = controller_leds(dev.devid);
	if (not nled or nled <= 0) then
		return {};
	end
	local res = {};

	local all = get_ledent(rgb, dev.devid, -1);
	all.name = "all";
	all.label = "All";
	table.insert(res, all);

	for i=1,nled do
		table.insert(res, get_ledent(rgb, dev.devid, i));
	end
	return res;
end

return function()
	local devs = ledm_devices("passive");

-- name/label are already set for us
	for k,v in pairs(devs) do
		v.label = v.label;
		v.kind = "action";
		v.submenu = true;
		v.handler = function()
			return get_led_menu(v);
		end
	end
	return devs;
end
