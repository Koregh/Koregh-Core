--!strict
-- ServiceManager.lua


local ServiceManager = {}
local _services: { [string]: any } = {}

-- [[ MÉTODOS PÚBLICOS ]] --

-- Varre a pasta de serviços e coloca todo mundo na memória (Lazy Loading)
function ServiceManager.Load(servicesFolder: Folder)
	for _, module in ipairs(servicesFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			-- O pcall aqui evita que um erro de sintaxe em um script derrube o carregamento dos outros
			local success, service = pcall(require, module)
			if success then
				_services[module.Name] = service
			else
				warn(`[ServiceManager] Falha crítica ao dar require em {module.Name}: {service}`)
			end
		end
	end
end

-- Prepara as dependências. É aqui que os serviços recebem o Framework e se configuram.
function ServiceManager.InitAll(framework: any)
	for name, service in pairs(_services) do
		if type(service.Init) == "function" then
			-- Blindagem: se um serviço quebrar no Init, o restante do jogo ainda tenta subir
			local success, err = pcall(service.Init, framework)
			if not success then
				-- Tenta usar o logger central, mas tem um fallback caso ele ainda não esteja pronto
				if framework.Log then
					framework.Log:SendMessage("Critical", `Erro no Init do serviço {name}: {err}`, "Error")
				else
					warn(`[ServiceManager] Erro no Init de {name}: {err}`)
				end
			end
		end
	end
end

-- Roda a lógica ativa (loops, conexões de eventos, etc.)
function ServiceManager.StartAll()
	for name, service in pairs(_services) do
		if type(service.Start) == "function" then
			-- Cada serviço ganha sua própria thread (task.spawn).
			-- Assim, um loop infinito no Serviço A não trava o Serviço B.
			task.spawn(function()
				local success, err = pcall(service.Start)
				if not success then
					warn(`[ServiceManager] Erro de execução no serviço {name}: {err}`)
				end
			end)
		end
	end
end

return ServiceManager

