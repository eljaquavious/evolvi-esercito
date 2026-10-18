"""Scrive src/shared/Config/AssetTruppe.luau dagli id caricati (assets-truppe/ids.json, da tools/carica-truppe.ps1)
e dalle misure scritte da esporta_fbx.py (assets-truppe/<Nome>/<Nome>.json). Solo libreria standard.

Uso: python tools/blocchi/asset_luau.py
"""
import json
import os

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CARTELLA = os.path.join(RADICE, "assets-truppe")


def main():
    ids = json.load(open(os.path.join(CARTELLA, "ids.json"), encoding="utf-8-sig"))
    righe = []
    for chiave in sorted(ids):
        if not chiave.endswith(".fbx"):
            continue
        nome = chiave[:-4]
        misure = json.load(open(os.path.join(CARTELLA, nome, nome + ".json")))
        c = misure["centro"]
        righe.append('\t%s = { id = %d, metri = %g, centro = Vector3.new(%.4f, %.4f, %.4f), basso = %.4f },'
                     % (nome, int(ids[chiave]), misure["metri"], c[0], c[1], c[2], misure["basso"]))
    testo = """-- Generato da tools/blocchi/asset_luau.py: non modificare a mano.
-- Modelli delle truppe caricati su Roblox come asset (MeshPart con Bone), da tools/blocchi/esporta_fbx.py.
-- id = asset del modello; metri = studs per metro; centro = centro della MeshPart rispetto ai piedi (studs);
-- basso = quanto scende il punto più basso sotto il centro.
return {
%s
}
""" % "\n".join(righe)
    percorso = os.path.join(RADICE, "src", "shared", "Config", "AssetTruppe.luau")
    open(percorso, "w", encoding="utf-8", newline="\n").write(testo)
    print(len(righe), "modelli in", percorso)


main()
