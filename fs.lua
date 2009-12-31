--[[
	module for generic filesystem funcs

	Copyright (c) Natanael Copa 2006
        MM edited to use "posix"
]]--

module (..., package.seeall)

require("posix")
require("format")

-- generic wrapper funcs
function is_dir ( pathstr )
	return posix.stat ( pathstr or "", "type" ) == "directory"
end

function is_file ( pathstr )
	return posix.stat ( pathstr or "", "type" ) == "regular"
end

function is_link ( pathstr )
	return posix.stat ( pathstr or "", "type" ) == "link"
end

-- Creates a directory if it doesn't exist, including the parent dirs
function create_directory ( path )
	local pos = string.find(path, "/")
	while pos do
		posix.mkdir(string.sub(path, 1, pos))
		pos = string.find(path, "/", pos+1)
	end
	posix.mkdir(path)
	return is_dir(path)
end

-- Deletes a directory along with its contents
function remove_directory ( path )
	if fs.is_dir(path) then
		for d in posix.files(path) do
			if (d == ".") or (d == "..") then
				-- ignore
			elseif fs.is_dir(path .. "/" ..  d) then
				remove_directory(path .. "/" ..d)
			else
				os.remove(path .. "/" ..d)
			end
		end
		os.remove(path)
		return true
	end
	return false
end

-- Creates a blank file (and the directory if necessary)
function create_file ( path )
	path = path or ""
	if not posix.stat(posix.dirname(path)) then create_directory(posix.dirname(path)) end
	local f = io.open(path, "w")
	if f then f:close() end
	return is_file(path)
end

-- Copies a file to a directory or new filename (creating the directory if necessary)
-- fails if new file is already a directory (this is different than cp function)
-- if newpath ends in "/", will treat as a directory
function copy_file(oldpath, newpath)
	local use_dir = string.find(newpath or "", "/%s*$")
	if not is_file(oldpath) or not newpath or newpath == "" or (not use_dir and is_dir(newpath)) or (use_dir and is_dir(newpath .. posix.basename(oldpath))) then
		return false
	end
	if use_dir then newpath = newpath .. posix.basename(oldpath) end
	if not posix.stat(posix.dirname(newpath)) then create_directory(posix.dirname(newpath)) end
	local old = io.open(oldpath, "r")
	local new = io.open(newpath, "w")
	new:write(old:read("*a"))
	new:close()
	old:close()
	return is_file(newpath)
end

-- Moves a file to a directory or new filename (creating the directory if necessary)
-- fails if new file is already a directory (this is different than mv function)
-- if newpath ends in "/", will treat as a directory
function move_file(oldpath, newpath)
	local use_dir = string.find(newpath or "", "/%s*$")
	if not is_file(oldpath) or not newpath or newpath == "" or (not use_dir and is_dir(newpath)) or (use_dir and is_dir(newpath .. posix.basename(oldpath))) then
		return false
	end
	if use_dir then newpath = newpath .. posix.basename(oldpath) end
	if not posix.stat(posix.dirname(newpath)) then create_directory(posix.dirname(newpath)) end
	local status, errstr, errno = os.rename(oldpath, newpath)
        -- errno 18 means  Invalid cross-device link
	if status or errno ~= 18 then
		-- successful move or failure due to something else
		return (status ~= nil), errstr, errno
	else
		status = copy_file(oldpath, newpath)
		if status then
			os.remove(oldpath)
		end
		return status
	end
end

-- Returns the contents of a file as a string
function read_file ( path )
	local file = io.open(path or "")
	if ( file ) then
		local f = file:read("*a")
		file:close()
		return f
	else
		return nil
	end
end

-- Returns an array with the contents of a file, 
-- or nil and the error message
function read_file_as_array ( path )
	local file, error = io.open(path or "")
	if ( file == nil ) then
		return nil, error
	end
	local f = {}
	for line in file:lines() do 
		table.insert ( f , line )
		--sometimes you will see it like f[#f+1] = line
	end
	file:close()
	return f
end
	
-- write a string to a file, will replace file contents
function write_file ( path, str )
	path = path or ""
	if not posix.stat(posix.dirname(path)) then create_directory(posix.dirname(path)) end
	local file = io.open(path, "w")
	--append a newline char to EOF
	str = string.gsub(str or "", "\n*$", "\n")
	if ( file ) then
		file:write(str)
		file:close()
	end
end

-- this could do more than a line. This will append
-- fs.write_line_file ("filename", "Line1 \nLines2 \nLines3")
function write_line_file ( path, str )
	path = path or ""
	if not posix.stat(posix.dirname(path)) then create_directory(posix.dirname(path)) end
	local file = io.open(path)
	if ( file) then
		local c = file:read("*a") or ""
		file:close()
		fs.write_file(path, c .. (str or ""))
	end
end

-- returns an array of files under "where" that match "what" (a Lua pattern)
function find_files_as_array ( what, where, follow, t )
	where = where or posix.getcwd()
	what = what or ".*"
	t =  t or {}
	
	local link
	if follow and fs.is_link(where) then
		link = posix.readlink(where)
		if not string.find(link, "^/") then
			link = posix.dirname(where).."/"..link
		end
	end

	if fs.is_dir(where) or (link and fs.is_dir(link)) then
		for d in posix.files ( where ) do
			if (d == ".") or ( d == "..") then
				-- do nothing
			elseif fs.is_dir ( where .. "/" ..  d ) then
				find_files_as_array (what, where .. "/" .. d, follow, t )
			elseif follow and fs.is_link ( where .. "/" ..  d ) then
				find_files_as_array (what, where .. "/" .. d, follow, t )
			elseif (string.match (d, "^" .. what .. "$" ))  then
				table.insert (t, ( string.gsub ( where .. "/" .. d, "/+", "/" ) ) )
			end
		end
	elseif (string.match (posix.basename(where), "^" .. what .. "$" )) and posix.stat(where) then
		table.insert (t, where )
	end

	return (t)
end

-- iterator function for finding dir entries matching (what) (a Lua pattern)
-- starting at where, or currentdir if not specified.
function find ( what, where, follow )
	local t = find_files_as_array ( what, where, follow )
	local idx = 0
	return function () 
		idx = idx + 1
		return t[idx]
	end
end

-- This function does almost the same as posix.stat, but instead it writes the output human readable.
function stat ( path )
	local filedetails = posix.stat(path or "")
	if (filedetails) then
		filedetails["ctime"]=os.date("%c", filedetails["ctime"])
		filedetails["mtime"]=os.date("%c", filedetails["mtime"])
		filedetails["path"]=path
		if ( filedetails["size"] > 1073741824 ) then
			filedetails["size"]=((filedetails["size"]/1073741824) - (filedetails["size"]/1073741824%0.1)) .. "G"
		elseif ( filedetails["size"] > 1048576 ) then
			filedetails["size"]=((filedetails["size"]/1048576) - (filedetails["size"]/1048576%0.1))  .. "M"
		elseif ( filedetails["size"] > 1024 ) then
			filedetails["size"]=((filedetails["size"]/1024) - (filedetails["size"]/1024%0.1)) .. "k"
		else
			filedetails["size"]=filedetails["size"]
		end
	end
	return filedetails
end
