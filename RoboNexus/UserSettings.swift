//
//  UserSettings.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import Foundation
import SwiftUI

let defaults = UserDefaults.standard

public extension UIColor {
    class func StringFromUIColor(color: UIColor) -> String {
        var components = color.cgColor.components
        while (components!.count < 4) {
            components!.append(1.0)
        }
        return "[\(components![0]), \(components![1]), \(components![2]), \(components![3])]"
    }
    
    class func UIColorFromString(string: String) -> UIColor {
        let componentsString = string
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        let components = componentsString.components(separatedBy: ", ")
        return UIColor(
            red: CGFloat((components[0] as NSString).floatValue),
            green: CGFloat((components[1] as NSString).floatValue),
            blue: CGFloat((components[2] as NSString).floatValue),
            alpha: CGFloat((components[3] as NSString).floatValue)
        )
    }
}

func getGreen() -> UIColor {
    #if os(iOS)
    return .systemGreen
    #else
    return .green
    #endif
}

class UserSettings: ObservableObject {
    
    // ==============================
    // NEW: Toggleable Haptics
    // ==============================
    @Published var enableHaptics = false  // Default OFF
    
    
    @Published var allAroundEligibilityFeaturesEnabled: Bool = defaults.bool(forKey: "allAroundEligibilityFeaturesEnabled") {
        didSet {
            // Save the new value every time it changes.
            defaults.set(allAroundEligibilityFeaturesEnabled, forKey: "allAroundEligibilityFeaturesEnabled")
        }
    }
    
    @Published var testingEligibilityFeaturesEnabled: Bool = defaults.bool(forKey: "testingEligibilityFeaturesEnabled") {
        didSet {
            defaults.set(testingEligibilityFeaturesEnabled, forKey: "testingEligibilityFeaturesEnabled")
        }
    }
    private var buttonColorString: String
    private var topBarColorString: String
    private var topBarContentColorString: String
    private var minimalistic: Bool
    private var adam_score: Bool
    private var grade_level: String
    private var team_info_default_page: String
    private var match_team_default_page: String
    private var selected_season_id: Int
    // Mark dateFilter as @Published so UI updates when it changes.
    @Published private var dateFilter: Int
    
    // ==============================
    // NEW: Program Selection
    // ==============================
    @Published var selectedProgram: String
    
    static var keyIndex = Int.random(in: 0..<10)
    
    init() {
        // Initialize the new property from UserDefaults.
        // If no value exists, the default will be false.
        self.allAroundEligibilityFeaturesEnabled = defaults.bool(forKey: "allAroundEligibilityFeaturesEnabled")
        
        // Initialize colors and other settings from defaults or fall back to defaults.
        self.buttonColorString = defaults.object(forKey: "buttonColor") as? String
            ?? UIColor.StringFromUIColor(color: getGreen())
        self.topBarColorString = defaults.object(forKey: "topBarColor") as? String
            ?? UIColor.StringFromUIColor(color: getGreen())
        
        let storedMinimalistic = defaults.object(forKey: "minimalistic") as? Int ?? 0
        self.minimalistic = storedMinimalistic == 1
        
        self.topBarContentColorString = defaults.object(forKey: "topBarContentColor") as? String
            ?? UIColor.StringFromUIColor(color: self.minimalistic ? getGreen() : .white)
        
        let storedAdam = defaults.object(forKey: "adam_score") as? Int ?? 1
        self.adam_score = storedAdam == 1
        
        self.grade_level = defaults.object(forKey: "grade_level") as? String ?? "High School"
        self.team_info_default_page = defaults.object(forKey: "team_info_default_page") as? String ?? "events"
        self.match_team_default_page = defaults.object(forKey: "match_team_default_page") as? String ?? "matches"
        self.selected_season_id = defaults.object(forKey: "selected_season_id") as? Int
            ?? API.active_season_id()
        
        // NEW: Initialize the selected program.
        self.selectedProgram = defaults.object(forKey: "selectedProgram") as? String ?? "Aerial Drone Competition"
        
        // NEW: Read haptics toggle from UserDefaults.
        self.enableHaptics = defaults.bool(forKey: "enableHaptics")
        // Updated dateFilter is now published.
        self.dateFilter = defaults.object(forKey: "dateFilter") as? Int ?? -7
    }
    
    func readUserDefaults() {
        self.buttonColorString = defaults.object(forKey: "buttonColor") as? String
            ?? UIColor.StringFromUIColor(color: getGreen())
        
        self.topBarColorString = defaults.object(forKey: "topBarColor") as? String
            ?? UIColor.StringFromUIColor(color: getGreen())
        
        let storedMinimalistic = defaults.object(forKey: "minimalistic") as? Int ?? 0
        self.minimalistic = storedMinimalistic == 1
        
        self.topBarContentColorString = defaults.object(forKey: "topBarContentColor") as? String
            ?? UIColor.StringFromUIColor(color: self.minimalistic ? getGreen() : .white)
        
        self.grade_level = defaults.object(forKey: "grade_level") as? String ?? "High School"
        self.team_info_default_page = defaults.object(forKey: "team_info_default_page") as? String ?? "events"
        self.match_team_default_page = defaults.object(forKey: "match_team_default_page") as? String ?? "matches"
        self.selected_season_id = defaults.object(forKey: "selected_season_id") as? Int
            ?? API.selected_season_id()
        
        // NEW: Re-read the selected program.
        self.selectedProgram = defaults.object(forKey: "selectedProgram") as? String ?? "Aerial Drone Competition"
        
        // NEW: Re-read haptics setting.
        self.enableHaptics = defaults.bool(forKey: "enableHaptics")
        self.dateFilter = defaults.integer(forKey: "dateFilter")
        
        // NEW: Re-read the All Around Eligibility toggle.
        self.allAroundEligibilityFeaturesEnabled = defaults.bool(forKey: "allAroundEligibilityFeaturesEnabled")
    }
    
    func updateUserDefaults(updateTopBarContentColor: Bool = false) {
        defaults.set(
            UIColor.StringFromUIColor(color: UIColor.UIColorFromString(string: self.buttonColorString)),
            forKey: "buttonColor"
        )
        defaults.set(
            UIColor.StringFromUIColor(color: UIColor.UIColorFromString(string: self.topBarColorString)),
            forKey: "topBarColor"
        )
        if updateTopBarContentColor {
            defaults.set(
                UIColor.StringFromUIColor(color: UIColor.UIColorFromString(string: self.topBarContentColorString)),
                forKey: "topBarContentColor"
            )
        }
        defaults.set(self.minimalistic ? 1 : 0, forKey: "minimalistic")
        defaults.set(self.grade_level, forKey: "grade_level")
        defaults.set(self.team_info_default_page, forKey: "team_info_default_page")
        defaults.set(self.match_team_default_page, forKey: "match_team_default_page")
        defaults.set(self.selected_season_id, forKey: "selected_season_id")
        
        // NEW: Persist the selected program.
        defaults.set(self.selectedProgram, forKey: "selectedProgram")
        
        // NEW: Persist haptics setting.
        defaults.set(self.enableHaptics, forKey: "enableHaptics")
        defaults.set(self.dateFilter, forKey: "dateFilter")
        
        // NEW: Persist the All Around Eligibility toggle.
        defaults.set(self.allAroundEligibilityFeaturesEnabled, forKey: "allAroundEligibilityFeaturesEnabled")
    }
    
    // MARK: - Setters
    func setDateFilter(dateFilter: Int) {
        self.dateFilter = dateFilter
        updateUserDefaults()  // Persist the change
    }
    
    func setButtonColor(color: SwiftUI.Color) {
        self.buttonColorString = UIColor.StringFromUIColor(color: UIColor(color))
    }
    
    func setTopBarColor(color: SwiftUI.Color) {
        self.topBarColorString = UIColor.StringFromUIColor(color: UIColor(color))
    }
    
    func setTopBarContentColor(color: SwiftUI.Color) {
        self.topBarContentColorString = UIColor.StringFromUIColor(color: UIColor(color))
    }
    
    func setMinimalistic(state: Bool) {
        self.minimalistic = state
    }
    
    func setGradeLevel(grade_level: String) {
        self.grade_level = grade_level
        API.populate_all_world_skills_caches()
    }
    
    func setTeamInfoDefaultPage(page: String) {
        self.team_info_default_page = page
    }
    
    func setMatchTeamDefaultPage(page: String) {
        self.match_team_default_page = page
    }
    
    func setSelectedSeasonID(id: Int) {
        self.selected_season_id = id
    }
    
    // NEW: Program Setter
    func setSelectedProgram(program: String) {
        self.selectedProgram = program
        defaults.set(program, forKey: "selectedProgram")
    }
    
    // MARK: - Getters
    
    func buttonColor() -> SwiftUI.Color {
        if let colorString = defaults.object(forKey: "buttonColor") as? String {
            return Color(UIColor.UIColorFromString(string: colorString))
        } else {
            return Color(getGreen())
        }
    }
    
    func topBarColor() -> SwiftUI.Color {
        if let colorString = defaults.object(forKey: "topBarColor") as? String {
            return Color(UIColor.UIColorFromString(string: colorString))
        } else {
            return Color(getGreen())
        }
    }
    
    func topBarContentColor() -> SwiftUI.Color {
        if let colorString = defaults.object(forKey: "topBarContentColor") as? String {
            let color = Color(UIColor.UIColorFromString(string: colorString))
            return color != topBarColor() ? color : Color.white
        } else {
            if UserSettings.getMinimalistic() {
                return Color(getGreen())
            } else {
                return Color.white
            }
        }
    }
    
    func tabColor() -> SwiftUI.Color {
        if defaults.object(forKey: "minimalistic") as? Int ?? 1 == 1 {
            return Color(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0))
        } else {
            return self.topBarColor()
        }
    }
    
    func getDateFilter() -> Int {
        return self.dateFilter
    }
    
    // MARK: - Static Getters
    
    static func getRobotEventsAPIKey() -> String? {
        var robotevents_api_key: String? {
            if let environmentAPIKey = ProcessInfo.processInfo.environment["ROBOTEVENTS_API_KEY"] {
                defaults.set(environmentAPIKey, forKey: "robotevents_api_key")
                return environmentAPIKey
            } else if let defaultsAPIKey = defaults.object(forKey: "robotevents_api_key") as? String,
                      !defaultsAPIKey.isEmpty {
                return defaultsAPIKey
            } else if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
                      let config = NSDictionary(contentsOfFile: path) as? [String: Any] {
                return config["key\(self.keyIndex)"] as? String
            }
            return nil
        }
        return robotevents_api_key
    }
    
    static func getMinimalistic() -> Bool {
        return defaults.object(forKey: "minimalistic") as? Int ?? 0 == 1
    }
    
    static func getDateFilter() -> Int {
        return defaults.object(forKey: "dateFilter") as? Int ?? -7
    }
    
    static func getGradeLevel() -> String {
        return defaults.object(forKey: "grade_level") as? String ?? "High School"
    }
    
    static func getTeamInfoDefaultPage() -> String {
        return defaults.object(forKey: "team_info_default_page") as? String ?? "events"
    }
    
    static func getMatchTeamDefaultPage() -> String {
        return defaults.object(forKey: "match_team_default_page") as? String ?? "matches"
    }
    
    static func getSelectedSeasonID() -> Int {
        return defaults.object(forKey: "selected_season_id") as? Int ?? API.selected_season_id()
    }
    
    // NEW: Static getter for selected program.
    static func getSelectedProgram() -> String? {
        let devMode = defaults.bool(forKey: "DeveloperModeEnabled")
        if let stored = defaults.object(forKey: "selectedProgram") as? String {
            if stored == ProgramType.adc.rawValue && !devMode {
                return ProgramType.selectableCases.first?.rawValue
            }
            return stored
        }
        return ProgramType.selectableCases.first?.rawValue
    }
}
