
local mymodule = {}

posix = require("posix")
fs = require("acf.fs")
format = require("acf.format")
apk = require("acf.apk")
subprocess = require("subprocess")

function mymodule.package_version(packagename)
	local result = apk.version(packagename)
	local errtxt
	if not result then
		errtxt = "Program not installed"
	end
	return result,errtxt
end

function mymodule.process_autostart(servicename)
	local result
	local errtxt = "Not programmed to autostart"
	local code, cmdresult = subprocess.call_capture({"rc-update", "show"})
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

function mymodule.read_initrunlevels()
	local config = {}
	local code, cmdresult = subprocess.call_capture({"rc-update", "show", "-v"})
	for line in string.gmatch(cmdresult, "([^\n]*)\n?") do
		local service = string.match(line, "^%s*(%S+)")
		local runlevels = string.match(line, "|%s*(%S.*)")
		if service and service ~= "rcK" and service ~= "rcL" and service ~= "rcS" then
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

function mymodule.add_runlevels(servicename, runlevels)
	local cmdresult,cmderrors
	if not servicename then
		cmderrors = "Invalid service name"
	else
		if runlevels and #runlevels > 0 then
			local cmd = {"rc-update", "add"}
			cmd[#cmd+1] = servicename
			for i,lev in ipairs(runlevels) do
				cmd[#cmd+1] = lev
			end
			cmd.stderr = subprocess.STDOUT
			local code
			code, cmdresult = subprocess.call_capture(cmd)
			cmdresult = string.gsub(cmdresult, "\n+$", "")
		else
			cmdresult = "No runlevels added"
		end
	end

	return cmdresult,cmderrors
end

function mymodule.delete_runlevels(servicename, runlevels)
	local cmdresult,cmderrors
	if not servicename then
		cmderrors = "Invalid service name"
	else
		if runlevels and #runlevels > 0 then
			local cmd = {"rc-update", "del"}
			cmd[#cmd+1] = servicename
			for i,lev in ipairs(runlevels) do
				cmd[#cmd+1] = lev
			end
			cmd.stderr = subprocess.STDOUT
			local code
			code, cmdresult = subprocess.call_capture(cmd)
			cmdresult = string.gsub(cmdresult, "\n+$", "")
		else
			cmdresult = "No runlevels deleted"
		end
	end

	return cmdresult,cmderrors
end

function mymodule.daemoncontrol (process, action)
	local cmdresult
	local cmderrors
	if not process then
		cmderrors = "Invalid service name"
	elseif not action then
		cmderrors = "Invalid action"
	else
		local res, err = pcall(function()
			local code
			code, cmdresult = subprocess.call_capture({"/etc/init.d/" .. process, string.lower(action), stderr=subprocess.STDOUT})
		end)
		if not res or err then
			cmderrors = err
		end
	end
	return cmdresult,cmderrors
end

function mymodule.daemon_actions (process)
	local actions = {"status", "start", "stop", "restart", "describe", "zap"}
	local reverse = {}
	for i,a in ipairs(actions) do
		reverse[a] = i
	end
	local description
	local res, err = mymodule.daemoncontrol(process, "describe")
	if err then
		return nil, err
	else
		lines = format.string_to_table(res, "\n")
		-- Description is last line before first action
		-- Actions are of the form " * action: description"
		local found = false
		for i,l in ipairs(lines) do
			local line = string.gsub(l, "^%s*%*%s*", "")
			if string.find(line, "^%S*:") then
				found = true
				local act = string.match(line, "^([^:]*)")
				if act and not reverse[act] then
					actions[#actions+1] = act
					reverse[act] = #actions
				end
			elseif not found then
				description = line
			end
		end
	end
	return actions, description
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

function mymodule.pidof(name)
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

return mymodule
