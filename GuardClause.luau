-- !strict
-- GuardClause.lua 


local GuardClause = {}

local _logger: any = nil
local _typeof = typeof
local _format = string.format

-- Conecta o logger para que as falhas de segurança apareçam no console central
function GuardClause.ConnectReporter(reporterInstance: any)
	_logger = reporterInstance
end

-- Centraliza como o erro é cuspido (seja via logger ou erro fatal)
local function report(msg: string, critical: boolean)
	if _logger then
		_logger:SendMessage("GuardClause", msg, critical and "Error" or "Warn")
	elseif critical then
		error("[GuardClause CRITICAL] " .. msg, 3)
	else
		warn("[GuardClause] " .. msg)
	end
end

-- [[ REGRAS DE VALIDAÇÃO ]] --

-- Checa se o tipo bate. Aceita múltiplos tipos usando pipe, ex: "string|number"
function GuardClause:Is(value: any, expected: string, critical: boolean?): boolean
	local actual = _typeof(value)
	
	-- Se tiver um "|", quebra a string e testa cada tipo permitido
	if expected:find("|") then
		for t in expected:gmatch("[^|]+") do
			if actual == t then return true end
		end
	elseif actual == expected then
		return true
	end

	report(_format("Tipo errado. O código pedia %s, mas chegou %s", expected, actual), critical or false)
	return false
end

-- Verifica se pertence à classe certa (IsA)
function GuardClause:IsInstance(value: any, className: string, critical: boolean?): boolean
	if _typeof(value) ~= "Instance" then
		report(_format("Esperava uma Instance (%s), mas recebi %s", className, _typeof(value)), critical or false)
		return false
	end
	
	if not value:IsA(className) then
		report(_format("Classe inválida. Esperado: %s, Real: %s", className, value.ClassName), critical or false)
		return false
	end
	return true
end

-- Trava o valor entre um mínimo e um máximo 
function GuardClause:Number(value: any, min: number?, max: number?, critical: boolean?): boolean
	if _typeof(value) ~= "number" then
		report("Valor não é numérico.", critical or false)
		return false
	end
	
	if (min and value < min) or (max and value > max) then
		report(_format("Número %f fora do limite permitido [%s, %s]", value, tostring(min), tostring(max)), critical or false)
		return false
	end
	return true
end

-- Garante que o valor está dentro de uma "whitelist" pré-definida
function GuardClause:InList(value: any, list: {any}, critical: boolean?): boolean
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	report(_format("O valor '%s' não consta na lista de opções permitidas.", tostring(value)), critical or false)
	return false
end

-- Valida tabelas complexas (Blueprints). 
-- Aceita campos opcionais com "?" e faz varredura profunda (recursiva).
function GuardClause:Schema(targetTable: any, blueprint: {[string]: any}, critical: boolean?): boolean
	if _typeof(targetTable) ~= "table" then
		report("Tentativa de rodar Schema em algo que não é tabela.", critical or false)
		return false
	end

	for key, expected in pairs(blueprint) do
		local value = targetTable[key]
		local actualType = _typeof(value)
		
		-- Lógica para campos opcionais (ex: "?string")
		local isOptional = false
		local expectedType = expected
		
		if _typeof(expected) == "string" and expected:sub(1,1) == "?" then
			isOptional = true
			expectedType = expected:sub(2)
			-- Se for nulo mas opcional, tá tudo certo, segue o baile
			if value == nil then continue end 
		end

		-- Se o blueprint for outra tabela, entramos nela para um "deep check"
		if _typeof(expectedType) == "table" then
			if not self:Schema(value, expectedType, critical) then
				return false
			end
		
		-- Validação simples de tipo
		elseif _typeof(expectedType) == "string" then
			if actualType ~= expectedType then
				report(_format("Erro no campo [%s]: Esperava %s, chegou %s", key, expectedType, actualType), critical or false)
				return false
			end
		end
	end

	return true
end

-- Para a execução na hora se a condição falhar. Use para evitar bugs em cascata.
function GuardClause:Assert(condition: boolean, msg: string)
	if not condition then
		report(msg, true)
		error(msg, 2)
	end
end

return GuardClause

