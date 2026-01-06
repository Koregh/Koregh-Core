--!strict
-- GuardClause.lua
-- O validador: Tipagem, Instâncias, Tabelas e Logs integrados.

local GuardClause = {}

local _logger: any = nil
local _typeof = typeof
local _format = string.format

-- Conecta ao seu ConsoleReporter
function GuardClause.ConnectReporter(reporterInstance: any)
	_logger = reporterInstance
end

-- Relatório centralizado
local function report(msg: string, critical: boolean)
	if _logger then
		_logger:SendMessage("GuardClause", msg, critical and "Error" or "Warn")
	elseif critical then
		error("[GuardClause Critical] " .. msg, 3)
	else
		warn("[GuardClause] " .. msg)
	end
end

-- [1] Validação Básica de Tipos
function GuardClause:Is(value: any, expectedType: string, critical: boolean?): boolean
	local ok = _typeof(value) == expectedType
	if not ok then
		report(_format("Esperado %s, recebeu %s", expectedType, _typeof(value)), critical or false)
	end
	return ok
end

-- [2] Validação de Instâncias do Roblox (Ex: "Part", "Player", "RemoteEvent")
function GuardClause:IsInstance(value: any, className: string, critical: boolean?): boolean
	local isInst = _typeof(value) == "Instance"
	local ok = isInst and value:IsA(className)
	
	if not ok then
		local got = isInst and value.ClassName or _typeof(value)
		report(_format("Esperada Instance do tipo %s, mas recebeu %s", className, got), critical or false)
	end
	return ok
end

-- [3] Validação de Números com Range
function GuardClause:Number(value: any, min: number?, max: number?, critical: boolean?): boolean
	if _typeof(value) ~= "number" then
		report("Valor não é um número.", critical or false)
		return false
	end
	if (min and value < min) or (max and value > max) then
		report(_format("Número %f fora do limite (%s, %s)", value, tostring(min), tostring(max)), critical or false)
		return false
	end
	return true
end

-- [4] Validação de Tabelas (SCHEMA) 
function GuardClause:Schema(targetTable: any, blueprint: {[string]: string}, critical: boolean?): boolean
	if _typeof(targetTable) ~= "table" then
		report("O alvo da validação de Schema não é uma tabela.", critical or false)
		return false
	end

	for key, expectedType in pairs(blueprint) do
		if _typeof(targetTable[key]) ~= expectedType then
			report(_format("Erro no Schema: Chave [%s] esperava %s, obteve %s", tostring(key), expectedType, _typeof(targetTable[key])), critical or false)
			return false
		end
	end
	return true
end

return GuardClause
