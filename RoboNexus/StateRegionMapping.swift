//
//  StateRegionMapping.swift
//
//  ADC Hub
//
//  Created by Skyler Clagg on 10/03/24.
//

import Foundation

struct StateRegionMapping {
    
    // Define the regions and their corresponding states/provinces (for ADC)
    static let regionToStatesMap: [String: [String]] = [
        "Northeast": [
            "Connecticut", "Delaware", "District of Columbia", "Kentucky", "Maryland", "Massachusetts",
            "Maine", "New Hampshire", "New Jersey", "New York", "Pennsylvania", "Rhode Island", "Vermont",
            "Virginia", "West Virginia",
            "Quebec", "Newfoundland and Labrador", "New Brunswick", "Prince Edward Island", "Nova Scotia"
        ],
        "North Central": [
            "Illinois", "Indiana", "Iowa", "Michigan", "Minnesota", "Nebraska", "North Dakota", "Ohio",
            "South Dakota", "Wisconsin",
            "Manitoba", "Ontario", "Nunavut"
        ],
        "Southeast": [
            "Alabama", "Arkansas", "Florida", "Georgia", "Louisiana", "Mississippi", "North Carolina",
            "South Carolina", "Tennessee"
        ],
        "South Central": [
            "Kansas", "Missouri", "New Mexico", "Oklahoma", "Texas"
        ],
        "West": [
            "Alaska", "American Samoa", "Arizona", "California", "Colorado", "Hawaii", "Idaho", "Montana",
            "Nevada", "Oregon", "Utah", "Washington", "Wyoming",
            "British Columbia", "Alberta", "Saskatchewan", "Yukon", "Northwest Territories"
        ],
        "International": [
            "Greece", "Kuwait", "Mexico", "Singapore"
        ]
    ]
    
    // Invert the mapping to create a State-to-Region dictionary
    static let stateToRegionMap: [String: String] = {
        var map = [String: String]()
        for (region, states) in regionToStatesMap {
            for state in states {
                map[state] = region
            }
        }
        return map
    }()
    
    // Map for state/province name variations
    static let stateNameVariations: [String: String] = [
        "DC": "District of Columbia",
        "Washington, D.C.": "District of Columbia",
        "Newfoundland": "Newfoundland and Labrador",
        "NWT": "Northwest Territories",
        "Yukon Territory": "Yukon"
        // Add more variations as needed
    ]
    
    
    /// Original function in case something else in your app relies on it.
    /// Uses `teamRegion` for ADC, `eventRegion` for others.
    static func getRegion(for program: String, eventRegion: String?, teamRegion: String?) -> String {
        // If the app is ADCHub, this might still rely on team.region by default:
        if program == "ADC" || program == "Aerial Drone Competition" {
            let regionValue = teamRegion ?? ""
            let normalized = stateNameVariations[regionValue] ?? regionValue
            return stateToRegionMap[normalized] ?? normalized
        } else {
            // For non‑ADC, default logic:
            return eventRegion ?? (teamRegion ?? "Unknown Region")
        }
    }
    
    
    // MARK: - NEW: getRegionForADC

    static func getRegionForADC(eventRegion: String?) -> String {
 
        let regionValue = eventRegion ?? ""

        return regionValue
    
    }
}
