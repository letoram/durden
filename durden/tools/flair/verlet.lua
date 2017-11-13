local sqrt = math.sqrt;

local function normal_solve(cons)
  local dx = cons.p1.x - cons.p2.x;
  local dy = cons.p1.y - cons.p2.y;
  local dist = sqrt(dx * dx + dy * dy);
  local diff = (cons.length - dist) / dist;

-- check dist against tearing distance here to drop link
  local s1 =
		(1.0 / cons.p1.mass) /
		((1.0 / cons.p1.mass) + (1.0 / cons.p2.mass));
  local s2 = 1.0 - s1;

-- spring links, add to one, remove from the other
 	cons.p1.x = cons.p1.x + dx * s1 * diff;
 	cons.p1.y = cons.p1.y + dy * s1 * diff;

 	cons.p2.x = cons.p2.x - dx * s2 * diff;
 	cons.p2.y = cons.p2.y - dy * s2 * diff;

	if (cons.p1.pinned) then
		cons.p1.x = cons.p1.pin_x;
		cons.p1.y = cons.p1.pin_y;
	end
	if (cons.p2.pinned) then
		cons.p2.x = cons.p2.pin_x;
		cons.p2.y = cons.p2.pin_y;
	end
end

local function build_constraint(p_a, p_b, space)
	return {
		p1 = p_a,
		p2 = p_b,
		length = space,
		solver = normal_solve
	};
end

local function add_force(pt, fx, fy)
	pt.ax = pt.ax + fx / pt.mass;
	pt.ay = pt.ay + fy / pt.mass;
end

local function make_point(x, y, dx, dy, mass, pin)
	return {
		x = x, y = y, px = x, py = y,
		ox = x, oy = y,
		ax = 0, ay = 0, mass = mass,
		damp_x = dx, damp_y = dy,
		pinned = pin, pin_x = x, pin_y = y
	};
end

-- apply verlet step for one point
-- v += (v - lv) + damp * velocity + 0.5 * accel
local function step_point(pt)
	if (pt.pinned) then
		return;
	end

	local vlx = pt.x - pt.px;
	local vly = pt.y - pt.py;
	local nx = pt.x + pt.damp_x * vlx + 0.5 * pt.ax;
	local ny = pt.y + pt.damp_y * vly + 0.5 * pt.ay;
	pt.px = pt.x;
	pt.py = pt.y;
	pt.x = nx;
	pt.y = ny;
	pt.ax = 0;
	pt.ay = 0;
end

-- smoothstep interpolation function used to reach restore state
local function interp(v1, v2, f)
-- f < 0.00001 ? v1 : v1 + (v2 - v1) * (1.0 - pow(2.0, -10.0 * f))
	local res = (f - 0.1) / (0.9 - 0.1);
	math.clamp(res, 0.0, 1.0);
	res = res * res * (3.0 - 2.0 * res);
	return v1 + res * (v2 - v1);
end

return {
	links = {},
	build = function(ctx, w, h, passes, spacing, gravity, lfun)
		ctx.accuracy = passes;
		ctx.spacing = spacing;
		ctx.gravity = gravity;
		ctx.links = {};
		ctx.points = {};
		ctx.w = w;
		ctx.h = h;
-- point field
		for y=0,h-1 do
			for x=0,w-1 do
				local lx, ly, pin, mass, dx, dy = lfun(x, y);
				table.insert(ctx.points, make_point(lx, ly, dx, dy, mass, pin));
			end
		end

-- p(0,0) <- p(1,0) <- p(2,0)
--   ^         ^         ^
-- p(0,1) <- p(1,1) <- p(2,1)
		for y=0,h-1 do
			for x=0,w-1 do
				if (x ~= 0) then
					local pa_n = ctx.points[y * w + x    ];
					local pa   = ctx.points[y * w + x + 1];
					table.insert(ctx.links, build_constraint(pa, pa_n, ctx.spacing));
				end
				if (y ~= 0) then
					local pa_n = ctx.points[(y  ) * w + x + 1];
					local pa   = ctx.points[(y-1) * w + x + 1];
					table.insert(ctx.links, build_constraint(pa, pa_n, ctx.spacing));
				end
			end
		end
		return ctx;
	end,
	pin = function(ctx, x, y, pv, len)
		if (not len) then
			len = 1;
		end
		for i=x,len do
			local pt = ctx.points[y * ctx.w + x + 1];
			if (not pt) then
				return;
			end
				pt.pinned = pv;
				pt.pin_x = pt.x;
				pt.pin_y = pt.y;
				pt.lx = pt.x;
				pt.ly = pt.y;
		end
	end,
-- irreversibly sever links
	cut = function(ctx, x, y)
		local pt = ctx.points[y * ctx.w + x + 1];
		if (not pt) then
			return;
		end
		for i=#ctx.links,1,-1 do
			if (ctx.links[i].p1 == pt or ctx.links[i].p2) then
				table.remove(ctx.links, i);
			end
		end
	end,
-- apply a force to all points or a specific point
	add_force = function(ctx, fx, fy, x, y)
		if (not x) then
			for i=1,#ctx.points do
				add_force(ctx.points[i], fx, fy);
			end
		else
			local pt = ctx.points[y * ctx.w + x + 1];
			if (pt) then
				add_force(pt, fx, fy);
			end
		end
	end,

-- remove vertices back to their original location
	restore = function(ctx, nt)
		ctx.restore = nt;
		ctx.restore_count = 0;
	end,

	tick = function(ctx)
		if (ctx.restore) then
			if (ctx.restore - ctx.restore_count > 0) then
				local f = ctx.restore_count / ctx.restore;
				for i=1,#ctx.points do
					ctx.points[i].x = interp(ctx.points[i].x, ctx.points[i].ox, f);
					ctx.points[i].y = interp(ctx.points[i].y, ctx.points[i].oy, f);
				end
				ctx.restore_count = ctx.restore_count + 1;
			end
			return;
		end

		for j=1,ctx.accuracy do
			for i=1,#ctx.links do
				normal_solve(ctx.links[i]);
			end
		end
		for j=1,#ctx.points do
			local pt = ctx.points[j];
			add_force(pt, 0, pt.mass * ctx.gravity);
			step_point(pt);
		end
	end
};
