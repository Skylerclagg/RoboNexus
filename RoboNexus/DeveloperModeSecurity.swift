//
//  DeveloperModeSecurity.swift
//  RoboNexus
//
//  Created by Skyler Clagg on 4/14/25.
//

import SwiftUI
import CryptoKit

// Helper function to generate a SHA-256 hash for a given string.
func hashString(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// Replace the value below with the hash of your chosen secret (e.g. "Learning1").
// You should compute this hash using a playground or another tool.
private let validDevCodeHash = "ec7a1425f5c313b93e6b5b66978130a1f92b2e5bdfcaa52013de0d568094336e"

// Function to validate an entered code.
func isValidDeveloperCode(_ code: String) -> Bool {
    return hashString(code) == validDevCodeHash
}
