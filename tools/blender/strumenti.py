"""Aiuti per lavorare sui modelli da remoto (MCP di Blender): costruire e esportare un'unità, foto multiple.

Dopo un riavvio di Blender (driver_namespace vuoto) si ridefinisce carica_moduli (vedi la memoria del
progetto) e poi:
    carica_moduli(sha, "umano", "legionario", "vestiti", "cavallo", "strumenti")["strumenti"].installa()
che rimette in driver_namespace "ciclo" e "foto_multi".
"""

import base64
import os
import sys
import tempfile
import time
import traceback

import bpy
import numpy as np


def foto_multi(viste, larghezza=600, altezza=800, bersaglio=(0.05, 0, 1.0), distanza=4.6, qualita=88):
    """Più viste (azimut, elevazione) affiancate in un JPEG, restituito in base64 (con un riempitivo che
    fa finire il risultato in un file, da decodificare con jq + base64)."""
    V = sys.modules["vestiti"]
    L = sys.modules["legionario"]
    sc = bpy.context.scene
    L.studio(larghezza, altezza)
    sc.render.image_settings.file_format = "PNG"
    d = tempfile.gettempdir()
    pezzi = []
    for i, (az, el) in enumerate(viste):
        p = os.path.join(d, "vista_%d.png" % i)
        V.foto(p, azimut=az, elevazione=el, distanza=distanza, bersaglio=bersaglio)
        img = bpy.data.images.load(p)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        pezzi.append(a)
        bpy.data.images.remove(img)
    tot = np.concatenate(pezzi, axis=1)
    h, w = tot.shape[:2]
    out = bpy.data.images.new("_multi", w, h, alpha=True)
    out.pixels.foreach_set(tot.ravel())
    out.file_format = "JPEG"
    p = os.path.join(d, "multi.jpg")
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = qualita
    out.save_render(p, scene=sc)
    bpy.data.images.remove(out)
    b = base64.b64encode(open(p, "rb").read()).decode()
    return {"img": b, "pad": "." * max(0, 110000 - len(b))}


def ciclo(sha, modulo, esporta=True):
    """Scarica vestiti, esporta e il modulo dell'unità al commit sha, costruisce e (se esporta) fa la
    versione da gioco "Gioco" con la texture cotta."""
    t = time.time()
    try:
        M = bpy.app.driver_namespace["carica_moduli"](sha, "vestiti", "esporta", modulo)[modulo]
        r = M.costruisci()
        if esporta:
            m = bpy.data.materials.get("Gioco_Cottura")
            if m:
                for l in list(m.node_tree.links):
                    if l.from_node.name == "Cottura":
                        m.node_tree.links.remove(l)
            e = M.esporta()
            g = bpy.data.objects["Gioco"]
            g.location.x = 1.2
            nt = g.data.materials[0].node_tree
            nt.links.new(nt.nodes["Cottura"].outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
            g.hide_render = False
            r.update({"gioco": e["triangoli"], "vertici": e["vertici"], "pezzi": e["pezzi"]})
    except Exception:
        r = {"errore": traceback.format_exc()[-2500:]}
    r["s"] = time.time() - t
    return r


def solo(nome):
    """Nasconde nei render tutte le altre unità e la vecchia versione da gioco."""
    for c in bpy.data.collections:
        if c.name not in ("Studio", "Collection", "CavalloBase"):
            c.hide_render = c.name != nome
            c.hide_viewport = c.name != nome
    g = bpy.data.objects.get("Gioco")
    if g:
        g.hide_render = True
        g.hide_viewport = True


def installa():
    ns = bpy.app.driver_namespace
    ns["foto_multi"] = foto_multi
    ns["ciclo"] = ciclo
    ns["solo"] = solo
    return True
