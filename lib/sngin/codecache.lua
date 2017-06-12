local lfs     			= require "lfs"
local lru               = require "lru"
local aws_auth          = require "sngin.aws"
local crypto            = require "sngin.crypto"
local httpc             = require "sngin.httpclient"
local ngin              = require "sngin.ngin"
local sandbox           = require "sngin.sandbox"
local utils             = require "sngin.utils"
local plpath            = require "pl.path"

local code_cache_size   = ngin.config.sngin_codecache_size
local myUrlHandler      = ngin.getCodeFromS3

local _M = {}

--[[
the strategy of this cache is to:
1. dynamically load remote file
2. cache it locally
3. use local file to trigger cache purge
4. use ttl (in seconds) to determine how often to check remote file
-- when we have the file, it is recommended to check every hour
-- when we don't have the file, check every x seconds - limit by proxy
]]
function _M.new(self, localBasePath, ttl, codeHandler)
	local codeCache = lru.new(code_cache_size or 10000)

    local urlHandler = codeHandler or myUrlHandler
    local defaultTtl = ttl or 3600 -- default to 1 hours

    -- should not be lower than 2 minutes
    -- user should use cache clearing mechanism
    if (defaultTtl < 120) then
    	defaultTtl = 120
    end

    localBasePath = plpath.abspath(localBasePath)
    --ngx.say("hi")
--[[
if value holder is nil, initialize value holder
if value is nil or ttl has expired
-- load File if it exists
  -- set cache for next guy
  -- set fileModification DateTime
-- doCheckRemoteFile()
  -- if remote return 200
    -- write file, load data
  -- on 404 - delete local file, set nil
  -- on other error - do nothing
-- remove from cache if not found
-- return result function

NOTE: urlHandler should use capture to simulate debounce
]]
	local function doCheckRemoteFile(valHolder)
		local opts = {
			url = valHolder.url
		}

		if (valHolder.fileMod ~= nil) then
			opts["last_modified"] = os.date("%c", valHolder.fileMod)
		end

	    os.execute('mkdir -p "' .. valHolder.localPath .. '"')

		-- if remote return 200
		local rsp, err = urlHandler(opts)

		if (rsp.status == 200) then
			-- ngx.say(valHolder.localPath)
		    -- write file, load data

			local myFile = io.open(valHolder.localFullPath, "w")
			myFile:write(rsp.body)
			myFile:close()

			valHolder.fileMod = lfs.attributes (valHolder.localFullPath, "modification")
			valHolder.value = sandbox.loadstring(rsp.body, nil, ngin.getSandboxEnv())
		elseif (rsp.status == 404) then
		    -- on 404 - set nil and delete local file
		    valHolder.value = nil
		    os.remove(valHolder.localFullPath)
		end

		-- on other error - do nothing
	end

	local function get(url)
		local valHolder = codeCache:get(url)

		-- initialize valHolder
		if (valHolder == nil) then
			-- strip query string and http/https://
			local domainAndPath, query = string.match(url, "([^?#]*)(.*)")
			domainAndPath = string.gsub(string.gsub(domainAndPath, "http://", ""), "https://", "")

		    -- expect directory
			local fileBasePath = utils.sanitizePath(localBasePath .. "/" .. domainAndPath)

			-- must store locally as index.lua
			-- this way, a path can contain other paths
			localFullPath = fileBasePath .. "/index.lua"

			valHolder = {
			    url = url,
				localPath = fileBasePath,
				localFullPath = localFullPath,
				lastCheck = os.time(),
				fileMod = lfs.attributes (localFullPath, "modification")
			}
		end

		if (valHolder.value == nil or (valHolder.lastCheck < (os.time() - defaultTtl))) then
			-- load file if it exists
			valHolder.fileMod = lfs.attributes (valHolder.localFullPath, "modification")
			if (valHolder.fileMod ~= nil) then

				valHolder.value = sandbox.loadfile(valHolder.localFullPath, ngin.getSandboxEnv())

			    -- set it back immediately for the next guy
			    -- set next ttl
			    valHolder.lastCheck = os.time()
			    codeCache:set(url, valHolder)
			else
				-- delete reference if file no longer exists/purged
				valHolder.value = nil
			end

		    doCheckRemoteFile(valHolder)
		end


		-- remove from cache if not found
		if valHolder.value == nil then
			codeCache:delete(url)
		end

		return valHolder.value
	end

	local mt = {
        get = get
    }

	return mt
end

return _M