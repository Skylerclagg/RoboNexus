//
//  Settings.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import CoreData

struct Settings: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    // Environment object for program configuration
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var eventSearch: EventSearch

    // State variables for appearance and season.
    @State var selected_button_color = UserSettings().buttonColor()
    @State var selected_top_bar_color = UserSettings().topBarColor()
    @State var selected_top_bar_content_color = UserSettings().topBarContentColor()
    @State var top_bar_content_color_changed = false
    @State var minimalistic = UserSettings.getMinimalistic()
    @State var grade_level = UserSettings.getGradeLevel()
    @State var selected_season_id = UserSettings.getSelectedSeasonID()
    @State var apiKey = UserSettings.getRobotEventsAPIKey() ?? ""
    @State var team_info_default_page = UserSettings.getTeamInfoDefaultPage() == "statistics"
    @State var match_team_default_page = UserSettings.getMatchTeamDefaultPage() == "statistics"
    @State var showLoading = false
    @State var showApply = false
    @State var clearedTeams = false
    @State var clearedEvents = false
    @State var clearedNotes = false
    @State var confirmClearTeams = false
    @State var confirmClearEvents = false
    @State var confirmClearData = false
    @State var confirmClearNotes = false
    @State var confirmAppearance = false
    @State var confirmAPIKey = false
    
    var mode: String {
        #if DEBUG
        return " DEBUG"
        #else
        return ""
        #endif
    }
    
    // Helper to format season options.
    func format_season_option(raw: String) -> String {
        var season = raw
        season = season.replacingOccurrences(of: "ADC ", with: "")
        let season_split = season.split(separator: "-")
        if season_split.count == 1 { return season }
        return "\(season_split[0])-\(season_split[1].dropFirst(2))"
    }
    
    // Computed binding for the program selection.
    // When the program changes, we update UserSettings, update the ConfigManager,
    // refresh the season ID map and world skills caches, and then set selected_season_id
    // to the active season for that program.
    var programBinding: Binding<ProgramType> {
        Binding<ProgramType>(
            get: {
                return ProgramType(rawValue: settings.selectedProgram) ?? .adc
            },
            set: { newProgram in
                // Update the program in UserSettings and persist it.
                settings.selectedProgram = newProgram.rawValue
                settings.updateUserDefaults()
                // Update the ConfigManager with the new program.
                configManager.updateProgram(to: newProgram)
                print("Updated program to \(newProgram.displayName)")
                // Refresh the season map and world skills caches.
                DispatchQueue.global(qos: .userInteractive).async {
                    API.generate_season_id_map()
                    API.populate_all_world_skills_caches() {
                        // Get the active season for the new program.
                        let activeSeason = API.get_current_season_id()
                        DispatchQueue.main.async {
                            self.selected_season_id = activeSeason
                            settings.setSelectedSeasonID(id: activeSeason)
                            API.setSelectedSeasonID(id: activeSeason)
                            print("the selected season Id in the API is: ", API.selected_season_id())
                            settings.updateUserDefaults(updateTopBarContentColor: false)
                            self.eventSearch.fetch_events(season_query: activeSeason)
                        }
                    }
                }
            }
        )
    }
    
    var body: some View {
        VStack {
            List {
                // MARK: - Program Selection Section
                Section("Program Selection") {
                    Picker("Program", selection: programBinding) {
                        ForEach(ProgramType.allCases) { program in
                            Text(program.displayName).tag(program)
                        }
                    }
                    .labelsHidden()
                }
                
                // MARK: - Season Selector Section
                Section("Season Selector") {
                    HStack {
                        Spacer()
                        if showLoading || API.season_id_map.isEmpty {
                            ProgressView()
                        } else {
                            Picker("Season", selection: $selected_season_id) {
                                ForEach(API.season_id_map[0].keys.sorted().reversed(), id: \.self) { season_id in
                                    Text(format_season_option(raw: API.season_id_map[0][season_id] ?? "Unknown")).tag(season_id)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: selected_season_id) { _ in
                                // Use a slight delay so the picker interaction can complete.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    settings.setSelectedSeasonID(id: selected_season_id)
                                    settings.updateUserDefaults(updateTopBarContentColor: false)
                                    self.showLoading = false
                                    DispatchQueue.global(qos: .userInteractive).async {
                                        API.populate_all_world_skills_caches() {
                                            DispatchQueue.main.async { self.showLoading = false }
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
                // MARK: - General Settings
                Section("General") {
                    Toggle("Enable Haptics", isOn: $settings.enableHaptics)
                        .onChange(of: settings.enableHaptics) { _ in
                            settings.updateUserDefaults()
                        }
                    // Fixed Stepper binding: we now return the positive value for display.
                    Stepper(value: Binding(
                        get: { -settings.getDateFilter() },
                        set: { settings.setDateFilter(dateFilter: -$0) }
                    ), in: 1...30) {
                        Text("Date Filter: \(-settings.getDateFilter()) days ago")
                    }
                }
                // MARK: - Appearance Section
                Section("Appearance") {
                    ColorPicker("Top Bar Color", selection: $selected_top_bar_color, supportsOpacity: false)
                        .onChange(of: selected_top_bar_color) { _ in
                            settings.setTopBarColor(color: selected_top_bar_color)
                            showApply = true
                        }
                    ColorPicker("Top Bar Content Color", selection: $selected_top_bar_content_color, supportsOpacity: false)
                        .onChange(of: selected_top_bar_content_color) { _ in
                            settings.setTopBarContentColor(color: selected_top_bar_content_color)
                            top_bar_content_color_changed = true
                            showApply = true
                        }
                    ColorPicker("Button and Tab Color", selection: $selected_button_color, supportsOpacity: false)
                        .onChange(of: selected_button_color) { _ in
                            settings.setButtonColor(color: selected_button_color)
                            showApply = true
                        }
                    Toggle("Minimalistic", isOn: $minimalistic)
                        .onChange(of: minimalistic) { _ in
                            settings.setMinimalistic(state: minimalistic)
                            showApply = true
                        }
                    if showApply {
                        Button("Apply changes") {
                            confirmAppearance = true
                        }
                        .confirmationDialog("Are you sure?", isPresented: $confirmAppearance) {
                            Button("Apply and close app?", role: .destructive) {
                                settings.updateUserDefaults(updateTopBarContentColor: top_bar_content_color_changed)
                                print("App Closing")
                                exit(0)
                            }
                        }
                    }
                }
                
                // MARK: - Danger Section
                Section("Danger") {
                    Button("Clear favorite teams") {
                        confirmClearTeams = true
                    }
                    .alert(isPresented: $clearedTeams) {
                        Alert(title: Text("Cleared favorite teams"), dismissButton: .default(Text("OK")))
                    }
                    .confirmationDialog("Are you sure?", isPresented: $confirmClearTeams) {
                        Button("Clear ALL favorited teams?", role: .destructive) {
                            // Clear all teams from all programs in FavoriteStorage
                            favorites.programFavoriteTeams = [:]
                            favorites.persistTeams()  // ensure it's saved
                            clearedTeams = true
                            print("ALL program favorite teams cleared!")
                        }
                    }
                    
                    Button("Clear favorite events") {
                        confirmClearEvents = true
                    }
                    .alert(isPresented: $clearedEvents) {
                        Alert(title: Text("Cleared favorite events"), dismissButton: .default(Text("OK")))
                    }
                    .confirmationDialog("Are you sure?", isPresented: $confirmClearEvents) {
                        Button("Clear ALL favorited events?", role: .destructive) {
                            // Clear all events from all programs
                            favorites.programFavoriteEvents = [:]
                            favorites.persistEvents()
                            clearedEvents = true
                            print("ALL program favorite events cleared!")
                        }
                    }
                    
                    Button("Clear all match notes") {
                        confirmClearNotes = true
                    }
                    .alert(isPresented: $clearedNotes) {
                        Alert(title: Text("Cleared match notes"), dismissButton: .default(Text("OK")))
                    }
                    .confirmationDialog("Are you sure?", isPresented: $confirmClearNotes) {
                        Button("Clear ALL match notes?", role: .destructive) {
                            dataController.deleteAllNotes()
                            clearedNotes = true
                        }
                    }
                }
                
                // MARK: - Developer Section
                Section("Developer") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(UIApplication.appVersion!) (\(UIApplication.appBuildNumber!))\(self.mode)")
                    }
                }
                
                Section {
                    // You can leave the section content empty if you only need a header.
                } header: {
                    // Combine Text views so that only the middle part is red.
                    Text("Developed by Skyler Clagg, ")
                    + Text("Note this app is NOT an OFFICIAL RECF App.").foregroundColor(.red)
                    + Text(" Based on Teams Ace 229V and Jelly 2733J's VRC Roboscout")
                }
            }
            Link("Join the Discord Server", destination: URL(string: "https://discord.gg/KzaUshqfsZ")!).padding()
        }
        .onAppear {
            navigation_bar_manager.title = "Settings"
            settings.readUserDefaults()
        }
    }
}
