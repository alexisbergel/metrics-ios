//
//  AppDelegate.swift
//  Metrics
//
//  Created by Alexis on 28/05/2022.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {

    private let centsStoreResetKey = "didResetStoreForCentsModelV1"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        resetStoreForCentsModelIfNeeded()

        return true
    }

    private func resetStoreForCentsModelIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: centsStoreResetKey) else { return }

        let storeURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("Metrics.sqlite")
        let storeFiles = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        do {
            for storeFile in storeFiles where FileManager.default.fileExists(atPath: storeFile.path) {
                try FileManager.default.removeItem(at: storeFile)
            }
            UserDefaults.standard.set(true, forKey: centsStoreResetKey)
        } catch {
            print("Unable to reset the previous Core Data store: \(error)")
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        
        let container = NSPersistentContainer(name: "Metrics")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        return container
    }()
    
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}


// MARK: - Settings

// 1. Orientation bloquée en mode portrait
// 2. Dark Mode désactivé
