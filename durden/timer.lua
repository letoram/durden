-- Copyright: 2016, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Timer functionality for durden, useful for fire-once
-- or repeated timers, both idle (resetable) and monotonic
--

local idle_timers = {};
local timers = {};
local wakeups = {};

local clockkey = APPLID .. "_clock_pulse";
local old_clock = _G[clockkey];
local idle_count = 0;
local tick_count = 0;
local idle_masked = false;

local function run_idle_timers()
	for i=#idle_timers,1,-1 do
		if (idle_count >= idle_timers[i].delay and not idle_timers[i].passive
			and not idle_timers[i].suspended) then
			idle_timers[i].trigger();
-- add to front of wakeup queue so we get last-in-first-out
			if (idle_timers[i].wakeup) then
				table.insert(wakeups, 1, idle_timers[i].wakeup);
			end
			if (idle_timers[i].once) then
				table.remove(idle_timers, i);
			else
				idle_timers[i].passive = true;
			end
		end
	end
end

function timer_tick(...)
	idle_count = idle_count + 1;
	tick_count = tick_count + 1;

-- idle timers are more complicated in the sense that they require both
-- a possible 'wakeup' stage and tracking so that they are not called repeatedly.
	if (not idle_masked) then
		run_idle_timers();
	end

	for i=#timers,1,-1 do
		if (not timers[i].suspended) then
			timers[i].count = timers[i].count - 1;
			if (timers[i].count == 0) then
				timers[i].trigger();
				if (timers[i].once) then
					table.remove(timers, i);
				else
					timers[i].count = timers[i].delay;
				end
			end
		end
	end

	old_clock(...);
end

_G[clockkey] = timer_tick;

function timer_mask_idle(state)
	if (nil == state) then
		return idle_masked;
	end
	if (true == state) then
		idle_masked = true;
		idle_count = 0;
	elseif (false == state) then
		idle_masked = false;
	end
end

function timer_list(group, active)
	local groups = {timers, idle_timers};
	if (group) then
		if (group == "timers") then
			group = {timers};
		elseif (group == "idle_timers") then
			group = {idle_timers};
		end
	end

	local res = {};
	for i,j in ipairs(groups) do
		for k,l in ipairs(j) do
			if (not l.hidden and (
				active == nil or ((active == true and not l.suspended) or
				(active == false and l.suspended)))) then
				table.insert(res, l.name);
			end
		end
	end

	return res;
end

function timer_reset_idle()
	idle_count = 0;
	for i,v in ipairs(wakeups) do
		v();
	end
	local wakeup = {};

	for i,v in ipairs(idle_timers) do
		if (v.passive) then
			v.passive = nil;
		end
	end
	wakeups = {};
end

local function find(name, drop)
	for k,v in ipairs(idle_timers) do
		if (v.name == name) then
			if (drop) then
				table.remove(idle_timers, k);
			end
			return v;
		end
	end
	for k,v in ipairs(timers) do
		if (v.name == name) then
			if (drop) then
				table.remove(timers, k);
			end
			return v;
		end
	end
end

function timer_delete(name)
	find(name, true);
end

function timer_suspend(name)
	local timer = find(name);
	if (not timer) then
		warning("unknown timer " .. name .. " requested");
	end
	timer.suspended = true;
end

function timer_resume(name)
	local timer = find(name);
	if (not timer) then
		warning("unknown timer " .. name .. " requested");
	end
-- slight question if we need to reset count here for idle timers,
-- but the ida is that whatever triggered this call should've reset
-- the idle counter anyhow
	timer.suspended = false;
end

-- add an idle timer that will trigger after [delay] ticks.
-- [name] is a unique- user presented/enumerable text tag.
-- if [once], then the timer will be removed after being fired once.
-- [trigger] is the required callback that will be invoked,
-- [wtrigger] is an optional callback that will be triggered when we
-- move out of idle state.
local function add(dst, name, delay, once, trigger, wtrigger, hidden)
	assert(name);
	assert(delay);
	assert(trigger and type(trigger) == "function");

	local res = find(name, true);
	if (res) then
		res.delay = delay;
		res.once = once;
		res.trigger = trigger;
		res.wakeup = wtrigger;
	else
		res = {
			name = name,
			delay = delay,
			once = once,
			trigger = trigger,
			wakeup = wtrigger
		};
	end
	res.hidden = hidden;
	table.insert(dst, res);
	return res;
end

function timer_add_idle(name, delay, once, trigger, wtrigger, hidden)
	local grp = add(idle_timers, name, delay, once, trigger, wtrigger, hidden);
	grp.kind = "idle";
end

function timer_add_periodic(name, delay, once, trigger, hidden)
	local grp = add(timers, name, delay, once, trigger, hidden);
	grp.count = delay;
	grp.kind = "periodic";
end
