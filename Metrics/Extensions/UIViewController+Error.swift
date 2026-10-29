//
//  UIViewController+Error.swift
//  Metrics
//

import UIKit

extension UIViewController {

    /// Affiche une alerte avec la description de l'erreur.
    /// Pour une `LocalizedError` (ex. `DataManagerError`), le message vient de `errorDescription`.
    func presentError(_ error: Error, title: String = "Une erreur est survenue") {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
