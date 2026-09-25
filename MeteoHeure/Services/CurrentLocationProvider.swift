import Foundation
import CoreLocation

// MARK: - Fournisseur de position
//
// Petit pont async/await au-dessus de CoreLocation :
// la demande d'autorisation et la localisation sont exposées
// par une seule méthode `request()` qui lève une erreur en cas de refus.

final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Obtient une position (autorisation demandée automatiquement).
    func request() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let status = manager.authorizationStatus
            switch status {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                continuation.resume(throwing: LocationError.denied)
                self.continuation = nil
            @unknown default:
                continuation.resume(throwing: LocationError.denied)
                self.continuation = nil
            }
        }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    private func fail(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            fail(LocationError.denied)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate else { return }
        finish(coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail(error)
    }
}

/// Erreurs « friendly » pour l'écran utilisateur.
enum LocationError: LocalizedError {
    case denied
    case unknown

    var errorDescription: String? {
        switch self {
        case .denied:
            return "L'accès à votre position est refusé. Autorisez-le dans Réglages > Confidentialité > Localisation."
        case .unknown:
            return "Impossible d'obtenir votre position pour le moment."
        }
    }
}
