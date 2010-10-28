--[[ lowlevel html functions 
     Written for Alpine Configuration Framework (ACF) -- see www.alpinelinux.org
     Copyright (C) 2007  Nathan Angelacos
     Licensed under the terms of GPL2
]]--
module (..., package.seeall)

--[[ Cookie functions ]]------------------------------------------------------
cookie={}

-- Set a cookie - returns a string suitable for setting a cookie
-- if the value is the boolean "false", then set the cookie to expire
cookie.set = function ( name, value, path )
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
	return (string.format('Set-Cookie: %s=%s; path=%s; %s\n', html_escape(tostring(name)), 
		html_escape(tostring(value)), html_escape(path), html_escape(expires)))
end


-- wrapper function to clear a cookie
cookie.unset = function ( name, path)
	return cookie.set (name, false, path)
end



-- escape unsafe html characters
function html_escape (text )
	text = text or "" 
	local str = string.gsub (text, "&", "&amp;" )
	str = string.gsub (str, "<", "&lt;" )
	str = string.gsub (str, ">", "&gt;" )
	str = string.gsub (str, "'", "&#39;" )
	return (string.gsub (str, '"', "&quot;" ))
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
		return (string.format (' %s="%s" ', html_escape(name) , html_escape(value) ))
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

local generic_input = function ( field_type, v )
	if type(v.value) == "table" then
		ret = {}
		local vals = v.value
		for n, val in ipairs(vals) do
			v.value = val
			table.insert(ret, generic_input(field_type, v))
		end
		v.value = vals
		return table.concat(ret)
	end
	if ( field_type == nil ) then 
		return nil
	end
	
	local str = string.format ( '<input class="%s" type="%s" ', html_escape(field_type), html_escape(field_type) )

	for i,k in ipairs ( {
			"name", "size", "checked", "maxlength", 
			"value", "length",   "class", "id", "src",
			"align", "alt", "contenteditable", "readonly", 
			"tabindex", "accesskey", "onfocus", "onblur"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end

	if ( v.disabled ~= nil ) then 
		str = str .. " disabled"
	end

	return ( str .. ">" )
end
	
	
--[[ Form functions ]]------------------------------------------------------
-- These expect something like a cfe to work (see mvc.lua)

form = {}
form.text = function ( v )
	return generic_input ( "text", v )
end


form.longtext = function ( v )
	local str = "<textarea"
	for i,k in ipairs ( {
				"name", "rows", "cols",
				"class", "id", "tabindex", "accesskey", 
				"onfocus", "onblur", "readonly"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end
	str = str .. nv_pair (nil, v.disabled)
	return ( str .. ">" .. html_escape(v.value) .. "</textarea>" )
end


function form.password ( v )
	return generic_input ( "password", v )
end

function form.hidden ( v )
	return generic_input ( "hidden", v )
end


function form.submit ( v )
	return generic_input ( "submit", v )
end


function form.action (v) 
	return generic_input ("submit", v)
end

function form.file ( v )
	return generic_input ( "file", v )
end

function form.image ( v )
	return generic_input ( "image", v )
end


-- v.value is the selected item (or an array if multiple)
-- v.option is an array of valid options (or an array of value, label)
-- NOTE use of value and values (plural)
function form.select ( v )
	if ( v.name == nil ) then 
		return nil 
	end
	local str = "<select"
	for i,k in ipairs ( {
			"name", "size", "tabindex", "accesskey", 
			"onfocus", "onblur", "onchange", "id", 
			"class", "multiple"
			} ) do
		str = str .. nv_pair ( k, v[k] )
	end
	
	if ( v.disabled ~= nil ) then
		str = str .. " disabled"
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
		str = str .. nv_pair("value", val) .. ">" .. html_escape(label) .. "</option>"
	end
	for val in pairs(reverseval) do
		str = str .. '<option selected value="' .. html_escape(val) ..'">[' .. html_escape(val) .. ']</option>'
	end
	str = str .. "</select>"
	return (str)
end

function form.checkbox ( v )
       	return generic_input ( "checkbox", v )
end


-- NOTE:  VALUE of a form is a table containing the form elements ... 
function form.start ( v)
	if ( v.action == nil ) then 
		return nil 
	end
	
	local method = v.method or "get"
	return ( string.format (
			'<form %s%s%s>',
			nv_pair ( "class", html_escape(v.class) ), 
			nv_pair ( "method", html_escape(v.method) ), 
			nv_pair (	"action", html_escape(v.action) )
		) )
end
	
function form.stop ( )
	return ("</form>")
end

-- For "h1, h2, p," etc 
-- WARNING - Text is printed verbatim - you may want to
-- wrap the text in html_escape
function entity (tag, text, class, id)
	return ( string.format (
			"<%s%s%s>%s</%s>",
			html_escape(tag),
			nv_pair ("class", class),
			nv_pair("id", id), html_escape(text), html_escape(tag))
		)
end
	 

function link ( v ) 
	if ( v.value == nil ) then
		return nil
	end
	local str = nv_pair ( "href", v.value )
	for i,k in ipairs( { "class", "id" }) do
		str = str .. nv_pair ( k, v[k] )
	end

	return ( "<a " .. str .. ">" .. html_escape(v.label) .. "</a>" )
end
