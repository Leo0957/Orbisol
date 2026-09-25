#!/usr/bin/env python3
"""Génère le masque terre/mer (grille 1° = 360x180) pour le widget « Jour · Nuit ».

Source : Natural Earth 110m (domaine public)
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson

Usage :
  python3 scripts/generate_worldmask.py /chemin/ne_110m_land.geojson > worldmask.b64

Le résultat est un base64 (bits MSB d'abord, ligne par ligne du pôle Nord au
pôle Sud, colonnes de 180°O à 180°E) prêt à être collé dans WorldMap.swift.
"""

import base64
import json
import sys


def collect_edges(features):
    """Découpe chaque anneau en segments (lon1,lat1)-(lon2,lat2) dans [-180,180)."""
    edges = []
    for feat in features:
        geom = feat.get("geometry")
        if not geom:
            continue
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            ring = poly[0]
            for i in range(len(ring) - 1):
                lon1, lat1 = ring[i][0], ring[i][1]
                lon2, lat2 = ring[i + 1][0], ring[i + 1][1]
                lon1 = ((lon1 + 180) % 360) - 180
                lon2 = ((lon2 + 180) % 360) - 180
                edges.append(((lon1, lat1), (lon2, lat2)))
    return edges


def rasterize(path, cols=360, rows=180):
    data = json.load(open(path))
    edges = collect_edges(data["features"])

    # Pour chaque ligne (latitude), les abscisses où des segments la traversent.
    crossings = [[] for _ in range(rows)]
    for (lon1, lat1), (lon2, lat2) in edges:
        lo, hi = min(lat1, lat2), max(lat1, lat2)
        for r in range(rows):
            lat_c = 90.0 - (r + 0.5)          # centre de la cellule
            if lo < lat_c < hi:
                t = (lat_c - lat1) / (lat2 - lat1)
                crossings[r].append(lon1 + t * (lon2 - lon1))

    # Remplissage pair-impair le long de chaque ligne.
    bits = []
    for r in range(rows):
        xs = sorted(crossings[r])
        entree = -180.0
        for i in range(0, len(xs) - 1, 2):
            de, fin = xs[i], xs[i + 1]
            c0 = int((de - (-180.0)) // (360.0 / cols))
            c1 = int((fin - (-180.0)) // (360.0 / cols))
            for c in range(max(0, c0), min(cols, c1 + 1)):
                if 0 <= c < cols:
                    bits.append((r, c))
        entree = entree  # (garde l'API stable)

    mask = [0] * ((rows * cols + 7) // 8)
    for r, c in bits:
        i = r * cols + c
        mask[i // 8] |= 1 << (i % 8)

    # Aperçu ASCII de contrôle (42 colonnes x 18 lignes).
    print("Aperçu (grossier) — '#' = terre :", file=sys.stderr)
    step_r = rows // 18 or 1
    step_c = cols // 42 or 1
    for r in range(0, rows, step_r):
        line = []
        for c in range(0, cols, step_c):
            i = r * cols + c
            line.append("#" if (mask[i // 8] >> (i % 8)) & 1 else ".")
        print("".join(line), file=sys.stderr)

    # Points de contrôle connus.
    def est_terre(lat, lon):
        r = int((90.0 - lat) // (180.0 / rows))
        c = int((lon + 180.0) // (360.0 / cols))
        if not (0 <= r < rows and 0 <= c < cols):
            return None
        i = r * cols + c
        return bool((mask[i // 8] >> (i % 8)) & 1)

    for nom, lat, lon, attendu in [
        ("Paris", 48.85, 2.35, True), ("New York", 40.71, -74.01, True),
        ("Los Angeles", 34.05, -118.24, True), ("Tokyo", 35.68, 139.69, True),
        ("Sydney", -33.87, 151.21, True), ("Delhi", 28.61, 77.21, True),
        ("Atlantique", 0.0, -30.0, False), ("Pacifique", 0.0, -150.0, False),
        ("Antarctique", -80.0, 0.0, True), ("Groenland", 72.0, -40.0, True),
        ("Madagascar", -19.0, 47.0, True), ("Londres", 51.5, -0.1, True),
    ]:
        ok = est_terre(lat, lon) == attendu
        print(f"{'OK ' if ok else 'ECHEC'} {nom}: {est_terre(lat, lon)} (attendu {attendu})",
              file=sys.stderr)

    return bytes(mask)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    mask = rasterize(sys.argv[1])
    b64 = base64.b64encode(mask).decode("ascii")
    # Pylint : rien à signaler, le flux est volontairement simple.
    print(b64)


if __name__ == "__main__":
    main()