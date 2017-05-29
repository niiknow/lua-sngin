
local escape_uri        = ngx.escape_uri

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

function _M.qsencode(tab, delimiter, quote)
  local query = {}
  local q = quote or ''
  local sep = delimiter or ''
  local keys = {}
  for k in pairs(tab) do
    keys[#keys+1] = k
  end
  table.sort(keys)
  for _,name in ipairs(keys) do
    local value = tab[name]
    name = escape_uri(tostring(name))

    local value = escape_uri(tostring(value))
    if value ~= "" then
      query[#query+1] = string.format('%s=%s', name, q .. value .. q)
    else
      query[#query+1] = name
    end  
  end
  return table.concat(query, sep)
end

return _M