import SwiftUI

struct ProgramSelectionPopup: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var eventSearch: EventSearch

    @Binding var isPresented: Bool
    @State private var selectedProgram: ProgramType = {
        if let stored = UserSettings.getSelectedProgram(),
           let prog = ProgramType(rawValue: stored) {
            if prog == .adc && !UserDefaults.standard.bool(forKey: "DeveloperModeEnabled") {
                return ProgramType.selectableCases.first ?? .viqrc
            }
            return prog
        }
        return ProgramType.selectableCases.first ?? .viqrc
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Your Program")
                    .font(.headline)
                Picker("Program", selection: $selectedProgram) {
                    ForEach(ProgramType.selectableCases) { program in
                        Text(program.displayName).tag(program)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                Button("Continue") {
                    applyProgram()
                    isPresented = false
                }
                .padding()
            }
            .navigationTitle("Program")
        }
    }

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
