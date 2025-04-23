//
//  WorldSkillsRankings.swift
//  ADC Hub
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

// MARK: - WorldSkillsTeam Model
struct WorldSkillsTeam: Identifiable, Hashable {
    let id = UUID()
    let number: String

    /// The original rank from the unfiltered data set.
    let originalRank: Int

    /// The rank we display in the current filtered set.
    let displayRank: Int

    /// When filtered, this stores the original rank.
    let additional_ranking: Int?

    let driver: Int
    let programming: Int
    let highest_driver: Int
    let highest_programming: Int
    let combined: Int

    // For local region filtering:
    let regionID: Int        // e.g. from world_skills.event_region_id
    let regionName: String   // user‑friendly region name computed using StateRegionMapping

    /// Constructor for the unfiltered scenario – originalRank = displayRank = rank; additional_ranking is nil.
    init(world_skills: WorldSkills, rank: Int) {
        self.number = world_skills.team.number

        self.originalRank = rank
        self.displayRank  = rank
        self.additional_ranking = nil

        self.driver = world_skills.driver
        self.programming = world_skills.programming
        self.highest_driver = world_skills.highest_driver
        self.highest_programming = world_skills.highest_programming
        self.combined = world_skills.combined

        // ADC integer region
        self.regionID = world_skills.event_region_id

        // For ADC/Aerial Drone, if the team’s region is empty, fall back to event_region.
        let program = UserSettings.getSelectedProgram() ?? "ADC"
        if program == "ADC" || program == "Aerial Drone Competition" {
            let teamRegion = world_skills.team.region
            if teamRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Use event_region if teamRegion is empty.
                self.regionName = world_skills.event_region
            } else {
                let normalized = StateRegionMapping.stateNameVariations[teamRegion] ?? teamRegion
                self.regionName = StateRegionMapping.stateToRegionMap[normalized] ?? normalized
            }
        } else {
            self.regionName = world_skills.event_region
        }
    }

    /// Constructor for filtered data – new displayRank provided while retaining the original rank.
    init(from old: WorldSkillsTeam, newDisplayRank: Int) {
        self.number            = old.number
        self.originalRank      = old.originalRank
        self.displayRank       = newDisplayRank
        self.additional_ranking = old.originalRank

        self.driver            = old.driver
        self.programming       = old.programming
        self.highest_driver    = old.highest_driver
        self.highest_programming = old.highest_programming
        self.combined          = old.combined
        self.regionID          = old.regionID
        self.regionName        = old.regionName
    }
}

// MARK: - WorldSkillsRow View
struct WorldSkillsRow: View {
    @EnvironmentObject var settings: UserSettings
    var team_world_skills: WorldSkillsTeam

    // Program‑dependent labels.
    var flightLabel: String {
        (settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition")
            ? "Autonomous Flight" : "Programming"
    }
    var pilotLabel: String {
        (settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition")
            ? "Piloting" : "Driver"
    }

    var body: some View {
        HStack {
            // Left side: rank text.
            HStack {
                if let additional = team_world_skills.additional_ranking {
                    Text("#\(team_world_skills.displayRank) (#\(additional))")
                        .font(.system(size: 18))
                } else {
                    Text("#\(team_world_skills.displayRank)")
                        .font(.system(size: 18))
                }
                Spacer()
            }
            .frame(width: 80)
            Spacer()
            // Middle: team number.
            Text("\(team_world_skills.number)")
                .font(.system(size: 18))
            Spacer()
            // Right: Combined score with breakdown.
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
    @Published var all_world_skills_teams: [WorldSkillsTeam] = []  // Full loaded data
    @Published var world_skills_teams: [WorldSkillsTeam] = []      // Filtered data
    @Published var isLoading: Bool = true

    /// regionFilter: for ADC, an integer (as String); for non‑ADC, a region name.
    var regionFilter: String = ""
    
    var filterFavorites: Bool = false
    var letter: Character = "0"
    var gradeLevel: String = "High School" // default

    /// Loads world skills data from the proper cache for the given grade level.
    func loadWorldSkillsData(gradeLevel: String) {
        self.isLoading = true
        self.gradeLevel = gradeLevel
        
        DispatchQueue.global(qos: .userInitiated).async {
            let currentProgram = UserSettings.getSelectedProgram() ?? "ADC"
            let skillsCache: WorldSkillsCache
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
                skillsCache = API.vurc_skills_cache
            case "VEX AI Robotics Competition":
                skillsCache = (gradeLevel == "College")
                    ? API.vairc_college_skills_cache
                    : API.vairc_high_school_skills_cache
            case "ADC", "Aerial Drone Competition":
                fallthrough
            default:
                skillsCache = (gradeLevel == "Middle School")
                    ? API.adc_middle_school_skills_cache
                    : API.adc_high_school_skills_cache
            }
            
            let teamsToProcess = skillsCache.teams
            var loadedTeams = [WorldSkillsTeam]()
            var rank = 1
            for wTeam in teamsToProcess {
                let rowModel = WorldSkillsTeam(world_skills: wTeam, rank: rank)
                // Debug print to check mapping
                print("""
                    DEBUG: Created team \(rowModel.number)
                    with teamRegion='\(wTeam.team.region)'
                    eventRegion='\(wTeam.event_region)'
                    => mapped regionName='\(rowModel.regionName)'
                    """)
                loadedTeams.append(rowModel)
                rank += 1
            }
            
            DispatchQueue.main.async {
                self.all_world_skills_teams = loadedTeams
                self.applyLocalFilter()
                self.isLoading = false
            }
        }
    }

    /// Applies local filters (favorites, region, letter). If any filter is active, recalculates displayRank.
    func applyLocalFilter(favoriteTeams: [String] = []) {
        var filtered = self.all_world_skills_teams

        // 1) Favorites filter.
        if filterFavorites && !favoriteTeams.isEmpty {
            filtered = filtered.filter { favoriteTeams.contains($0.number) }
        }

        // 2) Region filter.
        let program = UserSettings.getSelectedProgram() ?? "ADC"
        if !regionFilter.isEmpty && regionFilter != "All" {
            if program == "ADC" || program == "Aerial Drone Competition" {
                if let regionInt = Int(regionFilter), regionInt != 0 {
                    filtered = filtered.filter { $0.regionID == regionInt }
                }
            } else {
                filtered = filtered.filter { $0.regionName == regionFilter }
            }
        }

        // 3) Letter filter.
        if letter != "0" {
            filtered = filtered.filter { $0.number.last == letter }
        }

        // Recalculate displayRank if any filter is active.
        let isFiltered = (filterFavorites && !favoriteTeams.isEmpty)
                      || (!regionFilter.isEmpty && regionFilter != "All")
                      || (letter != "0")
        if isFiltered {
            var newArr = [WorldSkillsTeam]()
            var newRank = 1
            for item in filtered {
                let updated = WorldSkillsTeam(from: item, newDisplayRank: newRank)
                newArr.append(updated)
                newRank += 1
            }
            self.world_skills_teams = newArr
        } else {
            self.world_skills_teams = filtered
        }
    }
}

// MARK: - WorldSkillsRankings View
struct WorldSkillsRankings: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager

    // Default grade level depends on the selected program.
    @State private var grade_level: String = {
        let program = UserSettings.getSelectedProgram() ?? "ADC"
        switch program {
        case "ADC", "Aerial Drone Competition", "VEX V5 Robotics Competition":
            return "High School"
        case "VEX IQ Robotics Competition":
            return "Elementary"
        case "VEX U Robotics Competition":
            return "College"
        case "VEX AI Robotics Competition":
            return "High School"
        default:
            return "High School"
        }
    }()

    @State private var display_skills = "World Skills"
    @State private var selected_season: Int = API.selected_season_id()

    @StateObject private var world_skills_rankings = WorldSkillsTeams()
    
    // For ADC: compute fixed regions from loaded data.
    var fixedRegions: [(key: String, value: Int)] {
        // Build a unique set of (regionName, regionID) pairs from the unfiltered data.
        let pairs = world_skills_rankings.all_world_skills_teams.map { (regionName: $0.regionName, regionID: $0.regionID) }
        let uniquePairs = Dictionary(grouping: pairs, by: { $0.regionName })
            .compactMap { (key, values) -> (String, Int)? in
                if let first = values.first, !key.isEmpty {
                    return (key, first.regionID)
                } else {
                    return nil
                }
            }
        return uniquePairs.sorted { $0.0 < $1.0 }
    }
    
    // For non‑ADC: regionName filters.
    var nonADCRegions: [String] {
        let names = world_skills_rankings.all_world_skills_teams.compactMap { team -> String? in
            let name = team.regionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return ["All"] + Array(Set(names)).sorted()
    }

    var body: some View {
        VStack {
            // Grade Level Picker (if applicable)
            if settings.selectedProgram != "VEX U Robotics Competition" {
                Section("Grade Level") {
                    Picker("Grade Level", selection: $grade_level) {
                        if settings.selectedProgram == "VEX IQ Robotics Competition" {
                            Text("Elementary").tag("Elementary")
                            Text("Middle School").tag("Middle School")
                        } else if settings.selectedProgram == "VEX AI Robotics Competition"{
                            Text("High School").tag("High School")
                            Text("College").tag("College")
                        }else {
                            Text("Middle School").tag("Middle School")
                            Text("High School").tag("High School")
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.top, .bottom], 5)
                    .onChange(of: grade_level) { _ in loadData() }
                }
            } else {
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
                // Favorites filter.
                Button("Favorites") {
                    display_skills = "Favorites Skills"
                    navigation_bar_manager.title = display_skills
                    world_skills_rankings.filterFavorites = true
                    world_skills_rankings.regionFilter = ""
                    world_skills_rankings.applyLocalFilter(favoriteTeams: favorites.favoriteTeams)
                }
                // Region filter depends on program.
                if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
                    Menu("Select Region") {
                        Button("All") {
                            applyFilter(regionString: "", label: "World Skills")
                        }
                        ForEach(fixedRegions, id: \.key) { regionPair in
                            Button(regionPair.key) {
                                applyFilter(regionString: String(regionPair.value),
                                            label: "\(regionPair.key) Skills")
                            }
                        }
                    }
                } else {
                    Menu("Select Region") {
                        ForEach(nonADCRegions, id: \.self) { regionName in
                            Button(regionName) {
                                applyFilter(regionString: regionName == "All" ? "" : regionName,
                                            label: "\(regionName) Skills")
                            }
                        }
                    }
                }
                Button("Clear Filters") {
                    clearFilters()
                }
            }
            .font(.system(size: 19))
            .padding(5)
            
            // Data display
            if world_skills_rankings.isLoading {
                ProgressView("Loading Skills Rankings...")
            } else if world_skills_rankings.world_skills_teams.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
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

    /// Loads the world skills data (from caches) for the current grade level.
    private func loadData() {
        display_skills = "World Skills"
        navigation_bar_manager.title = display_skills
        world_skills_rankings.isLoading = true

        // Reset filters.
        world_skills_rankings.regionFilter = ""
        world_skills_rankings.filterFavorites = false
        world_skills_rankings.letter = "0"

        // Populate caches (if needed) then load data.
        API.populate_all_world_skills_caches {
            world_skills_rankings.loadWorldSkillsData(gradeLevel: grade_level)
        }
    }

    /// Applies a region filter.
    private func applyFilter(regionString: String, label: String) {
        display_skills = label
        navigation_bar_manager.title = label
        world_skills_rankings.filterFavorites = false
        world_skills_rankings.regionFilter = regionString
        world_skills_rankings.applyLocalFilter(favoriteTeams: favorites.favoriteTeams)
    }

    /// Clears all filters.
    private func clearFilters() {
        display_skills = "World Skills"
        navigation_bar_manager.title = display_skills
        world_skills_rankings.filterFavorites = false
        world_skills_rankings.regionFilter = ""
        world_skills_rankings.letter = "0"
        world_skills_rankings.applyLocalFilter(favoriteTeams: favorites.favoriteTeams)
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
