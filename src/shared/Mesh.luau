-- Modelli 3D fatti in Blender (tools/blender/esporta.py -> tools/converti_mesh.py -> Shared/MeshDati).
-- Costruisce a runtime una MeshPart con ossa e texture da quei dati, una volta per tipo e scala,
-- e ne dà copie: ogni copia ha le sue ossa (Bone) da animare con Bone.Transform.
-- Le ossa a riposo hanno orientamento neutro: ruotarle gira attorno agli assi del modello
-- (X a destra del soldato, Y in alto, Z dietro di lui).

local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")

local Mesh = {}

local cartellaDati = script.Parent:WaitForChild("MeshDati")
local modelli = {} -- chiave -> { parte = MeshPart, ossa = { nome -> CFrame relativo al padre }, ... }
local inCostruzione = {}

local function decomprimi(base64, lunghezza)
	local compressi = EncodingService:Base64Decode(buffer.fromstring(base64))
	local dati = EncodingService:DecompressBuffer(compressi, Enum.CompressionAlgorithm.Zstd)
	assert(buffer.len(dati) == lunghezza, "dati del modello corrotti")
	return dati
end

function Mesh.disponibile(nome)
	return cartellaDati:FindFirstChild(nome) ~= nil
end

local function costruisci(nome, scala)
	local dati = require(cartellaDati[nome])
	local geometria = decomprimi(dati.geometria, dati.lunghezzaGeometria)
	local minimo = Vector3.new(table.unpack(dati.minimo))
	local massimo = Vector3.new(table.unpack(dati.massimo))
	local estensione = massimo - minimo
	-- I vertici si centrano sul mezzo del modello: la MeshPart ha lì il suo centro.
	local centro = (minimo + massimo) / 2

	local em = AssetService:CreateEditableMesh()
	local ossaId, ossa = {}, {}
	for _, osso in ipairs(dati.ossa) do
		local posizione = Vector3.new(table.unpack(osso.posizione))
		local padre = osso.padre and ossa[osso.padre]
		local relativa = padre and (posizione - padre.posizione) or (posizione - centro)
		local cframe = CFrame.new(relativa * scala)
		-- AddBone vuole la posizione nello spazio della mesh; le istanze Bone invece sono relative al padre.
		ossaId[osso.nome] = em:AddBone({
			Name = osso.nome,
			CFrame = CFrame.new((posizione - centro) * scala),
			Virtual = false,
			ParentId = padre and padre.id or nil,
		})
		ossa[osso.nome] = { id = ossaId[osso.nome], posizione = posizione, cframe = cframe, padre = osso.padre }
	end
	local nomiOssa = {}
	for i, osso in ipairs(dati.ossa) do
		nomiOssa[i - 1] = osso.nome
	end

	local nv = buffer.readu32(geometria, 0)
	local nt = buffer.readu32(geometria, 4)
	local vertici, normali, uv = table.create(nv), table.create(nv), table.create(nv)
	local o = 8
	for i = 1, nv do
		local q = Vector3.new(buffer.readu16(geometria, o), buffer.readu16(geometria, o + 2), buffer.readu16(geometria, o + 4)) / 65535
		local posizione = (minimo + q * estensione - centro) * scala
		local v = em:AddVertex(posizione)
		vertici[i] = v
		uv[i] = em:AddUV(Vector2.new(buffer.readu16(geometria, o + 6) / 65535, buffer.readu16(geometria, o + 8) / 65535))
		local n = Vector3.new(buffer.readi8(geometria, o + 10), buffer.readi8(geometria, o + 11), buffer.readi8(geometria, o + 12))
		normali[i] = em:AddNormal(n.Magnitude > 0 and n.Unit or Vector3.yAxis)
		local idOssa, pesi = {}, {}
		for k = 0, 3 do
			local peso = buffer.readu8(geometria, o + 17 + k)
			if peso > 0 then
				table.insert(idOssa, ossaId[nomiOssa[buffer.readu8(geometria, o + 13 + k)]])
				table.insert(pesi, peso / 255)
			end
		end
		em:SetVertexBones(v, idOssa)
		em:SetVertexBoneWeights(v, pesi)
		o += 21
	end
	for _ = 1, nt do
		local a, b, c = buffer.readu16(geometria, o) + 1, buffer.readu16(geometria, o + 2) + 1, buffer.readu16(geometria, o + 4) + 1
		o += 6
		local faccia = em:AddTriangle(vertici[a], vertici[b], vertici[c])
		em:SetFaceNormals(faccia, { normali[a], normali[b], normali[c] })
		em:SetFaceUVs(faccia, { uv[a], uv[b], uv[c] })
	end

	local parte = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	parte.Name = nome
	parte.Anchored = false
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.Material = Enum.Material.SmoothPlastic
	parte.Color = Color3.new(1, 1, 1)

	local lato = dati.lato
	local rgb = decomprimi(dati.texture, dati.lunghezzaTexture)
	local rgba = buffer.create(lato * lato * 4)
	for i = 0, lato * lato - 1 do
		buffer.writeu8(rgba, i * 4, buffer.readu8(rgb, i * 3))
		buffer.writeu8(rgba, i * 4 + 1, buffer.readu8(rgb, i * 3 + 1))
		buffer.writeu8(rgba, i * 4 + 2, buffer.readu8(rgb, i * 3 + 2))
		buffer.writeu8(rgba, i * 4 + 3, 255)
	end
	local immagine = AssetService:CreateEditableImage({ Size = Vector2.new(lato, lato) })
	immagine:WritePixelsBuffer(Vector2.zero, Vector2.new(lato, lato), rgba)
	parte.TextureContent = Content.fromObject(immagine)

	-- Le ossa come istanze (CreateMeshPartAsync non le crea): stessi nomi e stessa gerarchia.
	local istanze = {}
	for _, osso in ipairs(dati.ossa) do
		local b = Instance.new("Bone")
		b.Name = osso.nome
		b.CFrame = ossa[osso.nome].cframe
		b.Parent = osso.padre and istanze[osso.padre] or parte
		istanze[osso.nome] = b
	end

	return {
		parte = parte,
		mesh = em,
		immagine = immagine,
		centro = centro * scala,
		altezza = estensione.Y * scala,
		basso = (minimo.Y - centro.Y) * scala,
	}
end

-- Copia della MeshPart del modello "nome" alla scala data (studs per metro).
-- Restituisce la parte (non ancora nel workspace), la sua posizione rispetto all'origine del modello e quanto
-- scende il punto più basso sotto il centro della parte.
function Mesh.copia(nome, scala)
	local chiave = nome .. "@" .. scala
	while inCostruzione[chiave] do
		task.wait()
	end
	local modello = modelli[chiave]
	if not modello then
		inCostruzione[chiave] = true
		local ok, risultato = pcall(costruisci, nome, scala)
		inCostruzione[chiave] = nil
		if not ok then
			warn("[Mesh] " .. nome .. ": " .. tostring(risultato))
			return nil
		end
		modello = risultato
		modelli[chiave] = modello
	end
	return modello.parte:Clone(), modello.centro, modello.basso
end

return Mesh
