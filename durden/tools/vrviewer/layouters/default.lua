--
-- basic layout algorithm
--

return function(layer)
	if (layer.fixed) then
		return;
	end

-- 1. separate models that have parents and root models
	local root = {};
	local chld = {};
	local chld_collapse = {};
	for _,v in ipairs(layer.models) do
		if not v.parent then
			table.insert(root, v);
		else
			chld[v.parent] = chld[v.parent] and chld[v.parent] or {};
			table.insert(chld, v.parent);
		end
	end

-- make sure we have one element that is selected at least
	if (not layer.selected and root[1] and
		valid_vid(root[1].external, TYPE_FRAMESERVER)) then
		root[1]:select();
	end

	local max_h = 0;

	local function getang(phi)
		phi = math.fmod(-phi + 0.5*math.pi, 2 * math.pi);
		return 180 * phi / math.pi;
	end

	local rad = layer.radius;
	local dphi_ccw = 0.5 * math.pi;
	local dphi_cw = 0.5 * math.pi;

	for i,v in ipairs(root) do
		local w, h, d = v:get_size();
		w = w + layer.spacing * 1.0 / rad;
		local z = 0;
		local x = 0;
		local ang = 0;
		max_h = max_h > h and max_h or h;

-- special case, at 12 o clock is 0, 0 @ 0 rad. ang is for billboarding,
-- there should just be a model_flag for setting spherical/cylindrical
-- billboarding (or just do it in shader) but it's not there at the
-- moment and we don't want more shader variants or flags.
-- would be nice, yet not always solvable, to align positioning at the
-- straight angles (0, half-pi, pi, ...) though the focal point of the
-- user will likely often be straight ahead and that gets special
-- treatment anyhow.
		if (i == 1) then
			z = -rad * math.sin(dphi_cw);
			dphi_cw = dphi_cw - 0.5 * w;
			dphi_ccw = dphi_ccw + 0.5 * w;

		elseif (i % 2 == 0) then
			x = -rad * math.cos(dphi_cw - w);
			z = -rad * math.sin(dphi_cw - w);

			ang = getang(dphi_cw - 0.5 * w);
			if (v.active) then
				dphi_cw = dphi_cw - w;
			end
		else
			x = -rad * math.cos(dphi_ccw + w);
			z = -rad * math.sin(dphi_ccw + w);

			ang = getang(dphi_ccw + 0.5 * w);
			if (v.active) then
				dphi_ccw = dphi_ccw + w;
			end
		end

-- unresolved, what to do if n_x or p_x reach pi?
		if (v.active) then
			if (math.abs(v.layer_pos[1] - x) ~= 0.0001) or
				(math.abs(v.layer_pos[3] - z) ~= 0.0001) or
				(math.abs(v.layer_ang ~= ang) ~= 0.0001) then

--			instant_image_transform(v.vid);
				move3d_model(v.vid, x, 0, z, v.ctx.animation_speed);
				rotate3d_model(v.vid,
					v.rel_ang[1], v.rel_ang[2], v.rel_ang[3] + ang,
					v.ctx.animation_speed
				);
			end
		end

		v.layer_ang = ang;
		v.layer_pos = {x, 0, z};
	end

-- avoid linking to stay away from the cascade deletion problem, if it needs
-- to be done for animations, then take the delete- and set a child as the
-- new parent.
	local as = layer.ctx.animation_speed;
	for k,v in pairs(chld) do
		local pw, ph, pd = k:get_size();
		local ch = ph;
		local lp = k.layer_pos;
		local la = k.layer_ang;

-- if collapsed, we increment depth by something symbolic to avoid z-fighting,
-- then offset Y enough to just see the tip, otherwise use a similar strategy
-- to the root, ignore billboarding for the time being.
		for i,j in ipairs(k) do
			if (i % 2 == 0) then
				move_image(j.vid, lp[1], lp[2] - ch, lp[3], as);
				ch = ch + ph;
			else
				move_image(j.vid, lp[1], lp[2] + ch, lp[3], as);
			end
			rotate3d_model(j.vid, 0, 0, k.layer_ang, as)
			pw, ph, pd = j:get_size();
			ch = ch + ph;
		end
	end
end
