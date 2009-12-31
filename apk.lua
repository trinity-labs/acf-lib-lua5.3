-- apk library
module (..., package.seeall)

local path = "PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin "

delete = function(package)
	local success = false
	local cmdresult
	local cmd = path .. "apk del " .. package .. " 2>&1"
	local f = io.popen( cmd )
	cmdresult = f:read("*a") or ""
	f:close()
	if string.find(cmdresult, "^OK") then
		cmdresult = "ERROR: Package not found\n"..cmdresult
	elseif not string.find(cmdresult, "ERROR") then
		success = true
	end
	return success, cmdresult
end

install = function(package)
	local success = true
	local cmdresult
	local cmd = path .. "apk add " .. package .. " 2>&1"
	local f = io.popen( cmd )
	cmdresult = f:read("*a")
	f:close()
	if string.find(cmdresult, "^ERROR") then
		success = false
	end
	return success, cmdresult
end

version = function(package)
	local cmdresult
	local cmd = path .. "apk info -ve " .. package .. " 2>&1"
	local f = io.popen( cmd )
	cmdresult = f:read("*a")
	f:close()
	if string.find(cmdresult, "^%s*$") then
		cmdresult = nil
	end
	return cmdresult
end
