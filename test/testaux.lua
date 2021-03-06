local core = require "silly.core"
local c = require "testaux.c"
local testaux = {}

local rand = math.random

local meta_str = "abcdefghijklmnopqrstuvwxyz"
local meta = {}
for i = 1, #meta_str do
	meta[#meta + 1] = meta_str:sub(i, i)
end

math.randomseed(core.now())

--inhierit testaux.c function
for k, v in pairs(c) do
	testaux[k] = v
end

function testaux.randomdata(sz)
	local tbl = {}
	for i = 1, sz do
		tbl[#tbl+1] = meta[rand(#meta)]
	end
	return table.concat(tbl, "")
end

function testaux.checksum(acc, str)
	for i = 1, #str do
		acc = acc + str:byte(i)
	end
	return acc
end

local function perror(str, a, b)
	a = a or "(nil)"
	b = b or "(nil)"
	assert(false, str .. " fail(data1:" .. a .. " data2:" .. b .. ")")
end

function testaux.asserteq(a, b, str)
	if a == b then
		return
	end
	perror(str, a, b)
end

function testaux.assertneq(a, b, str)
	if a ~= b then
		return
	end
	perror(str, a, b)
end


return testaux


