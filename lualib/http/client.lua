local socket = require "socket"
local ssl = require "ssl"
local stream = require "http.stream"
local dns = require "dns"

local client = {}
local EMPTY = {}

local function parseurl(url)
	local default = false
	local scheme, host, port, path= string.match(url, "(http[s]-)://([^:/]+):?(%d*)([%w-%.?&=_/]*)")
	if path == "" then
		path = "/"
	end
	if port == "" then
		if scheme == "https" then
			port = "443"
		elseif scheme == "http" then
			port = "80"
		else
			assert(false, "unsupport parse url scheme:" .. scheme)
		end
		default = true
	end
	return scheme, host, port, path, default
end

local function send_request(io_do, fd, method, host, abs, header, body)
	local tmp = ""
	table.insert(header, 1, string.format("%s %s HTTP/1.1", method, abs))
	table.insert(header, string.format("Host: %s", host))
	table.insert(header, string.format("Content-Length: %d", #body))
	table.insert(header, "User-Agent: Silly/0.2")
	table.insert(header, "Connection: keep-alive")
	table.insert(header, "\r\n")
	tmp = table.concat(header, "\r\n")
	tmp = tmp .. body
	io_do.write(fd, tmp)
end

local function recv_response(io_do, fd)
	local readl = function()
		return io_do.readline(fd, "\r\n")
	end
	local readn = function(n)
		return io_do.read(fd, n)
	end
	local status, first, header, body = stream.recv_request(readl, readn)
	if not status then	--disconnected
		return nil
	end
	if status ~= 200 then
		return status
	end
	local ver, status= first:match("HTTP/([%d|.]+)%s+(%d+)")
	return tonumber(status), header, body, ver
end

local function process(uri, method, header, body)
	local ip, io_do
	local scheme, host, port, path, default = parseurl(uri)
	if dns.isdomain(host) then
		ip = dns.query(host)
	else
		ip = host
	end
	if scheme == "https" then
		io_do = ssl
	elseif scheme == "http" then
		io_do = socket
	end
	if not default then
		host = string.format("%s:%s", host, port)
	end
	ip = string.format("%s@%s", ip, port)
	local fd = io_do.connect(ip)
	if not fd then
		return 599
	end
	header = header or EMPTY
	body = body or ""
	send_request(io_do, fd, method, host, path, header, body)
	local status, header, body, ver = recv_response(io_do, fd)
	io_do.close(fd)
	return status, header, body, ver
end

function client.GET(uri, header)
	return process(uri, "GET", header)
end

function client.POST(uri, header, body)
	return process(uri, "POST", header, body)
end

return client

