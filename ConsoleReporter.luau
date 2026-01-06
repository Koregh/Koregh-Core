--!strict
-- ConsoleReporter.luau

local ConsoleReporter = {}
ConsoleReporter.__index = ConsoleReporter

-- Limite para o histórico não crescer infinitamente e estourar
local MAX_LOG_HISTORY = 500 

-- Tipos para o Luau
export type MessageType = "Error" | "Warn" | "Print"

export type LogEntry = {
	Time: string,
	Type: MessageType,
	Title: string,
	Message: string,
	StackTrace: string?, -- Guardamos o caminho do erro para facilitar o debug
}

export type ConsoleReporterType = typeof(setmetatable({} :: {
	LogHistory: { LogEntry },
	Functions: { [MessageType]: (string, string) -> () }
}, ConsoleReporter))

-- Construtor do logger
function ConsoleReporter.new(): ConsoleReporterType
	local self = setmetatable({}, ConsoleReporter)
	self.LogHistory = {}
	
	-- Atalhos para não precisar de if/else toda vez que for printar algo
	self.Functions = {
		Error = function(title: string, message: string)
			-- Nível 3 para o erro apontar para quem chamou o logger, não para este script
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

-- Formata a hora atual para o log
function ConsoleReporter:GetTimestamp(): string
	local date = os.date("*t")
	return string.format("[%02d:%02d:%02d]", date.hour, date.min, date.sec)
end

-- O "coração" do módulo: processa a mensagem, salva no histórico e joga no console
function ConsoleReporter:SendMessage(Title: string?, Message: string, Type: MessageType)
	local safeTitle = Title or "System"
	local ts = self:GetTimestamp()
	
	-- Só puxamos o traceback se for erro, para não pesar o desempenho à toa
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

	-- Mantém o histórico sob controle (remove o mais velho se passar do limite)
	table.insert(self.LogHistory, logEntry)
	if #self.LogHistory > MAX_LOG_HISTORY then
		table.remove(self.LogHistory, 1)
	end

	-- Dispara o output correto (print, warn ou error)
	local func = self.Functions[Type]
	if func then
		func(string.format("%s %s", ts, safeTitle), Message)
	else
		-- Se alguém passar um tipo inexistente, avisamos para não perder a informação
		warn(string.format("[ConsoleReporter] Tipo inválido: %s | Msg: %s", tostring(Type), Message))
	end
end

-- Pega tudo que foi logado até agora
function ConsoleReporter:GetHistory(): { LogEntry }
	return self.LogHistory
end

-- Faxina no histórico
function ConsoleReporter:ClearHistory()
	table.clear(self.LogHistory)
end

-- Retorna só os logs de um tipo específico (ex: só erros)
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

