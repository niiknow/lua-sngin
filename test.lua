require 'luarocks.loader' 
local utils = require("lib.sngin.utils")
local base, file, query = utils.parseGithubRawLua("github.com-production/niiknow/test-repo/hello.world.lua?boom=1")
local url = base .. file .. query
print(url)