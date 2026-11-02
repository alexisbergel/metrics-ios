//
//  DateHelper.swift
//  Metrics
//

import Foundation

/// Point d'entrée unique pour convertir et afficher les dates de l'app.
///
/// - Produit les clés stockées en base : `dayKey` (yyyyMMdd) et clé de mois (yyyyMM).
/// - Calcule les clés voisines (ex. mois suivant) pour borner les requêtes par mois.
/// - Formate les mois pour l'affichage (ex. "Octobre 2026").
///
/// - Note: locale `fr_FR` et calendrier grégorien, quels que soient les réglages de l'appareil.
///   Déclaré en `enum` sans `case` : il ne peut pas être instancié.
enum DateHelper {

    /// Permets d'obtenir une date au format yyyyMMdd pour stocker le dayKey dans la BDD (ex: 20261031)
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyyMMdd"
        
        return formatter
    }()
    
    /// Clé de mois au format yyyyMM (ex: 202610)
    static func monthKey(for date: Date = Date()) -> Int32 {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Int32(components.year! * 100 + components.month!)
    }

    /// Clé du mois suivant (ex: 202612 → 202701)
    static func nextMonthKey(after monthKey: Int32) -> Int32 {
        let year = monthKey / 100
        let month = monthKey % 100
        return month == 12 ? (year + 1) * 100 + 1 : monthKey + 1
    }

    /// Permets d'obtenir une date au format "Octobre 2026" pour l'affichage du mois sélectionné
    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"

        return formatter
    }()

    /// Titre affichable pour une clé de mois (ex: 202610 → "Octobre 2026")
    static func monthTitle(forMonthKey monthKey: Int32) -> String {
        var components = DateComponents()
        components.year = Int(monthKey / 100)
        components.month = Int(monthKey % 100)
        components.day = 1

        guard let date = Calendar.current.date(from: components) else { return "" }
        return monthTitleFormatter.string(from: date).capitalized
    }
}
