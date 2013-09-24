module(..., package.seeall)

-- ################################################################################
-- PRIVATE DATABASE FUNCTIONS

local function assert (v, m)
	if not v then
		m = m or "Assertion failed!"
		error(m, 0)
	end
	return v, m
end

-- Escape special characters in sql statements
local escape = function(dbobject, sql)
	sql = sql or ""
	return dbobject.con:escape(sql)
end

local databaseconnect = function(dbobject)
	if not dbobject.con then
		-- create environment object
		if dbobject.engine == engine.postgresql then
			require("luasql.postgres")
			dbobject.env = assert (luasql.postgres())
		else
			error("Unknown database engine "..tostring(dbobject.engine))
		end

		-- connect to data source
		dbobject.con = assert(dbobject.env:connect(dbobject.name, dbobject.user, dbobject.password, dbobject.host, dbobject.port))
		return true
	end
	return false
end

local databasedisconnect = function(dbobject)
	if dbobject.env then
		dbobject.env:close()
		dbobject.env = nil
	end
	if dbobject.con then
		dbobject.con:close()
		dbobject.con = nil
	end
end

local runscript = function(dbobject, script, transaction)
	for i,scr in ipairs(script) do
		dbobject.runsqlcommand(scr, transaction)
	end
end

local runsqlcommand = function(dbobject, sql, transaction)
	if transaction then assert(dbobject.con:execute("SAVEPOINT before_command")) end
        local res, err = dbobject.con:execute(sql)
	if not res and err then
		-- Catch the error to see if it's caused by lack of table
		local table = string.match(err, "relation \"(%S+)\" does not exist")
		if table and dbobject.table_creation_scripts[table] then
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

local getselectresponse = function(dbobject, sql, transaction)
	local retval = {}
	if transaction then assert(dbobject.con:execute("SAVEPOINT before_select")) end
        local res, err = pcall(function()
		local cur = assert (dbobject.con:execute(sql))
		local row = cur:fetch ({}, "a")
		while row do
			local tmp = {}
			for name,val in pairs(row) do
				tmp[name] = val
			end
			retval[#retval + 1] = tmp
			row = cur:fetch (row, "a")
		end
		cur:close()
	end)
	if not res and err then
		-- Catch the error to see if it's caused by lack of table
		local table = string.match(err, "relation \"(%S+)\" does not exist")
		if table and dbobject.table_creation_scripts[table] then
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

local listtables = function(dbobject)
	local result = {}
	if dbobject.engine == engine.postgresql then
		local tab = dbobject.getselectresponse("SELECT tablename FROM pg_tables WHERE tablename !~* 'pg_*' ORDER BY tablename ASC")
		for i,t in ipairs(tab) do
			result[#result+1] = t.tablename
		end
	else
		-- untested
		result = dbobject.con:tables()
	end
	return result
end

local listcolumns = function(dbobject, table)
	local result = {}
	if dbobject.engine == engine.postgresql then
		local col = dbobject.getselectresponse("SELECT a.attname AS field FROM pg_class c, pg_attribute a, pg_type t WHERE c.relname = '"..escape(dbobject, table).."' AND a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum")
		for i,c in ipairs(col) do
			result[#result+1] = c.field
		end
	end
	return result
end

-- ################################################################################
-- PUBLIC FUNCTIONS / DEFINITIONS

engine = {
["postgresql"] = 1,
}

create = function(engine, name, user, password, host, port)
	local dbobject = {engine=engine, name=name, user=user, password=password, host=host, port=port}
	dbobject.escape = function(...) return escape(dbobject, ...) end
	dbobject.databaseconnect = function(...) return databaseconnect(dbobject, ...) end
	dbobject.databasedisconnect = function(...) return databasedisconnect(dbobject, ...) end
	dbobject.runscript = function(...) return runscript(dbobject, ...) end
	dbobject.runsqlcommand = function(...) return runsqlcommand(dbobject, ...) end
	dbobject.getselectresponse = function(...) return getselectresponse(dbobject, ...) end
	dbobject.listtables = function(...) return listtables(dbobject, ...) end
	dbobject.listcolumns = function(...) return listcolumns(dbobject, ...) end
	dbobject.isconnected = function() return dbobject.con ~= nil end
	dbobject.table_creation_scripts = {}
	return dbobject
end
