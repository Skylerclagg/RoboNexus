//
//  DeveloperModeSecurity.swift
//  RoboNexus
//
//  Created by Skyler Clagg on 4/14/25.
//

import Foundation
import CryptoKit

// MARK: - Developer Security Helpers

// Replace these hash strings with the SHA‑256 hashes of your valid developer codes.
private let validDevCodeHashes: [String] = [
    "ec7a1425f5c313b93e6b5b66978130a1f92b2e5bdfcaa52013de0d568094336e", // (Learning1)
    "1e7f5f3f24c25a6d647ccfd84799491d11e6bc09433fba5270a4ad363e6111a6", // (WVRobotics)
]

// Function to compute the SHA‑256 hash of a given string.
public func hashString(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// Function to check if the entered developer code is valid.
public func isValidDeveloperCode(_ code: String) -> Bool {
    let codeHash = hashString(code)
    // Check if the generated hash matches any valid hash.
    return validDevCodeHashes.contains(codeHash)
}
