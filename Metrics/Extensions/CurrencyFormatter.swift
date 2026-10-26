//
//  CurrencyFormatter.swift
//  Metrics
//

import Foundation

/// Formate les montants stockés en centimes sans utiliser de nombres à virgule flottante.
enum CurrencyFormatter {
    
    /// Convertit un montant en centimes pour l'afficher en euros.
    /// - Parameter includesCurrencySymbol: Ajoute le symbole euro hors des champs de saisie.
    static func string(from cents: Int64, includesCurrencySymbol: Bool = true) -> String {
        let isNegative = cents < 0
        // `magnitude` évite un dépassement avec la plus petite valeur Int64.
        let absoluteCents = cents.magnitude
        let euros = absoluteCents / 100
        let remainingCents = absoluteCents % 100
        let sign = isNegative ? "-" : ""
        let currencySymbol = includesCurrencySymbol ? " €" : ""

        /// Les centimes sont toujours affichés sur deux chiffres : 5 devient 05.
        return "\(sign)\(euros),\(String(format: "%02llu", remainingCents))\(currencySymbol)"
    }
}
