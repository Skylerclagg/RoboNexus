//
//  WorldSkillsRankings.swift
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

// MARK: - WorldSkillsTeam Model
struct WorldSkillsTeam: Identifiable, Hashable {
    let id = UUID()
    let number: String
    let ranking: Int
    let additional_ranking: Int?
    let driver: Int
    let programming: Int
    let highest_driver: Int
    let highest_programming: Int
    let combined: Int

    init(world_skills: WorldSkills, ranking: Int, additional_ranking: Int? = nil) {
        self.number = world_skills.team.number
        self.ranking = ranking
        self.additional_ranking = additional_ranking
        self.driver = world_skills.driver
        self.programming = world_skills.programming
        self.highest_driver = world_skills.highest_driver
        self.highest_programming = world_skills.highest_programming
        self.combined = world_skills.combined
    }
}

// MARK: - WorldSkillsRow View
struct WorldSkillsRow: View {
    @EnvironmentObject var settings: UserSettings
    var team_world_skills: WorldSkillsTeam

    // If the program is ADC, use the old labels; otherwise substitute.
    var flightLabel: String {
        (settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition")
            ? "Autonomous Flight"
            : "Programming"
    }
    var pilotLabel: String {
        (settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition")
            ? "Piloting"
            : "Driver"
    }

    var body: some View {
        HStack {
            HStack {
                if let additionalRanking = team_world_skills.additional_ranking {
                    Text("#\(team_world_skills.ranking) (#\(additionalRanking))")
                        .font(.system(size: 18))
                } else {
                    Text("#\(team_world_skills.ranking)")
                        .font(.system(size: 18))
                }
                Spacer()
            }
            .frame(width: 80)
            Spacer()
            Text("\(team_world_skills.number)")
                .font(.system(size: 18))
            Spacer()
            HStack {
                Menu("\(team_world_skills.combined)") {
                    Text("\(team_world_skills.combined) Combined")
                    Text("\(team_world_skills.programming) \(flightLabel)")
                    Text("\(team_world_skills.driver) \(pilotLabel)")
                    Text("\(team_world_skills.highest_programming) Highest \(flightLabel)")
                    Text("\(team_world_skills.highest_driver) Highest \(pilotLabel)")
                }
                .font(.system(size: 18))
                HStack {
                    Spacer()
                    VStack {
                        Text("\(team_world_skills.programming)")
                            .font(.system(size: 10))
                        Text("\(team_world_skills.driver)")
                            .font(.system(size: 10))
                    }
                }
                .frame(width: 30)
            }
            .frame(width: 80)
        }
    }
}

// MARK: - WorldSkillsTeams Observable Object
class WorldSkillsTeams: ObservableObject {
    @Published var world_skills_teams: [WorldSkillsTeam] = []

    // Filtering properties
    private var region: Int = 0
    private var letter: Character = "0"
    private var filter_array: [String] = []
    // The gradeLevel used to choose the proper cache
    var gradeLevel: String = "High School" // default
    
    /// Loads data from the appropriate world skills cache based on the selected program and grade level.
    func loadWorldSkillsData(region: Int = 0,
                             letter: Character = "0",
                             filter_array: [String] = [],
                             gradeLevel: String)
    {
        self.region = region
        self.filter_array = filter_array
        self.gradeLevel = gradeLevel

        DispatchQueue.global(qos: .userInitiated).async {
            let currentProgram = UserSettings.getSelectedProgram() ?? "ADC"
            var skillsCache: WorldSkillsCache

            // Select the proper cache based on current program and grade
            switch currentProgram {
            case "VEX IQ Robotics Competition":
                skillsCache = (gradeLevel == "Elementary")
                    ? API.viqrc_elementary_school_skills_cache
                    : API.viqrc_middle_school_skills_cache
            case "VEX V5 Robotics Competition":
                skillsCache = (gradeLevel == "Middle School")
                    ? API.v5rc_middle_school_skills_cache
                    : API.v5rc_high_school_skills_cache
            case "VEX U Robotics Competition":
                // For VURC, force grade level to "College"
                skillsCache = API.vurc_skills_cache
            case "ADC", "Aerial Drone Competition":
                fallthrough
            default:
                skillsCache = (gradeLevel == "Middle School")
                    ? API.adc_middle_school_skills_cache
                    : API.adc_high_school_skills_cache
            }
            
            var teamsToProcess = skillsCache.teams

            if !self.filter_array.isEmpty {
                // If user wants to filter by favorites, for example
                teamsToProcess = teamsToProcess.filter { self.filter_array.contains($0.team.number) }
            }
            if region != 0 {
                teamsToProcess = teamsToProcess.filter { $0.event_region_id == region }
            }
            if letter != "0" {
                teamsToProcess = teamsToProcess.filter { $0.team.number.last == letter }
            }
            
            // Build array of WorldSkillsTeams
            var worldSkillsTeams = [WorldSkillsTeam]()
            var rank = 1
            for team in teamsToProcess {
                // If a filter is being applied, show the actual ranking as an "additional ranking"
                let isFilterApplied = !self.filter_array.isEmpty || region != 0 || letter != "0"
                let additionalRanking = isFilterApplied ? team.ranking : nil
                let rowModel = WorldSkillsTeam(world_skills: team,
                                               ranking: rank,
                                               additional_ranking: additionalRanking)
                worldSkillsTeams.append(rowModel)
                rank += 1
            }
            
            DispatchQueue.main.async {
                self.world_skills_teams = worldSkillsTeams
            }
        }
    }
}

// MARK: - WorldSkillsRankings View
struct WorldSkillsRankings: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager

    // Local state for display title, filters, and selected season
    @State private var display_skills = "World Skills"
    @State private var region_id = 0
    @State private var letter: Character = "0"
    // Local grade level is used to drive the cache selection
    @State private var grade_level: String = UserSettings.getGradeLevel()
    @State private var selected_season: Int = API.selected_season_id()

    @StateObject private var world_skills_rankings = WorldSkillsTeams()

    var body: some View {
        VStack {
            // For non-VURC programs, show a grade-level picker
            if settings.selectedProgram != "VEX U Robotics Competition" {
                Section("Grade Level") {
                    Picker("Grade Level", selection: $grade_level) {
                        if settings.selectedProgram == "VEX IQ Robotics Competition" {
                            Text("Elementary").tag("Elementary")
                            Text("Middle School").tag("Middle School")
                        } else {
                            // For ADC and V5RC
                            Text("Middle School").tag("Middle School")
                            Text("High School").tag("High School")
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.top, .bottom], 5)
                    .onChange(of: grade_level) { newGrade in
                        updateWorldSkillsForGrade(newGrade)
                    }
                }
            } else {
                // For VURC, force grade level to "College"
                Text("Grade Level: College")
                    .padding(.vertical, 5)
                    .onAppear { grade_level = "College" }
            }
            
            // Season Picker
            Section("Season") {
                if !API.season_id_map.isEmpty && !API.season_id_map[0].isEmpty {
                    Picker("Season", selection: $selected_season) {
                        ForEach(API.season_id_map[0].keys.sorted().reversed(), id: \.self) { season_id in
                            Text(API.season_id_map[0][season_id] ?? "Unknown").tag(season_id)
                        }
                    }
                    .onChange(of: selected_season) { _ in
                        settings.setSelectedSeasonID(id: selected_season)
                        settings.updateUserDefaults(updateTopBarContentColor: false)
                        loadData()
                    }
                } else {
                    Text("No seasons available")
                }
            }
            
            // Filter Menu
            Menu("Filter") {
                // Use the new program-based favorites.teams if you want "Favorites" filter
                // We can rely on the .favoriteTeams to get the current program's list
                if !favorites.favoriteTeams.isEmpty {
                    Button("Favorites") {
                        applyFilter(filterArray: favorites.favoriteTeams, filterName: "Favorites Skills")
                    }
                }
                Menu("Region") {
                    Button("World") {
                        clearFilters()
                    }
                    ForEach(API.regions_map.sorted(by: <), id: \.key) { region, id in
                        Button(region) {
                            applyFilter(regionID: id, filterName: "\(region) Skills")
                        }
                    }
                }
                Button("Clear Filters") {
                    clearFilters()
                }
            }
            .fontWeight(.medium)
            .font(.system(size: 19))
            .padding(5)
            
            // Display
            if world_skills_rankings.world_skills_teams.isEmpty {
                ProgressView("Loading Skills Rankings...")
            } else {
                List(world_skills_rankings.world_skills_teams) { team in
                    WorldSkillsRow(team_world_skills: team)
                }
            }
        }
        .navigationTitle(display_skills)
        .onAppear {
            navigation_bar_manager.title = display_skills
            loadData()
        }
    }

    private func loadData() {
        // Clear current data
        world_skills_rankings.world_skills_teams = []
        // Repopulate caches, then load data from the correct cache
        API.populate_all_world_skills_caches {
            world_skills_rankings.loadWorldSkillsData(region: region_id,
                                                      letter: letter,
                                                      filter_array: [],
                                                      gradeLevel: grade_level)
        }
    }

    private func updateWorldSkillsForGrade(_ newGrade: String) {
        world_skills_rankings.loadWorldSkillsData(region: region_id,
                                                  letter: letter,
                                                  filter_array: [],
                                                  gradeLevel: newGrade)
    }

    private func applyFilter(regionID: Int = 0,
                             filterArray: [String] = [],
                             filterName: String)
    {
        display_skills = filterName
        navigation_bar_manager.title = display_skills
        region_id = regionID
        letter = "0"
        world_skills_rankings.loadWorldSkillsData(region: region_id,
                                                  letter: letter,
                                                  filter_array: filterArray,
                                                  gradeLevel: grade_level)
    }

    private func clearFilters() {
        display_skills = "World Skills"
        navigation_bar_manager.title = display_skills
        region_id = 0
        letter = "0"
        world_skills_rankings.loadWorldSkillsData(region: region_id,
                                                  letter: letter,
                                                  filter_array: [],
                                                  gradeLevel: grade_level)
    }
}

struct WorldSkillsRankings_Previews: PreviewProvider {
    static var previews: some View {
        WorldSkillsRankings()
            .environmentObject(UserSettings())
            .environmentObject(FavoriteStorage())
            .environmentObject(NavigationBarManager(title: "Preview Skills"))
    }
}
