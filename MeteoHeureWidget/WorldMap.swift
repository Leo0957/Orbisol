import Foundation
import Compression

/// Masque terre/mer du monde entier (grille 1° : 360 colonnes x 180 lignes).
///
/// Généré depuis Natural Earth 110m (domaine public) par
/// `scripts/generate_worldmask.py`, compressé en zlib puis base64.
/// La première lecture décompresse une seule fois en mémoire.
enum WorldMap {

    static let cols = 360
    static let rows = 180

    /// Base64 (zlib) du masque : bit i = ligne (i / cols), colonne (i % cols),
    /// ligne 0 = pôle Nord, colonne 0 = 180° O.
    private static let encoded = "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"

    /// Bits décompressés (une seule fois, à la première lecture).
    private static let landBits: [Bool] = {
        guard let data = Data(base64Encoded: encoded),
              let inflated = Self.inflate(data) else { return [] }
        var bits = [Bool](repeating: false, count: cols * rows)
        let byteCount = min(inflated.count, (cols * rows + 7) / 8)
        for byteIndex in 0..<byteCount {
            let byte = inflated[inflated.startIndex + byteIndex]
            for bit in 0..<8 {
                let index = byteIndex * 8 + bit
                if index < cols * rows {
                    bits[index] = (byte >> UInt8(bit)) & 1 == 1
                }
            }
        }
        return bits
    }()

    /// Vrai si le point (latitude, longitude) est sur la terre ferme.
    static func isLand(latitude: Double, longitude: Double) -> Bool {
        let row = Int(((90.0 - latitude) / 180.0 * Double(rows)).rounded(.down))
        var col = Int(((longitude + 180.0) / 360.0 * Double(cols)).rounded(.down))
        col = (col + cols) % cols // tolérance autour de l'antiméridien
        guard row >= 0, row < rows else { return false }
        return landBits[row * cols + col]
    }

    // MARK: - Points de terre prêts à dessiner

    /// Grille des terres émergées (pas de 1°) pré-calculée une seule fois :
    /// les latitudes vont du pôle Nord au pôle Sud, les longitudes de 180° O à 180° E.
    /// Évite de re-tester le masque bit à bit à chaque rendu Canvas.
    static let landPoints: [(lat: Double, lon: Double)] = {
        var points: [(lat: Double, lon: Double)] = []
        points.reserveCapacity(cols * rows / 3)
        var lat = 89.5
        while lat > -89.5 {
            var lon = -179.5
            while lon < 180.0 {
                if isLand(latitude: lat, longitude: lon) {
                    points.append((lat, lon))
                }
                lon += 1.0
            }
            lat -= 1.0
        }
        return points
    }()

    // MARK: - Décompression zlib (Compression.framework)

    private static func inflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = cols * rows / 8 + 64
        var output = [UInt8](repeating: 0, count: capacity)
        let result = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return output.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
                guard let dstPtr = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dstPtr, capacity, srcPtr, data.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        return result > 0 ? Data(output[0..<result]) : nil
    }
}