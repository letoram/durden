local function apply_scheme(palette, wnd)
	if (palette and valid_vid(wnd.external, TYPE_FRAMESERVER)) then
-- used to convey alpha, color scheme, etc. primarily for TUIs
		for k,v in ipairs(palette) do
			local ind = key_to_graphmode(k);
			if (ind and type(v) == "table" and #v == 3) then
				target_graphmode(wnd.external, ind, v[1], v[2], v[3]);
			else
				warning("apply_scheme(), broken key " .. k);
			end
		end
-- commit
		target_graphmode(wnd.external, 0);
	end
end

local function run_group(group, prefix, wnd)
	local ad = active_display();
	local as = ad.selected;

-- hack around the problem with many menu paths written using the dumb
-- active_display().selected
	if (wnd) then
		ad.selected = wnd;
	end

-- this doesn't check / account for reattachments/migrations etc.
	if (group and type(group) == "table") then
		for k,v in ipairs(group) do
			if (type(v) == "string" and string.starts_with(v, prefix)) then
				dispatch_symbol(v);
			end
		end
	end

-- and restore if we didn't destroy something, but this method isn't safe
-- from modification, and that's mentioned in the documentation
	if (as and as.canvas) then
		ad.selected = as;
	end
end

local function run_domain(group, pal, set)
	run_group(group, "/global/", nil);
	if (set) then
-- need a copy to survive UAF- self modification
		local lst = {};
		for k,v in ipairs(set) do
			table.insert(lst, v);
		end
		for i,wnd in ipairs(lst) do
			if (wnd.canvas) then
				run_group(group, "/target/", wnd);
			end
			apply_scheme(pal, wnd);
		end
	end
end

local function tryload_scheme(v)
	local res = system_load(v, 0);
	if (not res) then
		warning(string.format("devmaps/schemes, system_load on %s failed", v));
		return;
	end

	local okstate, tbl = pcall(res);
	if (not okstate) then
		warning(string.format("devmaps/schemes, couldn't parse/extract %s", v));
		return;
	end

-- FIXME: [a_Z,0-9 on name]
	if (type(tbl) ~= "table" or not tbl.name or not tbl.label) then
		warning(string.format("devmaps/schemes, no name/label field for %s", v));
		return;
	end

-- pretty much all fields are optional as it stands
	return tbl;
end

local schemes;
local function scan_schemes()
	schemes = {};
	local list = glob_resource("devmaps/schemes/*.lua", APPL_RESOURCE);
	for i,v in ipairs(list) do
		local res = tryload_scheme("devmaps/schemes/" .. v);
		if (res) then
			table.insert(schemes, res);
		end
	end
end

function ui_scheme_menu(scope, tgt)
	local res = {};
	if (not schemes) then
		scan_schemes();
		if (not schemes) then
			return;
		end
	end

	for k,v in ipairs(schemes) do
		table.insert(res, {
			name = v.name,
			label = v.label,
			kind = "action",
			handler = function()
				if (scope == "global") then
					local lst = {};
					for wnd in all_windows(true) do
						table.insert(lst, wnd);
					end
					run_domain(v.actions, v.palette, lst);
				elseif (scope == "display") then
					local lst = {};
					for i, wnd in ipairs(tgt.windows) do
						table.insert(lst, wnd);
					end
					run_domain(v.actions, nil, lst);
					run_domain(v.display, v.palette, lst);
				elseif (scope == "workspace") then
					local lst = {};
					for i,v in ipairs(tgt.children) do
						table.insert(lst, v);
					end
					run_domain(v.actions, nil, lst);
					run_domain(v.workspace, v.palette, lst);
				elseif (scope == "window") then
					run_domain(v.actions, nil, {tgt});
					run_domain(v.window, v.palette, {tgt});
				end
			end
		});
	end

	return res;
end
