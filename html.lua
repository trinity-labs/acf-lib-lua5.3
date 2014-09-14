--[[ lowlevel html functions 
     Written for Alpine Configuration Framework (ACF) -- see www.alpinelinux.org
     Copyright (C) 2007  Nathan Angelacos
     Licensed under the terms of GPL2
]]--
local mymodule = {}

--[[ Cookie functions ]]------------------------------------------------------
mymodule.cookie={}

-- Set a cookie - returns a string suitable for setting a cookie
-- if the value is the boolean "false", then set the cookie to expire
mymodule.cookie.set = function ( name, value, path )
	local expires = ""
	if name == nil then
		return ("")
	end
	if value == false then
		expires = 'expires=Thu Jan  1 00:00:00 EST 1970'
		value = ""
	end
	if path == nil then
		path = "/"
	end
	return (string.format('Set-Cookie: %s=%s; path=%s; %s\n', mymodule.html_escape(tostring(name)), 
		mymodule.html_escape(tostring(value)), mymodule.html_escape(path), mymodule.html_escape(expires)))
end


-- wrapper function to clear a cookie
mymodule.cookie.unset = function ( name, path)
	return mymodule.cookie.set (name, false, path)
end



-- escape unsafe html characters
function mymodule.html_escape (text )
	text = text or "" 
	local str = string.gsub (text, "&", "&amp;" )
	str = string.gsub (str, "<", "&lt;" )
	str = string.gsub (str, ">", "&gt;" )
	str = string.gsub (str, "'", "&#39;" )
	return (string.gsub (str, '"', "&quot;" ))
end

-- percent-encode reserved characters according to RFC3986 (except space to '+')
function mymodule.url_encode ( text )
	local str = text or ""
	str = string.gsub (str, "\n", "\r\n")
	str = string.gsub (str, "([^%w ])",
		function (c) return string.format ("%%%02X", string.byte(c)) end)
	str = string.gsub (str, " ", "+")
	return str    
end

--  return a name,value pair as a string.  
local nv_pair = function ( name, value)
	if ( name == nil ) then
		return ( value or "" )
	end
	
	if ( type(value) == "boolean" ) then
		value = tostring(value)
	end
	
	if ( value == nil ) then
		return ( "" )
	else
		return (string.format (' %s="%s" ', mymodule.html_escape(name) , mymodule.html_escape(value) ))
	end
end


local boolean_attribute = function ( name, value )
	if ( name and value ) then
		return name
	else
		return ""
	end
end

--[[
	each of these functions take a table that has an associative array of 
	the values we might care about:

	value -- this is the value in the form element, or the selected element
	name -- this is the name of the element
	cols, rows
	class
	id
	etc.
]]--

local generic_input
generic_input = function ( field_type, v )
	if type(v.value) == "table" then
		ret = {}
		local vals = v.value
		local name = v.name
		for n, val in ipairs(vals) do
			v.value = val
			v.name = name.."."..n
			table.insert(ret, generic_input(field_type, v))
		end
		v.value = vals
		v.name = name
		return table.concat(ret)
	end
	if ( field_type == nil ) then 
		return nil
	end
	
	local str = string.format ( '<input class="%s %s" type="%s" ', mymodule.html_escape(v.class), mymodule.html_escape(field_type), mymodule.html_escape(field_type) )

	for i,k in ipairs ( {
			"name", "size", "checked", "maxlength", 
			"value", "length", "id", "src",
			"align", "alt", "contenteditable",
			"tabindex", "accesskey", "onfocus", "onblur", "title"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end

	for i,k in ipairs ( {
			"readonly", "disabled",  
			} ) do
		str = str .. boolean_attribute ( k, v[k] )
	end

	return ( str .. ">" )
end
	
	
--[[ Form functions ]]------------------------------------------------------
-- These expect something like a cfe to work (see mvc.lua)

mymodule.form = {}
mymodule.form.text = function ( v )
	return generic_input ( "text", v )
end


mymodule.form.longtext = function ( v )
	local str = "<textarea"
	for i,k in ipairs ( {
				"name", "rows", "cols",
				"class", "id", "tabindex", "accesskey", 
				"onfocus", "onblur", "title"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end
	for i,k in ipairs ( {
			"readonly", "disabled",  
			} ) do
		str = str .. boolean_attribute ( k, v[k] )
	end
	str = str .. nv_pair (nil, v.disabled)
	return ( str .. ">" .. mymodule.html_escape(v.value) .. "</textarea>" )
end


function mymodule.form.password ( v )
	return generic_input ( "password", v )
end

function mymodule.form.hidden ( v )
	return generic_input ( "hidden", v )
end


function mymodule.form.submit ( v )
	return generic_input ( "submit", v )
end


function mymodule.form.action (v) 
	return generic_input ("submit", v)
end

function mymodule.form.file ( v )
	-- CFE must contain value, but file cannot have value
	local value = v.value
	v.value = nil
	local retval = generic_input ( "file", v )
	v.value = value
	return retval
end

function mymodule.form.image ( v )
	return generic_input ( "image", v )
end


-- v.value is the selected item (or an array if multiple)
-- v.option is an array of valid options (or an array of value, label)
-- NOTE use of value and values (plural)
function mymodule.form.select ( v )
	if ( v.name == nil ) then 
		return nil 
	end
	local str = "<select"
	for i,k in ipairs ( {
			"name", "size", "tabindex", "accesskey", 
			"onfocus", "onblur", "onchange", "id", 
			"class", "title"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end
	
	for i,k in ipairs ( {
			"disabled", "multiple" 
			} ) do
		str = str .. boolean_attribute ( k, v[k] )
	end

	str = str .. ">"
	-- now the options
	local reverseval = {}
	if type(v.value) == "table" then
		for x,val in ipairs(v.value) do
			reverseval[val]=x
		end
	else
		reverseval[v.value]=1
	end
	for i, k in ipairs ( v.option ) do
		local val, label
		if type(k) == "string" then
			val = k
			label = k
		else
			val = k.value
			label = k.label
		end
		str = str .. "<option "
		if reverseval[val] then
			str = str .. " selected"
			reverseval[val] = nil
		end
		str = str .. nv_pair("value", val) .. ">" .. mymodule.html_escape(label) .. "</option>"
	end
	for val in pairs(reverseval) do
		str = str .. '<option selected value="' .. mymodule.html_escape(val) ..'">[' .. mymodule.html_escape(val) .. ']</option>'
	end
	str = str .. "</select>"
	return (str)
end

function mymodule.form.checkbox ( v )
       	return generic_input ( "checkbox", v )
end


-- NOTE:  VALUE of a form is a table containing the form elements ... 
function mymodule.form.start ( v)
	if ( v.action == nil ) then 
		return nil 
	end
	
	local method = v.method or "get"
	return ( string.format (
			'<form %s%s%s>',
			nv_pair ( "class", mymodule.html_escape(v.class) ), 
			nv_pair ( "method", mymodule.html_escape(v.method) ), 
			nv_pair (	"action", mymodule.html_escape(v.action) )
		) )
end
	
function mymodule.form.stop ( )
	return ("</form>")
end

-- For "h1, h2, p," etc 
-- WARNING - Text is printed verbatim - you may want to
-- wrap the text in mymodule.html_escape
function mymodule.entity (tag, text, class, id)
	return ( string.format (
			"<%s%s%s>%s</%s>",
			mymodule.html_escape(tag),
			nv_pair ("class", class),
			nv_pair("id", id), mymodule.html_escape(text), mymodule.html_escape(tag))
		)
end
	 

function mymodule.link ( v ) 
	if ( v.value == nil ) then
		return nil
	end
	local str = nv_pair ( "href", v.value )
	for i,k in ipairs( { "class", "id" }) do
		str = str .. nv_pair ( k, v[k] )
	end

	return ( "<a " .. str .. ">" .. mymodule.html_escape(v.label) .. "</a>" )
end

return mymodule
