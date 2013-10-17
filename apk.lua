-- apk library
local mymodule = {}

mymodule.subprocess = require("subprocess")

mymodule.delete = function(package)
	local success = false
	local code, cmdresult = subprocess.call_capture({"apk", "del", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^OK") then
		cmdresult = "ERROR: Package not found\n"..cmdresult
	elseif not string.find(cmdresult, "ERROR") then
		success = true
	end
	return success, cmdresult
end

mymodule.install = function(package)
	local success = true
	local code, cmdresult = subprocess.call_capture({"apk", "add", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^ERROR") then
		success = false
	end
	return success, cmdresult
end

mymodule.version = function(package)
	local code, cmdresult = subprocess.call_capture({"apk", "info", "-ve", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^%s*$") then
		cmdresult = nil
	end
	return cmdresult
end

return mymodule
