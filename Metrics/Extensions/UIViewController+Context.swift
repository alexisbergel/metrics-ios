//
//  UIViewController+Context.swift
//  Metrics
//
//  Created by Alexis on 15/06/2022.
//

import Foundation
import UIKit
import CoreData

extension UIViewController {

    /// Contexte Core Data partagé par l'app : à utiliser directement pour les
    /// contrôleurs qui se contentent de lire/afficher des données.
    
    /// Pour un contrôleur dont la logique métier doit être testable en isolation,
    /// redéclarez plutôt une propriété stockée avec un nom différent (ex.
    /// `managedObjectContext`, Swift interdit de réutiliser `context`), initialisée
    /// avec `sharedViewContext()` ci-dessous : elle reste injectable par un test,
    /// sans rien changer pour les contrôleurs qui utilisent ce `context` par défaut.
    var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }

    func saveContext() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.saveContext()
    }

    /// Valeur par défaut pour les propriétés de contexte redéclarées (voir `context` ci-dessus).
    static func sharedViewContext() -> NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
}
