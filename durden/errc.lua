-- Copyright 2015, Björn Ståhl
-- License: 3-Clause BSD
-- References: http://durden.arcan-fe.com
-- Description:
-- Indirection table for future internationalization, errcodes
-- are added here in an 'english' default, switching active language
-- should only impose something like ERRNO = system_load("errc.fr.lua").
--

local ret = {};
ret["BROKEN_TERMINAL"] = "terminal support missing or broken";

return ret;
