--!strict
-- GuardClause.lua 
-- Validação Recursiva, Verificação de Instâncias, Enums e Sanitização de Dados.

local GuardClause = {}

local _logger: any = nil
local _typeof = typeof
local _format = string.format

-- [Configuração]
function GuardClause.ConnectReporter(reporterInstance: any)
	_logger = reporterInstance
end

local function report(msg: string, critical: boolean)
	if _logger then
		_logger:SendMessage("GuardClause", msg, critical and "Error" or "Warn")
	elseif critical then
		error("[GuardClause CRITICAL] " .. msg, 3)
	else
		warn("[GuardClause] " .. msg)
	end
end

-- [[ MÉTODOS DE VALIDAÇÃO ]] --

-- 1. Validação de Tipos Básicos (com suporte a múltiplos tipos)
-- Ex: Guard:Is(val, "string|number")
function GuardClause:Is(value: any, expected: string, critical: boolean?): boolean
	local actual = _typeof(value)
	
	-- Suporta verificação de múltiplos tipos separados por |
	if expected:find("|") then
		for t in expected:gmatch("[^|]+") do
			if actual == t then return true end
		end
	elseif actual == expected then
		return true
	end

	report(_format("Tipo inválido. Esperado: %s, Recebeu: %s", expected, actual), critical or false)
	return false
end

-- 2. Validação de Instâncias do Roblox com suporte a ClassName
function GuardClause:IsInstance(value: any, className: string, critical: boolean?): boolean
	if _typeof(value) ~= "Instance" then
		report(_format("Esperada Instance (%s), recebeu %s", className, _typeof(value)), critical or false)
		return false
	end
	
	if not value:IsA(className) then
		report(_format("Instance de classe errada. Esperado: %s, Recebeu: %s", className, value.ClassName), critical or false)
		return false
	end
	return true
end

-- 3. Validação de Números com Clamping (Range)
function GuardClause:Number(value: any, min: number?, max: number?, critical: boolean?): boolean
	if _typeof(value) ~= "number" then
		report("O valor não é um número.", critical or false)
		return false
	end
	
	if (min and value < min) or (max and value > max) then
		report(_format("Número %f fora do intervalo permitido [%s, %s]", value, tostring(min), tostring(max)), critical or false)
		return false
	end
	return true
end

-- 4. Validação de Enums (Verifica se o valor está em uma lista)
-- Ex: Guard:InList("Fire", {"Fire", "Ice", "Wind"})
function GuardClause:InList(value: any, list: {any}, critical: boolean?): boolean
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	report(_format("Valor '%s' não é uma opção válida na lista permitida.", tostring(value)), critical or false)
	return false
end

-- 5. SCHEMA RECURSIVO (O Coração do Sistema)
-- Suporta: tabelas dentro de tabelas e tipos opcionais (prefixados com ?)
-- Ex blueprint: { Name = "string", Stats = { Level = "number" }, Optional = "?string" }
function GuardClause:Schema(targetTable: any, blueprint: {[string]: any}, critical: boolean?): boolean
	if _typeof(targetTable) ~= "table" then
		report("O alvo do Schema não é uma tabela.", critical or false)
		return false
	end

	for key, expected in pairs(blueprint) do
		local value = targetTable[key]
		local actualType = _typeof(value)
		
		-- Caso o campo seja opcional (ex: "?string")
		local isOptional = false
		local expectedType = expected
		
		if _typeof(expected) == "string" and expected:sub(1,1) == "?" then
			isOptional = true
			expectedType = expected:sub(2)
			if value == nil then continue end -- Pula se for opcional e nulo
		end

		-- Se o blueprint for uma tabela, valida recursivamente (Deep Check)
		if _typeof(expectedType) == "table" then
			if not self:Schema(value, expectedType, critical) then
				return false
			end
		
		-- Se for uma string de tipo simples
		elseif _typeof(expectedType) == "string" then
			if actualType ~= expectedType then
				report(_format("Erro no campo [%s]: Esperado %s, recebeu %s", key, expectedType, actualType), critical or false)
				return false
			end
		end
	end

	return true
end

-- 6. ASSERT (Fail-Fast)
-- Útil para parar o código imediatamente se algo estiver errado
function GuardClause:Assert(condition: boolean, msg: string)
	if not condition then
		report(msg, true)
		error(msg, 2)
	end
end

return GuardClause

