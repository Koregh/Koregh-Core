--!strict
-- Signal.lua

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

-- Cria uma nova conexão. O handler será executado toda vez que o sinal for disparado.
function Signal:Connect(handler: (...any) -> ())
	local connection = {
		_handler = handler,
		_signal = self,
		Disconnect = function(conn)
			-- Remove o ouvinte da lista para que ele pare de receber atualizações
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

-- Avisa todos os inscritos que algo aconteceu. 
-- Cada handler roda em sua própria thread para evitar gargalos.
function Signal:Fire(...: any)
	for _, connection in ipairs(self._listeners) do
		task.spawn(connection._handler, ...)
	end
end

-- Faz o código "esperar" até que o sinal seja disparado uma vez.
function Signal:Wait()
	local thread = coroutine.running()
	local connection
	
	-- Conecta, recebe o dado, se auto-desconecta e retoma a thread original
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	
	return coroutine.yield()
end

-- Limpa todos os inscritos de uma vez. Útil para resetar sistemas.
function Signal:Destroy()
	table.clear(self._listeners)
end

return Signal

