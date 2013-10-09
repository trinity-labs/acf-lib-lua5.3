-- apk library
module (..., package.seeall)

subprocess = require("subprocess")

delete = function(package)
	local success = false
	local code, cmdresult = subprocess.call_capture({"apk", "del", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^OK") then
		cmdresult = "ERROR: Package not found\n"..cmdresult
	elseif not string.find(cmdresult, "ERROR") then
		success = true
	end
	return success, cmdresult
end

install = function(package)
	local success = true
	local code, cmdresult = subprocess.call_capture({"apk", "add", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^ERROR") then
		success = false
	end
	return success, cmdresult
end

version = function(package)
	local code, cmdresult = subprocess.call_capture({"apk", "info", "-ve", package, stderr=subprocess.STDOUT})
	if string.find(cmdresult, "^%s*$") then
		cmdresult = nil
	end
	return cmdresult
end
