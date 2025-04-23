import SwiftUI

// MARK: - ProgramType Enum
// Your four supported programs.
enum ProgramType: String, CaseIterable, Identifiable {
    case adc = "Aerial Drone Competition"
    case viqrc = "VEX IQ Robotics Competition"
    case v5rc = "VEX V5 Robotics Competition"
    case vurc = "VEX U Robotics Competition"
    case vairc = "VEX AI Robotics Competition"
    
    var id: String { self.rawValue }
    var displayName: String { self.rawValue }
}

// MARK: - CompetitionFormat Enum
// Represents the competition structure.
enum CompetitionFormat {
    // Cooperative: teams work together (e.g., 2 teams working together)
    case cooperative(teamsPerAlliance: Int, ageLevels: [String])
    // Alliances: competing alliances (e.g., 2 teams per alliance or 1v1)
    case alliances(teamsPerAlliance: Int, ageLevels: [String])
}

// MARK: - ProgramTheme Struct
// Contains the primary (theme) color and content colors for light and dark modes.
struct ProgramTheme {
    let primaryColor: Color         // The main color (e.g., Green, Blue, or Red)
    let lightContentColor: Color    // Content color in light mode (usually white)
    let darkContentColor: Color     // Content color in dark mode (usually black)
}

// MARK: - ProgramConfig Struct
// Bundles together the theme, bottom bar options, and competition format.
struct ProgramConfig {
    let theme: ProgramTheme
    let bottomBarOptions: [String]
    let competitionFormat: CompetitionFormat
}

// MARK: - ConfigManager Class
// This class manages the current program and its configuration.
class ConfigManager: ObservableObject {
    @Published var currentProgram: ProgramType
    @Published var currentConfig: ProgramConfig

    init() {
        // Use a local variable to initialize currentProgram first.
        let defaultProgram: ProgramType = .adc  // Default to ADC (Aerial Drone Competition)
        self.currentProgram = defaultProgram
        self.currentConfig = ConfigManager.config(for: defaultProgram)
    }
    
    // Returns a configuration for the given program.
    static func config(for program: ProgramType) -> ProgramConfig {
        switch program {
        case .adc:
            // ADC: Theme 1 (Green primary; light mode: white content, dark mode: black content)
            let theme = ProgramTheme(primaryColor: Color.green,
                                     lightContentColor: Color.white,
                                     darkContentColor: Color.black)
            // Full bottom bar options.
            let bottomBar = ["Home", "Matches", "Events", "Game Manual", "Calculators", "Settings"]
            // Competition format: cooperative (2 teams working together) for High and Middle School.
            let compFormat = CompetitionFormat.cooperative(teamsPerAlliance: 2, ageLevels: ["High School", "Middle School"])
            return ProgramConfig(theme: theme, bottomBarOptions: bottomBar, competitionFormat: compFormat)
            
        case .viqrc:
            // VIQRC: Theme 2 (Blue primary; light mode: white content, dark mode: black content)
            let theme = ProgramTheme(primaryColor: Color.blue,
                                     lightContentColor: Color.white,
                                     darkContentColor: Color.black)
            // Fewer bottom bar options (omit "Game Manual" and "Calculators").
            let bottomBar = ["Home", "Matches", "Events", "Settings"]
            // Competition format: cooperative (2 teams working together) for Elementary and Middle School.
            let compFormat = CompetitionFormat.cooperative(teamsPerAlliance: 2, ageLevels: ["Elementary", "Middle School"])
            return ProgramConfig(theme: theme, bottomBarOptions: bottomBar, competitionFormat: compFormat)
            
        case .v5rc:
            // V5RC: Theme 3 (Red primary; light mode: white content, dark mode: black content)
            let theme = ProgramTheme(primaryColor: Color.red,
                                     lightContentColor: Color.white,
                                     darkContentColor: Color.black)
            // Fewer bottom bar options.
            let bottomBar = ["Home", "Matches", "Events", "Settings"]
            // Competition format: alliances (2 teams per alliance) for Middle and High School.
            let compFormat = CompetitionFormat.alliances(teamsPerAlliance: 2, ageLevels: ["Middle School", "High School"])
            return ProgramConfig(theme: theme, bottomBarOptions: bottomBar, competitionFormat: compFormat)
            
        case .vurc:
            // VURC: Also uses Theme 3 (Red primary; light mode: white content, dark mode: black content)
            let theme = ProgramTheme(primaryColor: Color.red,
                                     lightContentColor: Color.white,
                                     darkContentColor: Color.black)
            // Fewer bottom bar options.
            let bottomBar = ["Home", "Matches", "Events", "Settings"]
            // Competition format: alliances (1 team per alliance, head-to-head) for College.
            let compFormat = CompetitionFormat.alliances(teamsPerAlliance: 1, ageLevels: ["College"])
            return ProgramConfig(theme: theme, bottomBarOptions: bottomBar, competitionFormat: compFormat)
        case .vairc:
            let theme = ProgramTheme(primaryColor: Color.red,
                                     lightContentColor: Color.white,
                                     darkContentColor: Color.black)
            // Fewer bottom bar options.
            let bottomBar = ["Home", "Matches", "Events", "Settings"]
            // Competition format: alliances (1 team per alliance, head-to-head) for College.
            let compFormat = CompetitionFormat.alliances(teamsPerAlliance: 1, ageLevels: ["High School","College"])
            return ProgramConfig(theme: theme, bottomBarOptions: bottomBar, competitionFormat: compFormat)
        }
    }
    
    // Updates the current program and configuration.
    func updateProgram(to newProgram: ProgramType) {
        self.currentProgram = newProgram
        self.currentConfig = ConfigManager.config(for: newProgram)
    }
}
