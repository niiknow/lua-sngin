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

-- convert a table to query string
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
    name = _M.encodeURIComponent(tostring(name))

    local value = _M.encodeURIComponent(tostring(value))
    if value ~= "" then
      query[#query+1] = string.format('%s=%s', name, q .. value .. q)
    else
      query[#query+1] = name
    end  
  end
  return table.concat(query, sep)
end

function _M.parseGithubRawLua(modname)
  -- capture path: https://raw.githubusercontent.com/
  local capturePath = "https://raw.githubusercontent.com/"
  if rawget(_G, __ghrawbase) == nil then
    -- only handle github.com for now
    if string.find(modname, "github.com/") then
      local user, repo, branch, pathx, query = string.match(modname, "github%.com/([^/]+)(/[^/]+)/blob(/[^/]+)(/[^?#]*)(.*)")
      local path, file = string.match(pathx, "^(.*/)([^/]*)$")
      local base = string.format("%s%s%s%s%s", capturePath, user, repo, branch, path)

      -- convert period to folder before return
      return base, string.gsub(string.gsub(file, "%.lua$", ""), '%.', "/") .. ".lua", query
    end
  else
    return __ghrawbase, string.gsub(string.gsub(modname, "%.lua$", ""), '%.', "/") .. ".lua", ""
  end
end

function _M.parseS3Url(s3url)
  local bucket, path = string.match(modname, "%.amazonaws%.com/([^/]+)(.*)")
end
return _M