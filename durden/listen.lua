-- helpers for managing new connection points
-- requires: timer.lua, suppl.lua
-- logs: CONNECTION

local log, fmt = suppl_add_logfn("connection");
local cps = {}
local listen

-- timer trigger, will re-set a new fire-once timer or
-- re-open the listening end-point
local function retry_reopen(ctx)
	local sleep = ctx.sleep
	local force_sleep = false

	if valid_vid(ctx.vid) then
		log("already_listening:name=" .. ctx.name)
		return
	end

-- this ensures at least n ticks between each connection on the point
-- outside the grace-window at startup
	if CLOCK - ctx.last < sleep and CLOCK - ctx.start > ctx.grace then
		sleep = (sleep + 1) - (CLOCK - ctx.last)
		force_sleep = true
	end

-- the 'eval' is the caller defined limit, the failed listen() is running out
-- of VIDs or (possible) the connection point being blocked
	if force_sleep or not ctx.eval() or not listen(ctx.name, ctx) then
		log(fmt("sleep=%d", sleep))
		ctx.timer = "ext_respawn_" .. ctx.name
		timer_add_periodic(ctx.name, sleep, true,
			function()
				log(fmt("timer"))
				retry_reopen(ctx)
			end, true
		)
		return
	end

	ctx.timer = nil
end

function listen_cancel(name)
	log(fmt("stop_listen=%s", name))
	if not cps[name] then
		return
	end

	if valid_vid(cps[name].vid) then
		delete_image(cps[name].vid)
	end

	if cps.timer then
		timer_delete(cps.timer)
		cps.timer = nil
	end

	cps[name] = nil
end

listen = function(name, dst)
	local cp = target_alloc(name,
		function(source, status, ...)
				dst.last = CLOCK

-- the odd case where the connection is initiated, but the client dies
-- before the connection is authenticated
			if status.kind == "terminated" then
				log(fmt("client_died=%s", name))
				delete_image(source)
				dst.vid = nil
				retry_reopen(dst)

-- we are not needed anymore, update the handler,
-- forward the connection point and re-spawn if it is time
			elseif status.kind == "connected" then
				log(fmt("connected=%s", name))
				target_updatehandler(source, handler)
				dst.vid = nil
				retry_reopen(dst)
				return dst.handler(source, status, ...);

-- none of this should happen
			else
				log(fmt("unexpected_event=%s", status.kind))
				delete_image(source)
			end
		end
	)

-- this can fail if we hit the vid ceiling
	if valid_vid(cp) then
		log(fmt("listen=%s", name))
		dst.vid = cp
		return true
	else
		log(fmt("listen_fail=%s:reason=no_vid", name))
		return false
	end
end

-- [name]    of the connection point to use
-- [eval]    function that returns a boolean if permitted now
--           (used with secondary resources such as #open windows)
-- [handler] function to forward new connections through
--
-- [grace]   number of ticks before time-based limit kicks in, set to
--           > 0 to allow an initial 'reconnect storm' from crash recovery
-- [sleep]   number of ticks between each attempt to re-open
--
-- if [name] is already in use by an existing connection point
--
function listen_ratelimit(name, eval, handler, grace, sleep)
	log(fmt("new_ratelimit:name=%s:grace_period=%d:retry_sleep=%d", name, grace, sleep))
	listen_cancel(name)

	local dst = {
		start = CLOCK,
		sleep = sleep,
		last  = 0,
		grace = grace,
		eval  = eval,
		handler = handler,
		name = name
	}

	cps[name] = dst
	retry_reopen(dst)
end
