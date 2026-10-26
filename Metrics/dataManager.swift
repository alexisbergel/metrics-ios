//
//  dataManager.swift
//  Metrics
//
//  Created by Alexis on 23/10/2022.
//

import UIKit
import CoreData

final class dataManager {

    static let sharedInstance = dataManager()
    static let tagsDidChangeNotification = Notification.Name("dataManager.tagsDidChange")

    private(set) var tags: [Tag] = []

    var context: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }

    private init() {
        do {
            try reloadTags()
        } catch {
            print("Could not fetch tags. \(error.localizedDescription)")
        }
    }

    func reloadTags() throws {
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.name), ascending: true)]

        tags = try context.fetch(fetchRequest)
    }

    @discardableResult
    func addTag(name: String) throws -> Tag {
        let newTag = Tag(context: context)
        newTag.name = name

        try saveTagsAndRefreshCache()
        return newTag
    }

    func updateTag(_ tag: Tag, name: String) throws {
        tag.name = name
        try saveTagsAndRefreshCache()
    }

    func deleteTag(_ tag: Tag) throws {
        context.delete(tag)

        try saveTagsAndRefreshCache()
    }

    private func saveTagsAndRefreshCache() throws {
        do {
            try context.save()
            try reloadTags()
            NotificationCenter.default.post(name: Self.tagsDidChangeNotification, object: nil)
        } catch {
            context.rollback()
            throw error
        }
    }
}
