//
//  ProgramSelectionPopup.swift
//  RoboNexus
//
//  Created by Skyler Clagg on 6/21/25.
//

import SwiftUI

// MARK: - ProgramSelectionPopup View

struct ProgramSelectionPopup: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var eventSearch: EventSearch

    @Binding var isPresented: Bool
    @State private var selectedProgram: ProgramType

    // Initialize selectedProgram with your existing logic
    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _selectedProgram = State(initialValue: {
            let developerModeEnabled = UserDefaults.standard.bool(forKey: "DeveloperModeEnabled")
            
            if let stored = UserSettings.getSelectedProgram(),
               let prog = ProgramType(rawValue: stored) {
                // If stored program is ADC and developer mode is OFF,
                // fallback to the first selectable case (likely VIQRC)
                if prog == .adc && !developerModeEnabled {
                    return ProgramType.selectableCases.first ?? .viqrc
                }
                return prog
            }
            // If no stored program, default to the first selectable case
            return ProgramType.selectableCases.first ?? .viqrc
        }())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Greeting Header
                VStack(spacing: 8) {
                    Text("Welcome to RoboNexus!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("To get started, please select your program.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 30)

                // MARK: - Program List
                // THIS IS THE CRUCIAL LINE THAT USES THE FILTERED LIST
                List(ProgramType.selectableCases) { program in // <-- Using .selectableCases here!
                    Button {
                        selectedProgram = program
                        applyProgram()
                        isPresented = false
                    } label: {
                        HStack {
                            Text(program.displayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedProgram == program {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(selectedProgram == program ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .listStyle(.insetGrouped)

                // MARK: - Instructional Text
                Text("You can change your selected program anytime in the app settings.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
            }
        }
    }

    // --- applyProgram function (unchanged) ---
    private func applyProgram() {
        settings.selectedProgram = selectedProgram.rawValue
        settings.updateUserDefaults()
        configManager.updateProgram(to: selectedProgram)

        DispatchQueue.global(qos: .userInteractive).async {
            API.generate_season_id_map()
            API.populate_all_world_skills_caches() {
                let activeSeason = API.get_current_season_id()
                DispatchQueue.main.async {
                    settings.setSelectedSeasonID(id: activeSeason)
                    API.setSelectedSeasonID(id: activeSeason)
                    settings.updateUserDefaults(updateTopBarContentColor: false)
                    eventSearch.fetch_events(season_query: activeSeason)
                }
            }
        }

        if let version = UIApplication.appVersion {
            UserDefaults.standard.set(version, forKey: "lastProgramPromptVersion")
        }
    }
}
