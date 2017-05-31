require 'luarocks.loader' 
local crypto = require("crypto")
local utils = require("lib.sngin.utils")

local hi = crypto.list("digests")
print(utils.dump(hi))