//
//  FirestoreProvider.swift
//  Axolotls
//
//  Created by Anabella Arzate on 11/4/26.
//

import FirebaseFirestore

extension Firestore {
    static var app: Firestore {
        Firestore.firestore(database: "afterglow")
    }
}
