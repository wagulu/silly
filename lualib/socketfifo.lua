local socket = require("blocksocket")
local core = require "silly.core"
local s = require "silly.socket"

local tunpack = table.unpack
local tinsert = table.insert
local tremove = table.remove

local FIFO_CONNECTING   = 1
local FIFO_CONNECTED    = 2
local FIFO_CLOSE        = 3

local socketfifo = {
}

local function wakeup(v, dummy1, dummy2, ...)
        assert(dummy1 == nil or dummy1 == true)
        assert(dummy2 == nil or dummy2 == true)

        s.wakeup(v, ...)
end

--when close the socket fifo, we must wakeup all the wait coroutine
--but the coroutine which we wakeup can be call connect too,
--if so, things will become complicated
--so, the socketfifo will be implemented can only be connected once

function socketfifo:create(config)
        local fifo = {}
        self.__index = self
        setmetatable(fifo, self)

        fifo.status = false
        fifo.ip = config.ip
        fifo.port = config.port
        fifo.packer = config.packer
        fifo.auth = config.auth
        fifo.conn_queue = {}
        fifo.co_queue = {}
        fifo.res_queue = {}

        return fifo
end

local function wait_for_conn(fifo)
        fifo.conn_queue[#fifo.conn_queue + 1] = core.self()
        core.block()
end

local function wake_up_conn(fifo, res)
        for _, v in pairs(fifo.conn_queue) do
                wakeup(v)
        end

        fifo.conn_queue = {}
end

local function wait_for_response(fifo, response)
        local co = core.self()
        tinsert(fifo.co_queue, 1, co)
        tinsert(fifo.res_queue, 1, response)
        return core.block()
end

--this function will be run the indepedent coroutine
local function wakeup_response(fifo)
        return function ()
                while fifo.sock do
                        if fifo.sock:closed() then
                                fifo:close()
                                return
                        end

                        local process_res = tremove(fifo.res_queue)
                        local co = tremove(fifo.co_queue)
                        if process_res and co then
                                local res = { pcall(process_res, fifo) }
                                if res[1] and res[2] then
                                        wakeup(co, tunpack(res))
                                else
                                        print("wakeup_response", res[1], res[2])
                                        wakeup(co)
                                        fifo:close()
                                        return 
                                end
                        else
                                assert(fifo:read() == "")
                                core.block()
                        end
                end
        end
end

local function block_connect(self)
        if self.status == FIFO_CONNECTED then
                return true;
        end

        if self.status == false then
                local res

                self.status = FIFO_CONNECTING
                self.sock = socket:connect(self.ip, self.port, core.create(wakeup_response(self)))
                if self.sock == nil then
                        res = false
                        self.status = FIFO_CLOSE
                else
                        self.status = FIFO_CONNECTED
                        res = true
                end


                if self.auth then
                        wait_for_response(self, self.auth)
                end

                wake_up_conn(self)
                return res
        elseif self.status == FIFO_CONNECTING then
                wait_for_conn(self)
                if (self.status == FIFO_CONNECTED) then
                        return true
                else
                        return false
                end
        end

        return false
end

function socketfifo:connect()
        return block_connect(self)
end

function socketfifo:close()
        if self.status == FIFO_CLOSE then
                return 
        end
        self.status = FIFO_CLOSE
        local co = tremove(self.co_queue)
        tremove(self.res_queue)
        while co do
                wakeup(co)
                co = tremove(self.co_queue)
                tremove(self.res_queue)
        end

        self.sock:close()
        self.sock = nil

        return 
end

function socketfifo:closed()
        return self.status == FIFO_CLOSE
end

-- the respose function will be called in the socketfifo coroutine
function socketfifo:request(cmd, response)
        local res
        assert(block_connect(self))
        res = self.sock:write(cmd)
        if response then
                return wait_for_response(self, response)
        else
                res = nil
        end

        return res
end

local function read_write_wrapper(func)
        return function (self, d)
                return func(self.sock, d)
        end
end

socketfifo.read = read_write_wrapper(socket.read)
socketfifo.write = read_write_wrapper(socket.write)
socketfifo.readline = read_write_wrapper(socket.readline)

return socketfifo

