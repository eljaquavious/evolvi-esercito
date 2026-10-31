"""Scrive src/shared/Config/AssetLobby.luau da assets-lobby/oggetti.json (tools/blender/lobby.py) e dall'id
del modello caricato (assets-truppe/ids.json, chiave OggettiLobby.fbx).

Uso: python tools/lobby_luau.py
"""
import json
import os

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def v3(v):
    return "Vector3.new(%s)" % ", ".join(("%.3f" % x).rstrip("0").rstrip(".") or "0" for x in v)


def main():
    with open(os.path.join(RADICE, "assets-lobby", "oggetti.json"), encoding="utf-8") as f:
        oggetti = json.load(f)
    with open(os.path.join(RADICE, "assets-truppe", "ids.json"), encoding="utf-8-sig") as f:
        ids = json.load(f)
    righe = [
        "-- Oggetti della lobby fatti in Blender (tools/blender/lobby.py), caricati con tools/carica-truppe.ps1",
        "-- -Prefisso \"EYA lobby\". File generato da tools/lobby_luau.py: non modificarlo a mano.",
        "-- Un Model con una MeshPart per oggetto. Per ogni oggetto, in studs e negli assi di Roblox, rispetto alla sua",
        "-- origine (il punto d'appoggio; davanti verso -Z): centro dell'ingombro (= MeshPart.Position), misure e",
        "-- punti dove il gioco mette fuochi, luci e scritte.",
        "",
        "return {",
        "\tid = %s," % ids["OggettiLobby.fbx"],
        "\toggetti = {",
    ]
    for nome in sorted(oggetti):
        o = oggetti[nome]
        punti = ", ".join("%s = { %s }" % (k, ", ".join(v3(p) for p in vs)) for k, vs in sorted(o["punti"].items()))
        righe.append("\t\t%s = { centro = %s, misure = %s, punti = { %s } }," % (nome, v3(o["centro"]), v3(o["misure"]), punti))
    righe += ["\t},", "}", ""]
    with open(os.path.join(RADICE, "src", "shared", "Config", "AssetLobby.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(righe))
    print(len(oggetti), "oggetti")


main()
