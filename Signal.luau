--!strict
-- Signal.lua
-- Uma implementação simplificada de FastSignal para comunicação interna ultra-rápida.

local Signal = {}
Signal.__index = Signal

type Connection = {
	Disconnect: (Connection) -> (),
	_handler: (...any) -> (),
	_signal: any,
}

function Signal.new()
	return setmetatable({
		_listeners = {}
	}, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local connection = {
		_handler = handler,
		_signal = self,
		Disconnect = function(conn)
			local listeners = conn._signal._listeners
			local index = table.find(listeners, conn)
			if index then
				table.remove(listeners, index)
			end
		end
	}
	table.insert(self._listeners, connection)
	return connection
end

function Signal:Fire(...: any)
	for _, connection in ipairs(self._listeners) do
		task.spawn(connection._handler, ...)
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	table.clear(self._listeners)
end

return Signal
