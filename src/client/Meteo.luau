-- Pioggia e neve che cadono attorno alla telecamera durante le battaglie (Config/Luci.meteo[].particelle).
-- Un blocco invisibile sopra la telecamera, un po' avanti a dove guarda, la segue e fa cadere le particelle:
-- si vedono ovunque si guardi, senza riempire tutto il campo.

local RunService = game:GetService("RunService")

local Meteo = {}

local TIPI = {
	pioggia = {
		altezza = 40,
		lato = 70,
		-- Roblox limita le gocce di un singolo emettitore: con uno solo la pioggia sembra rada.
		emettitori = 4,
		proprieta = {
			Rate = 2000,
			Lifetime = NumberRange.new(0.7, 0.9),
			Speed = NumberRange.new(70, 85),
			Size = NumberSequence.new(0.34),
			-- Negativo: la goccia si allunga lungo la caduta (positivo la allargherebbe).
			Squash = NumberSequence.new(-3),
			Color = ColorSequence.new(Color3.fromRGB(222, 230, 242)),
			Transparency = NumberSequence.new(0.3),
			LightEmission = 0.1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Acceleration = Vector3.new(2, -10, 0),
		},
	},
	neve = {
		altezza = 22,
		lato = 90,
		proprieta = {
			Rate = 450,
			Lifetime = NumberRange.new(6, 8),
			Speed = NumberRange.new(3, 5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25, 0.08), NumberSequenceKeypoint.new(1, 0.25, 0.08) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.15), NumberSequenceKeypoint.new(0.9, 0.15), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 0.3,
			SpreadAngle = Vector2.new(25, 25),
			RotSpeed = NumberRange.new(-60, 60),
			Rotation = NumberRange.new(0, 360),
			Drag = 0.4,
			Acceleration = Vector3.new(1.5, -2, 0.5),
		},
	},
}

local blocco, connessione, attuale

function Meteo.imposta(tipo)
	if tipo == attuale then
		return
	end
	attuale = tipo
	if connessione then
		connessione:Disconnect()
		connessione = nil
	end
	if blocco then
		blocco:Destroy()
		blocco = nil
	end
	local conf = tipo and TIPI[tipo]
	if not conf then
		return
	end
	blocco = Instance.new("Part")
	blocco.Name = "Meteo"
	blocco.Anchored = true
	blocco.CanCollide = false
	blocco.CanQuery = false
	blocco.CanTouch = false
	blocco.CastShadow = false
	blocco.Transparency = 1
	blocco.Size = Vector3.new(conf.lato, 1, conf.lato)
	local emettitore = Instance.new("ParticleEmitter")
	emettitore.EmissionDirection = Enum.NormalId.Bottom
	for k, v in pairs(conf.proprieta) do
		emettitore[k] = v
	end
	emettitore.Parent = blocco
	for _ = 2, conf.emettitori or 1 do
		emettitore:Clone().Parent = blocco
	end
	blocco.Parent = workspace
	connessione = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and blocco then
			local avanti = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if avanti.Magnitude > 0.01 then
				avanti = avanti.Unit * conf.lato * 0.35
			end
			blocco.CFrame = CFrame.new(camera.CFrame.Position + avanti + Vector3.new(0, conf.altezza, 0))
		end
	end)
end

return Meteo
