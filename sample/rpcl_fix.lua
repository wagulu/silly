local proto = require "rpcproto"

local DO = {}

local idx = 3

DO[proto:querytag("rrpc_sum")] = function(fd, cmd, msg)
	idx = idx + 2
	local arpc_sum = {
		val = msg.val1 + msg.val2,
		suffix = msg.suffix .. "rpcd.fix." .. idx
	}
	print("call", fd, cmd, msg)
	return "arpc_sum", arpc_sum
end

return DO

