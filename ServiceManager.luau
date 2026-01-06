--!strict
-- ServiceManager.lua

local ServiceManager = {}
local _services: { [string]: any } = {}

-- [[ MÉTODOS PÚBLICOS ]] --

-- Varre a pasta de serviços e coloca todo mundo na memória
function ServiceManager.Load(servicesFolder: Folder)
	for _, module in ipairs(servicesFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local success, service = pcall(require, module)
			if success then
				_services[module.Name] = service
			else
				warn(`[ServiceManager] Falha crítica ao dar require em {module.Name}: {service}`)
			end
		end
	end
end

-- Prepara as dependências e mede o tempo de resposta (Telemetria)
function ServiceManager.InitAll(framework: any)
	for name, service in pairs(_services) do
		if type(service.Init) == "function" then
			-- [TELEMETRIA] Começamos a contar o tempo aqui
			local startTime = os.clock()
			
			local success, err = pcall(service.Init, framework)
			
			local duration = os.clock() - startTime
			
			if not success then
				if framework.Log then
					framework.Log:SendMessage("Critical", `Erro no Init do serviço {name}: {err}`, "Error")
				else
					warn(`[ServiceManager] Erro no Init de {name}: {err}`)
				end
			else
				-- Log de performance: se demorar mais que 0.1s, avisa que está lento
				if duration > 0.1 and framework.Log then
					framework.Log:SendMessage("Warning", `Serviço {name} demorou {string.format("%.4f", duration)}s para iniciar!`, "Warn")
				end
			end
		end
	end
end

-- Roda a lógica ativa (loops, conexões de eventos, etc.)
function ServiceManager.StartAll()
	for name, service in pairs(_services) do
		if type(service.Start) == "function" then
			task.spawn(function()
				local success, err = pcall(service.Start)
				if not success then
					warn(`[ServiceManager] Erro de execução no serviço {name}: {err}`)
				end
			end)
		end
	end
end

-- [O NOVO]: Permite que um serviço encontre o outro com segurança
-- Ex: local Economy = ServiceManager.Get("EconomyService")
function ServiceManager.Get(name: string): any
	local service = _services[name]
	if not service then
		warn(`[ServiceManager] Tentativa de acessar serviço inexistente: {name}`)
		return nil
	end
	return service
end

return ServiceManager

