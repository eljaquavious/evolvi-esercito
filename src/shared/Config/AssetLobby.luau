-- Oggetti della lobby fatti in Blender (tools/blender/lobby.py), caricati con tools/carica-truppe.ps1
-- -Prefisso "EYA lobby". File generato da tools/lobby_luau.py: non modificarlo a mano.
-- Un Model con una MeshPart per oggetto. Per ogni oggetto, in studs e negli assi di Roblox, rispetto alla sua
-- origine (il punto d'appoggio; davanti verso -Z): centro dell'ingombro (= MeshPart.Position), misure e
-- punti dove il gioco mette fuochi, luci e scritte.

return {
	id = 109573531160590,
	oggetti = {
		BancoArmy = { centro = Vector3.new(-0, 3.24, 0), misure = Vector3.new(20, 6.48, 8), punti = { fuoco = { Vector3.new(8.6, 6.64, 2.6), Vector3.new(-8.6, 6.64, 2.6) } } },
		BancoCassa = { centro = Vector3.new(-0, 1.73, 0), misure = Vector3.new(7, 3.46, 5.4), punti = { piano = { Vector3.new(-0, 3.46, 0) }, targa = { Vector3.new(-0, 1.75, -2.6) } } },
		Botte = { centro = Vector3.new(-0, 1.55, 0), misure = Vector3.new(2.451, 3.1, 2.451), punti = {  } },
		Braciere = { centro = Vector3.new(-0, 2.048, 0), misure = Vector3.new(4.36, 4.136, 4.36), punti = { fuoco = { Vector3.new(-0, 4.2, 0) } } },
		Cartello = { centro = Vector3.new(-0, 0.866, -0.1), misure = Vector3.new(27.1, 9.832, 1), punti = { scritta = { Vector3.new(-0, 0, -0.32) } } },
		CassaLegno = { centro = Vector3.new(-0, 1.8, 0), misure = Vector3.new(3.7, 3.6, 3.7), punti = {  } },
		ColonnaMarmo = { centro = Vector3.new(-0, 14, 0), misure = Vector3.new(4.12, 28, 4.12), punti = {  } },
		ColonnaPorta = { centro = Vector3.new(-0, 13, 0), misure = Vector3.new(4.92, 26, 4.92), punti = {  } },
		ColonnaRotonda = { centro = Vector3.new(-0, 20, 0), misure = Vector3.new(5.12, 40, 5.12), punti = {  } },
		LampadaIndustriale = { centro = Vector3.new(-0, -1.897, 0), misure = Vector3.new(3.1, 3.793, 3.1), punti = { luce = { Vector3.new(-0, -3.5, 0) } } },
		Lampadario = { centro = Vector3.new(-0, 0.3, 0), misure = Vector3.new(27.1, 3.4, 27.072), punti = { catena = { Vector3.new(-9.192, 0.75, 9.192), Vector3.new(9.192, 0.75, 9.192), Vector3.new(9.192, 0.75, -9.192), Vector3.new(-9.192, 0.75, -9.192) }, fuoco = { Vector3.new(-13, 2.3, 0), Vector3.new(-9.192, 2.3, 9.192), Vector3.new(-0, 2.3, 13), Vector3.new(9.192, 2.3, 9.192), Vector3.new(13, 2.3, 0), Vector3.new(9.192, 2.3, -9.192), Vector3.new(0, 2.3, -13), Vector3.new(-9.192, 2.3, -9.192) } } },
		Piedistallo = { centro = Vector3.new(-0, 0.981, -0.396), misure = Vector3.new(9.3, 1.962, 10.593), punti = { piano = { Vector3.new(-0, 1.76, 0) }, targa = { Vector3.new(-0, 1.105, -5.4) } } },
		PlintoStatua = { centro = Vector3.new(-0, 2.28, 0), misure = Vector3.new(10.12, 4.56, 10.12), punti = { piano = { Vector3.new(-0, 4.56, 0) } } },
		Podio = { centro = Vector3.new(-0, 2.25, 0), misure = Vector3.new(20.4, 4.5, 7.4), punti = { cifra = { Vector3.new(-0, 2.45, -3.02), Vector3.new(6.4, 1.7, -3.02), Vector3.new(-6.4, 1.2, -3.02) } } },
		Portale = { centro = Vector3.new(-0, 11.988, 1), misure = Vector3.new(33, 23.975, 12.12), punti = { centro = { Vector3.new(-0, 12.2, 0) }, fuoco = { Vector3.new(14, 22.6, 1), Vector3.new(-14, 22.6, 1) } } },
		RastrellieraFucili = { centro = Vector3.new(-0, 4.455, -0.1), misure = Vector3.new(9.3, 8.91, 1.8), punti = {  } },
		RastrellieraLance = { centro = Vector3.new(-0, 5.35, -0.1), misure = Vector3.new(9.3, 10.7, 1.8), punti = {  } },
		RastrellieraSpade = { centro = Vector3.new(-0, 4.455, -0.1), misure = Vector3.new(9.3, 8.91, 1.8), punti = {  } },
		StemmaCornice = { centro = Vector3.new(-0, 0.6, -0.01), misure = Vector3.new(7.74, 8.94, 0.92), punti = {  } },
		StemmaDisco = { centro = Vector3.new(-0, 0, -0.225), misure = Vector3.new(6.6, 6.6, 0.65), punti = {  } },
		StendardoAsta = { centro = Vector3.new(-0, -7.576, -0.083), misure = Vector3.new(9.5, 16.352, 0.767), punti = {  } },
		StendardoTelo = { centro = Vector3.new(-0, -8, 0), misure = Vector3.new(6.5, 16, 0.585), punti = {  } },
		TavoloGuerra = { centro = Vector3.new(-0, 3.05, 0), misure = Vector3.new(62, 6.1, 62), punti = { misure_piano = { Vector3.new(-44, 0, 34) }, piano = { Vector3.new(-0, 5.6, 0) } } },
		Torcia = { centro = Vector3.new(-0, 0.739, -0.957), misure = Vector3.new(0.93, 2.978, 1.913), punti = { fuoco = { Vector3.new(-0, 2.298, -1.543) } } },
	},
}
