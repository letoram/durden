local function clipboard_paste()
	local wnd = active_display().selected;
	if wnd.paste then
		wnd:paste(CLIPBOARD.globals[1]);
	else
		clipboard_paste_default(wnd, CLIPBOARD.globals[1]);
	end
end

local function clipboard_paste_local()
	local wnd = active_display().selected;
	if wnd.paste then
		wnd:paste(CLIPBOARD:list_local(wnd.clipboard)[1]);
	else
		clipboard_paste_default(wnd, CLIPBOARD:list_local(wnd.clipboard)[1]);
	end
end

local function clipboard_histgen(wnd, lst, promote)
	local res = {};
	for k, v in ipairs(lst) do
		local short = string.shorten(v, 20);
		table.insert(res, {
			name = "hist_" .. tostring(k),
			description = v,
			label = string.format("%d:%s", k, short),
			kind = "action",
			format = suppl_strcol_fmt(short, false),
			select_format = suppl_strcol_fmt(short, true),
			handler = function()
				if (promote) then
					CLIPBOARD:set_global(v);
				else
					local m1, m2 = dispatch_meta();
					if wnd.paste then
						wnd:paste(v);
					else
						clipboard_paste_default(wnd, v);
					end
				end
			end
		});
	end
	return res;
end

local function clipboard_local_history()
	local wnd = active_display().selected;
	return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard));
end

local function clipboard_history()
	return clipboard_histgen(active_display().selected, CLIPBOARD.globals);
end

local function clipboard_urls()
	local res = {};
	local wnd = active_display().selected;

	for k,v in ipairs(CLIPBOARD.urls) do
		local short = string.shorten(v, 20);
		table.insert(res, {
			name = "url_" .. tostring(k),
			label = short,
			description = v,
			fmt = suppl_strcol_fmt(short, false),
			select_fmt = suppl_strcol_fmt(short, true),
			kind = "action",
			handler = function()
				local m1, m2 = dispatch_meta();

				if wnd.paste then
					wnd:paste(v);
				else
					clipboard_paste_default(wnd, v);
				end
			end
		});
	end
	return res;
end

local function pick_type(prov, tbl)
	local res = {};

-- we'd need some remapping table for common types here as some clients
-- (wayland/x11) tend to provide mime- descriptions
	for i,v in ipairs(tbl.types) do
		table.insert(res, {
			name = "type_" .. tostring(i),
			label = v,
			kind = "action",
			handler = function()
				prov(active_display().selected, v);
			end,
		});
	end

	return res;
end

local function table_for_provider(name, tbl)
	return {
		kind = "action",
		label = name,
		name = name,
		submenu = true,
		handler =
		function()
			return pick_type(tbl);
		end,
	};
end

local function clipboard_provmenu()
	local lst, first = CLIPBOARD:get_providers();
	local res = {};

	if first then
		table.insert(res, menu_for_provider("focus", first));
	end

	if ist then
		for i,v in ipairs(lst) do
			table.insert(res, menu_for_provider(v.name, v));
		end
	end

	return res;
end

return {
	{
		name = "paste",
		label = "Paste",
		kind = "action",
		description = "Paste the current entry from the global clipboard",
		eval = function() return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste
	},
	{
		name = "autopaste_on",
		label = "Autopaste",
		kind = "action",
		description = "paste new global clipboard items into this window",
		eval = function()
			local wnd = active_display().selected;
			return
				valid_vid(wnd.external, TYPE_FRAMESERVER) and
				wnd.clipboard_monitor == nil;
		end,
		handler = function()
			local wnd = active_display().selected;
			wnd.clipboard_monitor =
			function(msg, src)
				clipboard_paste_default(wnd, msg);
			end
			CLIPBOARD:add_monitor(wnd.clipboard_monitor);
		end
	},
	{
		name = "autopaste_off",
		label = "Disable Autopaste",
		kind = "action",
		description = "Disable automatically pasting new global clipboard items",
		eval = function()
			return active_display().selected.clipboard_monitor ~= nil;
		end,
		handler = function()
			local wnd = active_display().selected;
			CLIPBOARD:del_monitor(wnd.clipboard_monitor);
			wnd.clipboard_monitor = false;
		end
	},
	{
		name = "lpaste",
		label = "Paste-Local",
		kind = "action",
		description = "Paste the current entry from the local clipboard",
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste_local
	},
	{
		name = "lhist",
		label = "History-Local",
		kind = "action",
		description = "Enumerate the local clipboard history",
		eval = function()
			local wnd = active_display().selected;
			return wnd.clipboard ~= nil and #CLIPBOARD:list_local(wnd.clipboard) > 0;
		end,
		submenu = true,
		handler = function()
			local wnd = active_display().selected;
			return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard));
		end
	},
	{
		name = "providers",
		label = "Providers",
		kind = "action",
		description = "Paste from a specific data provider and type",
		eval = function()
			return #clipboard_provmenu() > 0;
		end,
		submenu = true,
		handler = function()
			return clipboard_provmenu();
		end
	},
	{
		name = "lhistprom",
		label = "Promote",
		kind = "action",
		description = "Promote an entry from the local clipboard to the global shared one",
		eval = function()
			local wnd = active_display().selected;
			return wnd.clipboard ~= nil and #CLIPBOARD:list_local(wnd.clipboard) > 0;
		end,
		submenu = true,
		handler = function()
			local wnd = active_display().selected;
			return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard), true);
		end
	},
	{
		name = "hist",
		label = "History",
		description = "Select an entry from the global history",
		kind = "action",
		submenu = true,
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_history
	},
	{
		name = "url",
		label = "URLs",
		kind = "action",
		description = "Select an entry from the URL catcher",
		submenu = true,
		eval = function()
			return valid_vid(
				active_display().selected.external, TYPE_FRAMESERVER) and
				#CLIPBOARD.urls > 0;
		end,
		handler = clipboard_urls
	},
	{
		name = "mode",
		label = "Mode",
		kind = "value",
		description = "Change the preprocess filter that will be applied before pasting",
		initial = function()
			local wnd = active_display().selected;
			return wnd.pastemode and wnd.pastemode or "";
		end,
		set = CLIPBOARD:pastemodes(),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local f, l = CLIPBOARD:pastemodes(val);
			wnd.pastemode = l;
			wnd.pastefilter = f;
		end
	}
}
