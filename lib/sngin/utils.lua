-- our utils lib, nothing here should depend on ngx
-- for ngx stuff, put it inside ngin.lua file
local _M = {}

function _M.trim(str)
	if (str == nil) then
		return nil
	end
	return string.match(str, '^%s*(.*%S)') or ''
end

function _M.slugify(str)
	if (str == nil) then
		return nil
	end
	str = self.trim(str)
	return string.lower(string.gsub(string.gsub(str,"[^ A-Za-z]"," "),"[ ]+","-"))
end

function _M.slugemail(str)
	if (str == nil) then
		return nil
	end
	str = trim(str)
	return string.lower(string.gsub(str,"[^@0-9A-Za-z]","-"))
end

function _M.split(str, sep, dest)
	if (str == nil) then
		return {}
	end

  if sep == nil then
    sep = "%s"
  end

  local t = dest or {}
  for str in string.gmatch(str, "([^"..sep.."]+)") do
    table.insert(t, str)
  end

  return t
end

function _M.encodeURIComponent(s)
   s = string.gsub(s, 
      "([&=+%c])", 
      function (c)
        return string.format("%%%02X", string.byte(c))
      end)
   s = string.gsub(s, " ", "%20")
   return s
end

function _M.sanitizePath(s)
	-- path should not have double quote, single quote, period
	-- we purposely left casing because paths are case-sensitive
	s = string.gsub(s, "[^a-zA-Z0-9.-_/]", "")

	-- remove double period and forward slash
	s = string.gsub(string.gsub(s, "%.%.", ""), "//", "/")

	-- remove trailing forward slash
	s = string.gsub(s, "/*$", "")

	return s
end

return _M