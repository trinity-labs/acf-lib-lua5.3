
module(..., package.seeall)

require("posix")
require("fs")
require("format")
require("apk")

local path = "PATH=/usr/bin:/bin:/usr/sbin:/sbin "

function package_version(packagename)
	local result = apk.version(packagename)
	local errtxt
	if not result then
		errtxt = "Program not installed"
	end
	return result,errtxt
end

function process_autostart(servicename)
	local result
	local errtxt = "Not programmed to autostart"
	local f = io.popen( "/sbin/rc-update show" )
	local cmdresult = f:read("*a") or ""
	f:close()
	for line in string.gmatch(cmdresult, "[^\n]+") do
		if string.match(line, "^%s*"..format.escapemagiccharacters(servicename).."%s+|") then
			local runlevels = string.match(line, "|(.*)")
			-- ignore the shutdown runlevel
			runlevels = string.gsub(runlevels, "%sshutdown%s", " ")
			runlevels = string.gsub(runlevels, "^%s+", "")
			runlevels = string.gsub(runlevels, "%s+$", "")
			if runlevels ~= "" then
				result = "Service will autostart at next boot (at runlevel '" .. runlevels .. "')"
				errtxt = nil
			end
			break
		end
	end	
	return result,errtxt
end

function read_initrunlevels()
	local config = {}
	local f = io.popen( "/sbin/rc-update show -v" )
	local cmdresult = f:read("*a") or ""
	f:close()
	for line in string.gmatch(cmdresult, "([^\n]*)\n?") do
                local service = string.match(line, "^%s*(%S+)")
                local runlevels = string.match(line, "|%s*(%S.*)")
		if service then
			local runlevel = {}
			if runlevels then
				runlevel = format.string_to_table(string.gsub(runlevels, "%s+$", ""), "%s+") or {}
			end
			config[#config+1] = {servicename=service, runlevels=runlevel}
		end
	end
	table.sort(config, function(a,b) return a.servicename < b.servicename end)
	return config
end

function add_runlevels(servicename, runlevels)
	local cmdresult,cmderrors
	if not servicename then
		cmderrors = "Invalid service name"
	else
		if runlevels and #runlevels > 0 then
			local cmd = {path, "rc-update add"}
			cmd[#cmd+1] = format.escapespecialcharacters(servicename)
			for i,lev in ipairs(runlevels) do
				cmd[#cmd+1] = lev
			end
			cmd[#cmd+1] = "2>&1"
			local f = io.popen(table.concat(cmd, " "))
			cmdresult = f:read("*a")
			f:close()
			cmdresult = string.gsub(cmdresult, "\n+$", "")
		else
			cmdresult = "No runlevels added"
		end
	end

	return cmdresult,cmderrors
end

function delete_runlevels(servicename, runlevels)
	local cmdresult,cmderrors
	if not servicename then
		cmderrors = "Invalid service name"
	else
		if runlevels and #runlevels > 0 then
			local cmd = {path, "rc-update del"}
			cmd[#cmd+1] = format.escapespecialcharacters(servicename)
			for i,lev in ipairs(runlevels) do
				cmd[#cmd+1] = lev
			end
			cmd[#cmd+1] = "2>&1"
			local f = io.popen(table.concat(cmd, " "))
			cmdresult = f:read("*a")
			f:close()
			cmdresult = string.gsub(cmdresult, "\n+$", "")
		else
			cmdresult = "No runlevels deleted"
		end
	end

	return cmdresult,cmderrors
end

function daemoncontrol (process, action)

	local cmdresult = ""
	local cmderrors
	if not process then
		cmderrors = "Invalid service name"
	elseif not action then
		cmderrors = "Invalid action"
	else
		local file = io.popen( "PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin /etc/init.d/" .. 
			format.escapespecialcharacters(process) .. " " .. format.escapespecialcharacters(string.lower(action)) .. " 2>&1" )
		if file ~= nil then
			cmdresult = file:read( "*a" )
			file:close()
		end
	end
	return cmdresult,cmderrors
end

-- the following methods are available:
-- /proc/<pid>/stat	the comm field (2nd) field contains name but only up 
--   			to 15 chars. does not resolve links
--
-- /proc/<pid>/cmdline	argv[0] contains the command. However if it is a script
--   			then will the interpreter show up
--
-- /proc/<pid>/exe	link to exe file. this will resolv links
--
-- returns list of all pids for given exe name

--[[
-- gives lots of false positives for busybox
local function is_exe(path, name)
	local f = posix.readlink(path.."/exe")
	if f and (f == name or posix.basename(f) == name) then
		return true
	else
		return false
	end
end
]]--


local function is_stat(path, name)
	local f = io.open(path.."/stat")
	if (f) then
		local line = f:read()
		local p = string.gsub(line, ".*%(", "")
		p = string.gsub(p, "%).*", "")
		f:close()
	end
	if p ~= nil then	
		if string.len(name) <= 15 and p == name then
			return true
		end
	end
	return false
end

local function is_cmdline(path, name)
	local f = io.open(path.."/cmdline")
	if f == nil then
		return false
	end
	local line = f:read()
	f:close()
	if line == nil then 
		return false
	end
	local arg0 = string.gsub(line, string.char(0)..".*", "")
	if posix.basename(arg0) == name then
		return true
	end
end

local function has_pidfile(name)
	local pid
	local file = "/var/run/"..name..".pid"
	if fs.is_file(file) then
		-- check to see if there's a matching proc directory and that it was created slightly after the pid file
		-- this allows us to find init scripts with differing process names and avoids the problem with
		-- proc numbers wrapping
		local tmp = string.match(fs.read_file(file) or "", "%d+")
		if tmp then
			local dir = "/proc/" .. tmp
			filetime = posix.stat(file, "ctime")
			dirtime = posix.stat(dir, "ctime")
			if dirtime and (tonumber(dirtime) - tonumber(filetime) < 100) then
				pid = tmp
			end
		end
	end
	return pid
end

function pidof(name)
	local pids = {has_pidfile(name)}
	local i, j

	for i,j in pairs(posix.glob("/proc/[0-9]*")) do
		local pid = tonumber(posix.basename(j))
		if is_stat(j, name) or is_cmdline(j, name) then
			table.insert(pids, pid)
		end
	end
	if #pids == 0 then
		pids = nil
	end
	return pids
end

