local mymodule = {}

subprocess = require("subprocess")

local function assert (v, m)
	if not v then
		m = m or "Assertion failed!"
		error(m, 0)
	end
	return v, m
end

-- ################################################################################
-- PRIVATE DATABASE FUNCTIONS TO BE EXPORTED FOR EACH OBJECT

local export = {}

-- Escape special characters in sql statements
export.escape = function(dbobject, sql)
	sql = sql or ""
	return dbobject.con:escape(sql)
end

export.databaseconnect = function(dbobject)
	if not dbobject.con then
		-- create environment object
		if dbobject.engine == mymodule.engine.postgresql then
			luasql = require("luasql.postgres")
			dbobject.env = assert (luasql.postgres())
		elseif dbobject.engine == mymodule.engine.mysql then
			luasql = require("luasql.mysql")
			dbobject.env = assert (luasql.mysql())
		elseif dbobject.engine == mymodule.engine.sqlite3 then
			luasql = require("luasql.sqlite3")
			dbobject.env = assert (luasql.sqlite3())
		else
			error("Unknown database engine "..tostring(dbobject.engine))
		end

		-- connect to data source
		dbobject.con = assert(dbobject.env:connect(dbobject.database, dbobject.user, dbobject.password, dbobject.host, dbobject.port))
		return true
	end
	return false
end

export.databasedisconnect = function(dbobject)
	if dbobject.env then
		dbobject.env:close()
		dbobject.env = nil
	end
	if dbobject.con then
		dbobject.con:close()
		dbobject.con = nil
	end
end

export.isconnected = function(dbobject)
	return (dbobject.con ~= nil)
end

export.runscript = function(dbobject, script, transaction)
	for i,scr in ipairs(script) do
		dbobject.runsqlcommand(scr, transaction)
	end
end

export.runsqlcommand = function(dbobject, sql, transaction)
	if transaction then assert(dbobject.con:execute("SAVEPOINT before_command")) end
        local res, err = dbobject.con:execute(sql)
	if not res and err then
		-- Catch the error to see if it's caused by lack of table
		local table
		if dbobject.engine == mymodule.engine.postgresql then
			table = string.match(err, "relation \"(%S+)\" does not exist")
		elseif dbobject.engine == mymodule.engine.mysql then
			table = string.match(err, "Table '[^.]*%.(%S+)' doesn't exist")
		elseif dbobject.engine == mymodule.engine.sqlite3 then
			table = string.match(err, "LuaSQL: no such table: (%S+)")
		end
		if table and dbobject.table_creation_scripts and dbobject.table_creation_scripts[table] then
			if transaction then assert(dbobject.con:execute("ROLLBACK TO before_command")) end
			dbobject.runscript(dbobject.table_creation_scripts[table])
			dbobject.runsqlcommand(sql)
		else
			assert(res, err)
		end
	else
		if transaction then
			assert(dbobject.con:execute("RELEASE SAVEPOINT before_command"))
		end
		if type(res) == userdata then
			res:close()
		end
	end
end

export.getselectresponse = function(dbobject, sql, transaction)
	local retval = {}
	if transaction then assert(dbobject.con:execute("SAVEPOINT before_select")) end
        local res, err = pcall(function()
		local cur = assert (dbobject.con:execute(sql))
		local row
		if type(cur) == "userdata" then
			row = cur:fetch ({}, "a")
		end
		while row do
			local tmp = {}
			for name,val in pairs(row) do
				tmp[name] = val
			end
			retval[#retval + 1] = tmp
			row = cur:fetch (row, "a")
		end
		if type(cur) == "userdata" then
			cur:close()
		end
	end)
	if not res and err then
		-- Catch the error to see if it's caused by lack of table
		local table
		if dbobject.engine == mymodule.engine.postgresql then
			table = string.match(err, "relation \"(%S+)\" does not exist")
		elseif dbobject.engine == mymodule.engine.mysql then
			table = string.match(err, "Table '[^.]*%.(%S+)' doesn't exist")
		elseif dbobject.engine == mymodule.engine.sqlite3 then
			table = string.match(err, "LuaSQL: no such table: (%S+)")
		end
		if table and dbobject.table_creation_scripts and dbobject.table_creation_scripts[table] then
			if transaction then assert(con:execute("ROLLBACK TO before_select")) end
			dbobject.runscript(dbobject.table_creation_scripts[table])
			return dbobject.getselectresponse(sql)
		else
			assert(res, err)
		end
	elseif transaction then
		assert(dbobject.con:execute("RELEASE SAVEPOINT before_select"))
	end
	return retval
end

export.listtables = function(dbobject)
	local result = {}
	if dbobject.engine == mymodule.engine.postgresql then
		local tab = dbobject.getselectresponse("SELECT tablename FROM pg_tables WHERE tablename !~* 'pg_*' AND schemaname = 'public' ORDER BY tablename ASC")
		for i,t in ipairs(tab) do
			result[#result+1] = t.tablename
		end
	elseif dbobject.engine == mymodule.engine.sqlite3 then
		local tab = dbobject.getselectresponse("SELECT name FROM sqlite_master WHERE type = 'table'")
		for i,t in ipairs(tab) do
			result[#result+1] = t.name
		end
	else
		local tab = dbobject.getselectresponse("SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '"..dbobject.escape(dbobject.database).."'")
		for i,t in ipairs(tab) do
			result[#result+1] = t.table_name
		end
	end
	return result
end

export.getcolumndata = function(dbobject, table)
	local columns = {}
	-- There is no good way to get default values from pg_attribute, so may as well use information_schema
	local foundkey = false
	if dbobject.engine == mymodule.engine.postgresql then
		local key = dbobject.getselectresponse("SELECT pg_attribute.attname AS field FROM pg_index, pg_class, pg_attribute WHERE pg_class.oid = '"..dbobject.escape(table).."'::regclass AND indrelid = pg_class.oid AND pg_attribute.attrelid = pg_class.oid AND pg_attribute.attnum = any(pg_index.indkey) AND indisprimary")
		local reversekeys = {}
		if nil ~= next(key) then
			for i,k in ipairs(key) do
				reversekeys[k.field] = true
			end
		end
		local col = dbobject.getselectresponse("SELECT column_name, column_default, is_nullable, data_type FROM information_schema.columns WHERE table_name = '"..dbobject.escape(table).."' AND table_schema = 'public' ORDER BY ordinal_position")
		for i,c in ipairs(col) do
			columns[#columns+1] = {name=c.column_name, default=c.column_default, nullable=(c.is_nullable == "YES"), type=c.data_type, key=(reversekeys[c.column_name] == true)}
			if columns[#columns].key then foundkey = true end
		end
	elseif dbobject.engine == mymodule.engine.sqlite3 then
		local col = dbobject.getselectresponse("pragma table_info("..dbobject.escape(table)..")")
		for i,c in ipairs(col) do
			columns[#columns+1] = {name=c.name, default=c.dflt_value, nullable=(c.notnull ~= 1), type=c.type, key=(c.pk == 1)}
			if columns[#columns].key then foundkey = true end
		end
	else
		-- column_key is a mysql extension to information_schema.columns
		local col = dbobject.getselectresponse("SELECT column_name, column_default, is_nullable, data_type, column_key FROM information_schema.columns WHERE table_name = '"..dbobject.escape(table).."' AND table_schema = '"..dbobject.escape(dbobject.database).."' ORDER BY ordinal_position")
		for i,c in ipairs(col) do
			columns[#columns+1] = {name=c.column_name, default=c.column_default, nullable=(c.is_nullable == "YES"), type=c.data_type, key=(c.column_key == "PRI")}
			if columns[#columns].key then foundkey = true end
		end
	end
	if not foundkey then
		for i,c in ipairs(columns) do
			c.key = true
		end
	end

	return columns
end

export.listcolumns = function(dbobject, table)
	local columns = {}
	local defaults = {}
	local nullable = {}
	local data_type = {}
	-- There is no good way to get default values from pg_attribute, so may as well use information_schema
--	if dbobject.engine == mymodule.engine.postgresql then
--		local col = dbobject.getselectresponse("SELECT a.attname AS field, a.attnotnull FROM pg_class c, pg_attribute a, pg_type t WHERE c.relname = '"..dbobject.escape(table).."' AND a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum")
	if dbobject.engine == mymodule.engine.sqlite3 then
		local col = dbobject.getselectresponse("pragma table_info("..dbobject.escape(table)..")")
		for i,c in ipairs(col) do
			columns[#columns+1] = c.name
			defaults[c.name] = c.dflt_value
			nullable[c.name] = c.notnull ~= 1
			data_type[c.name] = c.type
		end
	else
		local col
		if dbobject.engine == mymodule.engine.postgresql then
			col = dbobject.getselectresponse("SELECT column_name, column_default, is_nullable, data_type FROM information_schema.columns WHERE table_name = '"..dbobject.escape(table).."' AND table_schema = 'public' ORDER BY ordinal_position")
		else
			col = dbobject.getselectresponse("SELECT column_name, column_default, is_nullable, data_type FROM information_schema.columns WHERE table_name = '"..dbobject.escape(table).."' AND table_schema = '"..dbobject.escape(dbobject.database).."' ORDER BY ordinal_position")
		end
		for i,c in ipairs(col) do
			columns[#columns+1] = c.column_name
			defaults[c.column_name] = c.column_default
			nullable[c.column_name] = c.is_nullable == "YES"
			data_type[c.column_name] = c.data_type
		end
	end

	return columns, defaults, nullable, data_type
end

export.listkeycolumns = function(dbobject, table)
	local result = {}
	if dbobject.engine == mymodule.engine.postgresql then
		local col = dbobject.getselectresponse("SELECT pg_attribute.attname AS field FROM pg_index, pg_class, pg_attribute WHERE pg_class.oid = '"..dbobject.escape(table).."'::regclass AND indrelid = pg_class.oid AND pg_attribute.attrelid = pg_class.oid AND pg_attribute.attnum = any(pg_index.indkey) AND indisprimary")
		if nil == next(col) then
			result = export.listcolumns(dbobject, table)
		else
			for i,c in ipairs(col) do
				result[#result+1] = c.field
			end
		end
	elseif dbobject.engine == mymodule.engine.sqlite3 then
		local col = dbobject.getselectresponse("pragma table_info("..dbobject.escape(table)..")")
		for i,c in ipairs(col) do
			if c.pk == 1 then
				result[#result+1] = c.name
			end
		end
		if #result == 0 then
			for i,c in ipairs(col) do
				result[#result+1] = c.name
			end
		end
	elseif dbobject.engine == mymodule.engine.mysql then
		-- column_key is a mysql extension to information_schema.columns
		local col = dbobject.getselectresponse("SELECT column_name, column_key FROM information_schema.columns WHERE table_name = '"..dbobject.escape(table).."' AND table_schema = '"..dbobject.escape(dbobject.database).."' ORDER BY ordinal_position")
		for i,c in ipairs(col) do
			if c.column_key == "PRI" then
				result[#result+1] = c.column_name
			end
		end
	end
	return result
end

export.listdatabases = function(dbobject)
	local result = {}
	if dbobject.engine == mymodule.engine.postgresql then
		local cmd = {"psql", "-lt", "-U"}
		local stdin
		if dbobject.user and dbobject.user ~= "" then
			cmd[#cmd+1] = dbobject.user
		else
			cmd[#cmd+1] = "postgres"
		end
		if dbobject.password and dbobject.password ~= "" then
			-- Have never seen a need to use password
		end
		if dbobject.host and dbobject.host ~= "" then
			cmd[#cmd+1] = "-h"
			cmd[#cmd+1] = dbobject.host
		end
		if dbobject.port and dbobject.port ~= "" then
			cmd[#cmd+1] = "-p"
			cmd[#cmd+1] = dbobject.port
		end
		cmd["stderr"]=subprocess.STDOUT
		local code, cmdresult = subprocess.call_capture(cmd)
		if code ~= 0 then
			error(cmdresult, 0)
		end
		for line in string.gmatch(cmdresult or "", "[^\n]+") do
			local table = string.match(line, "%s*([^ |]*)")
			if table and table ~= "" then
				result[#result+1] = table
			end
		end
	elseif dbobject.engine == mymodule.engine.mysql then
		local cmd = {"mysql", "-Bse",  "show databases", "-u"}
		if dbobject.user and dbobject.user ~= "" then
			cmd[#cmd+1] = dbobject.user
		else
			cmd[#cmd+1] = "root"
		end
		if dbobject.password and dbobject.password ~= "" then
			cmd[#cmd+1] = "-p"..dbobject.password
		end
		if dbobject.host and dbobject.host ~= "" then
			cmd[#cmd+1] = "-h"
			cmd[#cmd+1] = dbobject.host
		end
		if dbobject.port and dbobject.port ~= "" then
			cmd[#cmd+1] = "-P"
			cmd[#cmd+1] = dbobject.port
		end
		cmd["stderr"]=subprocess.STDOUT
		local code, cmdresult = subprocess.call_capture(cmd)
		if code ~= 0 then
			error(cmdresult, 0)
		end
		for line in string.gmatch(cmdresult or "", "[^\n]+") do
			local table = string.match(line, "%s*([^ |]*)")
			if table and table ~= "" then
				result[#result+1] = table
			end
		end
	elseif dbobject.engine == mymodule.engine.sqlite3 then
	else
		error("Invalid database engine", 0)
	end
	return result
end

-- ################################################################################
-- PUBLIC FUNCTIONS / DEFINITIONS

mymodule.engine = {
["postgresql"] = 1,
["mysql"] = 2,
["sqlite3"] = 3,
}

mymodule.create = function(engine, database, user, password, host, port)
	local dbobject = {engine=engine, database=database, user=user, password=password, host=host, port=port}
	for n,f in pairs(export) do
		dbobject[n] = function(...) return f(dbobject, ...) end
	end
	return dbobject
end

return mymodule
