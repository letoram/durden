-- Copyright: 2015-2017, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Shader compilation and setup.

if (SHADER_LANGUAGE == "GLSL120") then
local old_build = build_shader;
function build_shader(vertex, fragment, label)
	vertex = vertex and ("#define VERTEX\n" .. vertex) or nil;
	fragment = fragment and ([[
		#ifdef GL_ES
			#ifdef GL_FRAGMENT_PRECISION_HIGH
				precision highp float;
			#else
				precision mediump float;
			#endif
		#else
			#define lowp
			#define mediump
			#define highp
		#endif
	]] .. fragment) or nil;

--
--  [ dump to get real line numbers ]
--	local debug = string.split(fragment, "\n");
--	for i,v in ipairs(debug) do print(i, v); end
--
--
	return old_build(vertex, fragment, label);
end
end

local shdrtbl = {
	effect = {},
	ui = {},
	display = {},
	audio = {},
	simple = {}
};

local groups = {"effect", "ui", "display", "audio", "simple"};

function shdrmgmt_scan()
 	for a,b in ipairs(groups) do
 		local path = string.format("shaders/%s/", b);

		for i,j in ipairs(glob_resource(path .. "*.lua", APPL_RESOURCE)) do
			local res = system_load(path .. j, false);
			if (res) then
				res = res();
				if (not res or type(res) ~= "table" or res.version ~= 1) then
					warning("shader " .. j .. " failed validation");
				else
					local key = string.sub(j, 1, string.find(j, '.', 1, true)-1);
					shdrtbl[b][key] = res;
				end
		else
				warning("error parsing " .. path .. j);
 			end
		end
	end
end

shdrmgmt_scan();

local function set_uniform(dstid, name, typestr, vals, source)
	local len = string.len(typestr);
	if (type(vals) == "table" and len ~= #vals) or
		(type(vals) ~= "table" and len > 1) then
		warning("set_uniform called from broken source: " .. source);
 		return false;
	end
	if (type(vals) == "table") then
		shader_uniform(dstid, name, typestr, unpack(vals));
 	else
		shader_uniform(dstid, name, typestr, vals);
	end
	return true;
end

local function load_from_file(relp, lim)
	local res = {};
	if (open_rawresource(relp)) then
		local line = read_rawresource();
		while (line ~= nil and lim -1 ~= 0) do
			table.insert(res, line);
			line = read_rawresource();
			lim = lim - 1;
		end
		close_rawresource();
	else
		warning(string.format("shader, load from file: %s failed, EEXIST", relp));
	end

	return table.concat(res, "\n");
end

local function setup_shader(shader, name, group)
	if (shader.shid) then
		return true;
	end

-- ugly non-blocking read (note, this does not cover variants)
	if (not shader.vert and shader.vert_source) then
		shader.vert = load_from_file(string.format(
			"shaders/%s/%s", group, shader.vert_source), 1000);
	end

	if (not shader.frag  and shader.frag_source) then
		shader.frag = load_from_file(string.format(
			"shaders/%s/%s", group, shader.frag_source), 1000);
	end

	local dvf = (shader.vert and
		type(shader.vert == "table") and shader.vert[SHADER_LANGUAGE])
		and shader.vert[SHADER_LANGUAGE] or shader.vert;

	local dff = (shader.frag and
		type(shader.frag == "table") and shader.frag[SHADER_LANGUAGE])
		and shader.frag[SHADER_LANGUAGE] or shader.frag;

	shader.shid = build_shader(dvf, dff, group.."_"..name);
	if (not shader.shid) then
		shader.broken = true;
		warning("building shader failed for " .. group.."_"..name);
	return false;
	end
-- this is not very robust, bad written shaders will yield fatal()
	for k,v in pairs(shader.uniforms) do
		set_uniform(shader.shid, k, v.utype, v.default, name .. "-" .. k);
	end
	return true;
end

local function preload_effect_shader(shdr, group, name)
	for _,v in ipairs(shdr.passes) do
		if (not v.shid) then
			setup_shader(v, name, group);
		end
		if (not shdr.scale) then
			shdr.scale = {1, 1};
		end
		if (not shdr.filter) then
			shdr.filter = "bilinear";
		end
		if (not shdr.maps) then
			shdr.maps = {};
		else
			for i,v in ipairs(shdr.maps) do
				if (type(v) == "string") then
					shdr.maps[i] = load_image_asynch(
						string.format("shaders/lut/%s", v),
-- defer shader application if the LUT can't be loaded?
						function() end
					);
				end
			end
		end
	end
end

-- for display, state is actually the display name
local function dsetup(shader, dst, group, name, state)
	if (not setup_shader(shader, dst, name)) then
		return;
	end

	if (not shader.states) then
		shader.states = {};
	end

	if (not shader.states[state]) then
		shader.states[state] = shader_ugroup(shader.shid);
	end
	image_shader(dst, shader.states[state]);
end

local function filter_strnum(fltstr)
	if (fltstr == "bilinear") then
		return FILTER_BILINEAR;
	elseif (fltstr == "linear") then
		return FILTER_LINEAR;
	else
		return FILTER_NONE;
	end
end

local function ssetup(shader, dst, group, name, state)
	if (not shader.shid) then
		setup_shader(shader, name, group);

-- states inherit shaders, define different uniform values
		if (shader.states) then
			for k,v in pairs(shader.states) do
				shader.states[k].shid = shader_ugroup(shader.shid);

				for i,j in pairs(v.uniforms) do
					set_uniform(v.shid, i, shader.uniforms[i].utype, j,
						string.format("%s-%s-%s", name, k, i));
				end
			end
		end
	end
-- now the shader exists, apply
	local shid = ((state and shader.states and shader.states[state]) and
		shader.states[state].shid) or shader.shid;
	image_shader(dst, shid);
end

local function esetup(shader, dst, group, name)
	if (not shader.passes or #shader.passes == 0) then
		return;
	end

-- Special shortpath, only one pass - used when we want global settings but
-- otherwise the behavior of a simple shader
	if (#shader.passes == 1 and shader.no_rendertarget) then
		return ssetup(shader.passes[1], dst, group, name);
	end

-- Track the order in which the rendertargets are created. This is needed as
-- each rendertarget is setup with manual update controls as a means of synching
-- with the frame delivery rate of the source.
	local rtgt_list = {};

-- the process of taking a pass description, creating an intermediate FBO
-- applying the pass shader and returning the outcome. Subtle edge conditions
-- to look out for here.
	local build_pass = function(invid, pass)
		local props = image_storage_properties(invid);
		local fmt = ALLOC_QUALITY_NORMAL;

		if (pass.float) then
			fmt = ALLOC_QUALITY_FLOAT16;
		elseif (pass.float32) then
			fmt = ALLOC_QUALITY_FLOAT32;
		end
		if (pass.filter) then
			image_texfilter(invid, filter_strnum(pass.filter));
		end

-- min-clamp as there's a limit for the rendertarget backend store,
-- note that scaling doesn't work with all modes (e.g. autocrop) or client types
		local outw = math.clamp(props.width * pass.scale[1], 32);
		local outh = math.clamp(props.height * pass.scale[2], 32);

		local outvid = alloc_surface(outw, outh, true, fmt);
		if (not valid_vid(outvid)) then
			return invid;
		end
-- FIXME: missing renderset->LUTs (which requires a null surface, detach +
-- hide on the invid + renderset and sharestorage on the null surface)

-- sanity checks and resource loading/preloading
		define_rendertarget(outvid, {invid},
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
		image_shader(invid, pass.shid);
		resize_image(invid, outw, outh);
		move_image(invid, 0, 0);
		show_image({invid, outvid});
		table.insert(rtgt_list, outvid);
		rendertarget_forceupdate(outvid);
		return outvid;
	end

-- this is currently quite wasteful, there is a blit-out copy stage in order
-- to get an output buffer that can simply be sharestorage()d into the canvas
-- slot rather than all the complications with swap-in-out.
	local function build_passes()
		local props = image_storage_properties(dst);
		local invid = null_surface(props.width, props.height);
		image_sharestorage(dst, invid);

		for i=1,#shader.passes do
			invid = build_pass(invid, shader.passes[i]);
		end

-- chain finished and stored in invid, final blitout pass so we have a
-- shareable storage format
		local outprops = image_storage_properties(invid);
		local outvid = alloc_surface(outprops.width, outprops.height);
		define_rendertarget(outvid, {invid},
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
		table.insert(rtgt_list, outvid);
--		show_image(outvid);
		if (shader.filter) then
			image_texfilter(outvid, filter_strnum(shader.filter));
		end
		return outvid;
	end

	preload_effect_shader(shader, group, name);
	local outvid = build_passes();
	rendertarget_forceupdate(outvid);
	hide_image(outvid);

-- return a reference to the video object, a refresh function and a
-- rebuild-or-destroy function.
	return outvid, function()
		for i,v in ipairs(rtgt_list) do
			rendertarget_forceupdate(v);
		end
	end,
	function(vid, destroy)
		for i,v in ipairs(rtgt_list) do
			delete_image(v);
		end
		rtgt_list = {};
-- this is unnecessarily expensive, better approach would be to re-enumerate
-- the passes and just resize rendertarget and inputs / outputs
		if (not destroy and valid_vid(vid)) then
			dst = vid;
			return build_passes();
		end
	end;
end

-- note: boolean and 4x4 matrices are currently ignored
local utype_lut = {
i = 1, f = 1, ff = 1, fff = 1, ffff = 1
};

local function add_stateref(res, uniforms, shid)
	for k,v in pairs(uniforms) do
		if (not v.ignore) then
			table.insert(res, {
			name = k,
			label = v.label,
			kind = "value",
			hint = (type(v.default) == "table" and
				table.concat(v.default, " ")) or tostring(v.default),
			eval = function()
				return utype_lut[v.utype] ~= nil;
			end,
			validator = suppl_valid_typestr(v.utype, v.low, v.high, v.default),
			handler = function(ctx, val)
				shader_uniform(shid, k, v.utype, unpack(
					suppl_unpack_typestr(v.utype, val, v.low, v.high)));
			end
		});
		end
	end
end

-- the different shader types:
-- 'ui' Has states that need to be forwarded. Right now, there is just
-- one shared for all UI elements because the delete_shader approach for
-- ugroups is faulty, so we'd have problems after 64k such changes but we
-- do want to be able to forward more window specific parameters, like
-- privilege level and so on.
--
-- 'simple, audio' are treated as ui, though won't have an instanced state.
--
-- displays are inherently single pass.
--
-- 'effect' is more complicated as it needs to support multiple passes
-- with indirect offscreen rendering and will be chainable in the future.
--
local function smenu(shdr, grp, name)
	if (not shdr.uniforms) then
		return;
	end

	local found = false;
	for k,v in pairs(shdr.uniforms) do
		if (not v.ignore) then
			found = true;
			break;
		end
	end
	if (not found) then
		return;
	end

	local res = {
	};

	if (shdr.states) then
		for k,v in pairs(shdr.states) do
-- build even if it hasn't been used yet, otherwise this might cause menu
-- entries not being available at start - and add stateref needs a shid to
-- reference the uniform to
			if (not v.shid and not v.broken) then
				local nsrf = null_surface(1, 1);
				ssetup(shdr, nsrf, grp, name);
				delete_image(nsrf);
			end

			if (v.shid) then
				table.insert(res, {
					name = "state_" .. k,
					label = k,
					kind = "action",
					submenu = true,
					handler = function()
						local res = {};
						add_stateref(res, shdr.uniforms, v.shid);
						return res;
					end
				});
			end
		end
	else
		add_stateref(res, shdr.uniforms, shdr.shid);
	end

	return res;
end

local function emenu(shdr, grp, name, state)
	if (not shdr.passes or #shdr.passes == 0) then
		return {};
	end

	local get_pass_menu = function(pass)
		local res = {};
		if (not pass.shid) then
			setup_shader(pass, name, grp);
		end
		add_stateref(res, pass.uniforms, pass.shid);
		return res;
	end

	if (#shdr.passes == 1) then
		return get_pass_menu(shdr.passes[1]);
	end

	local res = {};
	for i,pass in ipairs(shdr.passes) do
		table.insert(res, {
			submenu = true,
			kind = "action",
			name = "pass_" .. tostring(i),
-- dynamic call this as it might trigger shader compilation which scales poorly
			handler = function() return get_pass_menu(pass); end,
			label = tostring(i)
		});
	end
	return res;
end

local function dmenu(shdr, grp, name, state)
	local res = {};
	if (not shdr.uniforms) then
		return res;
	end

	if (not shdr.states[state]) then
		warning("display shader does not have matching display");
		return res;
	end

	local found = false;
	for k,v in pairs(shdr.uniforms) do
		if (not v.ignore) then
			found = true;
			break;
		end
	end

	if (not found) then
		return res;
	end

	add_stateref(res, shdr.uniforms, shdr.states[state]);
	return res;
end

-- argument one [ setup ], argument two, [ configuration menu ]
local fmtgroups = {
	ui = {ssetup, smenu},
	effect = {esetup, emenu},
	display = {dsetup, dmenu},
	audio = {ssetup, smenu},
	simple = {ssetup, smenu}
};

-- Prepare a shader with the rules applies from [group, name] in the optional
-- state [state]. If the group is [effect] it will return the output of the
-- chain using [dst] as initial input - if this is different from [dst] it is
-- to be treated as a dynamically allocated/resolution sensitive effect chain
-- with the last stage of the chain applied as effect.
function shader_setup(dst, group, name, state)
	if (not fmtgroups[group]) then
		group = group and group or "no group";
		warning("shader_setup called with unknown group " .. group);
		return dst;
	end

	if (not shdrtbl[group] or not shdrtbl[group][name]) then
		warning(string.format(
			"shader_setup called with unknown group(%s) or name (%s) ",
			group and group or "nil",
			name and name or "nil"
		));
		return dst;
	end

	return fmtgroups[group][1](shdrtbl[group][name], dst, group, name, state);
end

function shader_uform_menu(name, group, state)
	if (not fmtgroups[group]) then
		warning("shader_setup called with unknown group " .. group);
		return {};
	end

	if (not shdrtbl[group] or not shdrtbl[group][name]) then
		warning(string.format(
			"shader_setup called with unknown group(%s) or name (%s) ",
			group and group or "nil",
			name and name or "nil"
		));
		return {};
	end

	return fmtgroups[group][2](shdrtbl[group][name], group, name, state);
end

-- update shader [sname] in group [domain] for the uniform [uname],
-- targetting either the global [states == nil] or each individual
-- instanced ugroup in [states].
function shader_update_uniform(sname, domain, uname, args, states)
	assert(shdrtbl[domain]);
	assert(shdrtbl[domain][sname]);
	local shdr = shdrtbl[domain][sname];
	if (not states) then
		states = {"default"};
	end

	for k,v in ipairs(states) do
		local dstid, dstuni;
-- special handling, allow default group to be updated alongside substates
		if (v == "default") then
			dstid = shdr.shid;
			dstuni = shdr.uniforms;
		else
			if (shdr.states[v]) then
				dstid = shdr.states[v].shid;
				dstuni = shdr.states[v].uniforms;
			end
		end
-- update the current "default" if this is set, in order to implement
-- uniform persistance across restarts
		if (dstid) then
			if (set_uniform(dstid, uname, shdr.uniforms[uname].utype,
				args, "update_uniform-" .. sname .. "-"..uname) and dstuni[uname]) then
				dstuni[uname].default = args;
			end
		end
	end
end

function shader_getkey(name, domain)
	if (not domain) then
		domain = groups;
	end

	if (type(domain) ~= "table") then
		domain = {domain};
	end

-- the end- slide of Lua, why u no continue ..
	for i,j in ipairs(domain) do
		if (shdrtbl[j]) then
			for k,v in pairs(shdrtbl[j]) do
				if (v.label == name or k == name) then
					return k, j;
				end
			end
		end
	end
end

function shader_key(label, domain)
	for k,v in ipairs(shdrtbl[domain]) do
		if (v.label == label) then
			return k;
 		end
 	end
end

function shader_list(domain)
	local res = {};

	if (type(domain) ~= "table") then
		domain = {domain};
	end

	for i,j in ipairs(domain) do
		if (shdrtbl[j]) then
			for k,v in pairs(shdrtbl[j]) do
				table.insert(res, v.label);
			end
		end
	end
	return res;
end
