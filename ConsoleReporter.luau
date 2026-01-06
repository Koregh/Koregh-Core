--!strict
-- ConsoleReporter.luau
-- Logger com gerenciamento de memória e rastreio de stack.

local ConsoleReporter = {}
ConsoleReporter.__index = ConsoleReporter

-- Configurações de Segurança
local MAX_LOG_HISTORY = 500 -- Evita Memory Leak

-- Tipos
export type MessageType = "Error" | "Warn" | "Print"

export type LogEntry = {
	Time: string,
	Type: MessageType,
	Title: string,
	Message: string,
	StackTrace: string?, -- Útil para debugar erros complexos
}

export type ConsoleReporterType = typeof(setmetatable({} :: {
	LogHistory: { LogEntry },
	Functions: { [MessageType]: (string, string) -> () }
}, ConsoleReporter))

-- Cria uma nova instância do Logger
function ConsoleReporter.new(): ConsoleReporterType
	local self = setmetatable({}, ConsoleReporter)
	self.LogHistory = {}
	
	-- Dispatcher otimizado
	self.Functions = {
		Error = function(title: string, message: string)
			error(string.format("%s: %s", title, message), 3)
		end,
		Warn = function(title: string, message: string)
			warn(string.format("%s: %s", title, message))
		end,
		Print = function(title: string, message: string)
			print(string.format("%s: %s", title, message))
		end,
	}
	
	return self :: any
end

-- Gera timestamp legível (Otimizado)
function ConsoleReporter:GetTimestamp(): string
	local date = os.date("*t")
	return string.format("[%02d:%02d:%02d]", date.hour, date.min, date.sec)
end

-- Envia mensagem e gerencia histórico
function ConsoleReporter:SendMessage(Title: string?, Message: string, Type: MessageType)
	local safeTitle = Title or "System"
	local ts = self:GetTimestamp()
	
	-- Captura Stack Trace apenas para erros
	local stack = nil
	if Type == "Error" then
		stack = debug.traceback(nil, 3)
	end

	local logEntry: LogEntry = {
		Time = ts,
		Type = Type,
		Title = safeTitle,
		Message = Message,
		StackTrace = stack
	}

	-- Gerenciamento de Memória (Buffer Circular)
	table.insert(self.LogHistory, logEntry)
	if #self.LogHistory > MAX_LOG_HISTORY then
		table.remove(self.LogHistory, 1) -- Remove o mais antigo
	end

	-- Execução da saída
	local func = self.Functions[Type]
	if func then
		func(string.format("%s %s", ts, safeTitle), Message)
	else
		-- Fallback de segurança
		warn(string.format("[ConsoleReporter] Tipo inválido: %s | Msg: %s", tostring(Type), Message))
	end
end

-- Retorna histórico completo
function ConsoleReporter:GetHistory(): { LogEntry }
	return self.LogHistory
end

-- Limpa histórico
function ConsoleReporter:ClearHistory()
	table.clear(self.LogHistory)
end

-- Filtra histórico por tipo (Otimizado com table.create)
function ConsoleReporter:GetHistoryByType(Type: MessageType): { LogEntry }
	local filtered = {}
	for _, entry in self.LogHistory do
		if entry.Type == Type then
			table.insert(filtered, entry)
		end
	end
	return filtered
end

return ConsoleReporter
