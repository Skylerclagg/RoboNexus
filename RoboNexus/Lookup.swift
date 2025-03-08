//
//  Lookup.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import OrderedCollections
import Combine
import CoreML

// MARK: - TeamInfo & TeamInfoRow

struct TeamInfo: Identifiable {
    let id = UUID()
    let property: String
    let value: String
}

struct TeamInfoRow: View {
    var team_info: TeamInfo
    
    var body: some View {
        HStack {
            Text(team_info.property)
            Spacer()
            Text(team_info.value)
        }
    }
}

// MARK: - Main Lookup View

struct Lookup: View {
    
    @Binding var lookup_type: Int
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    
    @State private var selected_season: Int = API.selected_season_id()
    
    var body: some View {
        VStack {
            Picker("Lookup", selection: $lookup_type) {
                Text("Teams").tag(0)
                Text("Events").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Spacer()
            
            if lookup_type == 0 {
                // Teams lookup view
                Section("Season") {
                    if !API.season_id_map.isEmpty && !API.season_id_map[0].isEmpty {
                        Picker("Season", selection: $selected_season) {
                            ForEach(API.season_id_map[0].keys.sorted().reversed(), id: \.self) { season_id in
                                Text(API.season_id_map[0][season_id] ?? "Unknown")
                                    .tag(season_id)
                            }
                        }
                        .onChange(of: selected_season) { _ in
                            settings.setSelectedSeasonID(id: selected_season)
                            settings.updateUserDefaults(updateTopBarContentColor: false)
                            DispatchQueue.global(qos: .userInteractive).async {
                                API.populate_all_world_skills_caches() {
                                    DispatchQueue.main.async { }
                                }
                            }
                        }
                    } else {
                        Text("No seasons available")
                    }
                }
                TeamLookup(team_number: "", editable: true, fetch: false)
                    .environmentObject(favorites)
                    .environmentObject(settings)
                    .environmentObject(dataController)
            } else if lookup_type == 1 {
                // Events lookup view
                EventLookup()
                    .environmentObject(settings)
                    .environmentObject(favorites)
                    .environmentObject(dataController)
            }
        }
        .onAppear {
            navigation_bar_manager.title = "Lookup"
        }
    }
}

// MARK: - TeamLookup View

struct TeamLookup: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    
    @State var team_number: String = ""
    @State var favorited: Bool = false
    @State var fetch: Bool = false
    @State var fetched: Bool = false
    @State private var team: Team = Team()
    @State private var world_skills = WorldSkills()
    @State private var avg_rank: Double = 0.0
    @State private var award_counts = OrderedDictionary<String, Int>()
    @State private var showLoading: Bool = false
    @State var editable: Bool = true
    @State private var selected_season: Int = API.selected_season_id()
    
    init(team_number: String = "", editable: Bool = true, fetch: Bool = false) {
        self._team_number = State(initialValue: team_number)
        self._editable = State(initialValue: editable)
        self._fetch = State(initialValue: fetch)
    }
    
    // Function to hide the keyboard (iOS only)
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
    
    func fetch_info(number: String) {
        hideKeyboard()
        showLoading = true
        team_number = number.uppercased()
        
        DispatchQueue.global(qos: .userInteractive).async {
            let fetched_team = Team(number: number)
            if fetched_team.id == 0 {
                DispatchQueue.main.async { showLoading = false }
                return
            }
            
            let fetched_world_skills = API.world_skills_for(team: fetched_team) ?? WorldSkills(team: fetched_team, data: [:])
            let fetched_avg_rank = fetched_team.average_ranking()
            fetched_team.fetch_awards()
            fetched_team.awards.sort(by: { $0.order < $1.order })
            
            // NOTE: We now check the new program-based favorites approach
            let is_favorited = favorites.favoriteTeams.contains(fetched_team.number)
            
            DispatchQueue.main.async {
                team = fetched_team
                world_skills = fetched_world_skills
                avg_rank = fetched_avg_rank
                award_counts = fetched_team.awards.reduce(into: OrderedDictionary<String, Int>()) { dict, award in
                    dict[award.title, default: 0] += 1
                }
                favorited = is_favorited
                showLoading = false
                fetched = true
            }
        }
    }
    
    var worldSkillsData: (worldSkills: WorldSkills, teamsCount: Int) {
        let prog = settings.selectedProgram
        switch prog {
        case "VEX IQ Robotics Competition":
            if let skills = API.viqrc_elementary_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.viqrc_elementary_school_skills_cache.teams.count)
            } else if let skills = API.viqrc_middle_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.viqrc_middle_school_skills_cache.teams.count)
            } else {
                return (WorldSkills(team: team), 0)
            }
        case "VEX V5 Robotics Competition":
            if let skills = API.v5rc_middle_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.v5rc_middle_school_skills_cache.teams.count)
            } else if let skills = API.v5rc_high_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.v5rc_high_school_skills_cache.teams.count)
            } else {
                return (WorldSkills(team: team), 0)
            }
        case "VEX U Robotics Competition":
            if let skills = API.vurc_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.vurc_skills_cache.teams.count)
            } else {
                return (WorldSkills(team: team), 0)
            }
        case "ADC", "Aerial Drone Competition":
            fallthrough
        default:
            if let skills = API.adc_middle_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.adc_middle_school_skills_cache.teams.count)
            } else if let skills = API.adc_high_school_skills_cache.teams.first(where: { $0.team.id == team.id }) {
                return (skills, API.adc_high_school_skills_cache.teams.count)
            } else {
                return (WorldSkills(team: team), 0)
            }
        }
    }
    
    var teamPageURL: URL? {
        let prog = settings.selectedProgram
        let base: String
        switch prog {
        case "VEX V5 Robotics Competiton":
            base = "http://robotevents.com/teams/v5rc/"
        case "VEX IQ Robotics Competiton":
            base = "http://robotevents.com/teams/viqrc/"
        case "VEX U Robotics Competition":
            base = "http://robotevents.com/teams/vurc/"
        default:
            base = "http://robotevents.com/teams/adc/"
        }
        return URL(string: base + team.number)
    }
    
    var body: some View {
        VStack {
            HStack {
                if fetched && team.id != 0, let url = teamPageURL {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.system(size: 25))
                            .padding(20)
                            .opacity(fetched ? 1 : 0)
                    }
                }
                
                // Wrap the TextField in a ZStack to overlay a custom placeholder.
                ZStack {
                    // Show custom placeholder only when team_number is empty.
                    if team_number.isEmpty {
                        HStack(spacing: 8) {
                            // Magnifying glass icon.
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 36))
                            // Placeholder text.
                            Text("12345a")
                                .foregroundColor(.gray)
                                .font(.system(size: 36))
                        }
                        // Underline the placeholder (both text and icon).
                        .underline()
                    }
                    // The actual TextField with an empty placeholder string.
                    TextField("", text: $team_number, onEditingChanged: { _ in
                        team = Team()
                        world_skills = WorldSkills(team: Team())
                        avg_rank = 0.0
                        fetched = false
                        favorited = false
                        showLoading = false
                    }, onCommit: {
                        showLoading = true
                        fetch_info(number: team_number)
                    })
                    .disabled(!editable)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 36))
                    .onAppear {
                        if fetch {
                            fetch_info(number: team_number)
                            fetch = false
                        }
                    }
                }
                
                // Toggle favorite status using the new program-based approach.
                Button(action: {
                    guard !team_number.isEmpty else { return }
                    showLoading = true
                    hideKeyboard()
                    team_number = team_number.uppercased()
                    
                    if team.number != team_number {
                        fetch_info(number: team_number)
                    }
                    
                    if favorites.favoriteTeams.contains(team.number) {
                        favorites.removeTeam(team.number)
                        favorited = false
                        showLoading = false
                        return
                    } else {
                        favorites.addTeam(team.number)
                        favorited = true
                        showLoading = false
                    }
                }, label: {
                    if favorited {
                        Image(systemName: "star.fill")
                            .font(.system(size: 25))
                    } else {
                        Image(systemName: "star")
                            .font(.system(size: 25))
                    }
                })
                .padding(20)
            }
        }
        
        VStack {
            if showLoading {
                ProgressView()
            }
        }
        .frame(height: 10)
        List {
            Group {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(team.name)
                }
                // Dynamic label: "Drone Name" for ADC; "Robot Name" for other programs.
                HStack {
                    Text((settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition")
                         ? "Drone Name"
                         : "Robot Name")
                    Spacer()
                    Text(team.robot_name)
                }
                // Grade Level
                HStack {
                    Text("Grade Level")
                    Spacer()
                    Text(team.grade)
                }
                HStack {
                    Text("Organization")
                    Spacer()
                    Text(team.organization)
                }
                HStack {
                    Text("Location")
                    Spacer()
                    Text(fetched ? "\(team.city), \(team.region)" : "")
                }
            }
            HStack {
                Text("World Skills Ranking")
                Spacer()
                Text(fetched
                     ? (worldSkillsData.worldSkills.ranking != 0
                        ? "# \(worldSkillsData.worldSkills.ranking) of \(worldSkillsData.teamsCount)"
                        : "No Data Available")
                     : "")
            }
            HStack {
                Menu("World Skills Score") {
                    Text("\(worldSkillsData.worldSkills.driver) \((settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition") ? "Piloting" : "Driver")")
                    Text("\(worldSkillsData.worldSkills.programming) \((settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition") ? "Autonomous Flight" : "Programming")")
                    Text("\(worldSkillsData.worldSkills.highest_driver) Highest \((settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition") ? "Piloting" : "Driver")")
                    Text("\(worldSkillsData.worldSkills.highest_programming) Highest \((settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition") ? "Autonomous Flight" : "Programming")")
                }
                Spacer()
                Text(fetched
                     ? (worldSkillsData.worldSkills.ranking != 0
                        ? "\(worldSkillsData.worldSkills.combined)"
                        : "No Data Available")
                     : "")
            }
            HStack {
                Menu("Awards") {
                    ForEach(0..<award_counts.count, id: \.self) { index in
                        Text("\(Array(award_counts.values)[index])x \(Array(award_counts.keys)[index])")
                    }
                }
                Spacer()
                Text(fetched && team.registered ? "\(team.awards.count)" : "")
            }
            if editable {
                HStack {
                    NavigationLink(destination:
                        TeamEventsView(team_number: team.number)
                            .environmentObject(settings)
                            .environmentObject(dataController)
                    ) {
                        Text("Events")
                    }
                }
            }
        }
        .tint(settings.buttonColor())
    }
}


// MARK: - EventLookup & EventSearch

struct EventLookup: View {
    
    // Use the environment settings here so that the rest of your app remains consistent.
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    
    // We remove the duplicate newsettings and use onAppear to update eventSearch.settings.
    @StateObject private var eventSearch: EventSearch = EventSearch(settings: UserSettings())
    @State private var selected_season: Int = API.selected_season_id()
    
    init() {
        // Since environment objects are not available in init, we initialize with a temporary settings.
        // We will update eventSearch.settings in .onAppear.
        _eventSearch = StateObject(wrappedValue: EventSearch(settings: UserSettings()))
    }
    
    func clearFilters(){
        eventSearch.name_query = ""
        eventSearch.region_query = ""
        eventSearch.state_query = ""
        eventSearch.level_query = ""
        eventSearch.isDateFilterActive = true
        selected_season = API.selected_season_id()
        eventSearch.fetch_events(season_query: selected_season)
    }
                                 
    var body: some View {
        NavigationView {
            VStack {
                // Use a ZStack to overlay a custom placeholder behind the text field.
                ZStack {
                    // Show the custom placeholder only when the query is empty.
                    if eventSearch.name_query.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 36))
                            Text("Event Name")
                                .underline()
                                .foregroundColor(.gray)
                                .font(.system(size: 36))
                        }
                    }
                    // The actual TextField with an empty placeholder string.
                    TextField("", text: $eventSearch.name_query)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36))
                        .padding()
                        .onChange(of: eventSearch.name_query) { _ in
                            eventSearch.filter_events()
                        }
                }

                
                Menu("Filters") {
                                    // Season selection remains unchanged.
                                    Menu("Select Season") {
                                        ForEach(API.season_id_map[0].keys.sorted().reversed(), id: \.self) { season_id in
                                            Button(action: {
                                                selected_season = season_id
                                                eventSearch.fetch_events(season_query: selected_season)
                                                if selected_season != API.get_current_season_id(){
                                                    eventSearch.isDateFilterActive = false
                                                    print("Date Filter disabled")
                                                } else if selected_season == API.get_current_season_id(){
                                                    eventSearch.isDateFilterActive = true
                                                    print("Date Filter enabled")
                                                } else {
                                                    print("Date Filter not touched")
                                                }
                                            }) {
                                                Text(format_season_option(raw: API.season_id_map[0][season_id] ?? "Unknown"))
                                            }
                                        }
                                    }
                                    .font(.system(size: 20))
                                    .padding()
                                    
                                    // Level selection remains unchanged.
                                    Menu("Select Level") {
                                        Button("All") {
                                            eventSearch.level_query = ""
                                            eventSearch.filter_events()
                                        }
                                        Button("Regional") {
                                            eventSearch.level_query = "regional"
                                            eventSearch.filter_events()
                                        }
                                    }
                                    
                                    // For ADC (or Aerial Drone), show separate Region and State menus.
                                    if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
                                        Menu("Select Region") {
                                            Button("All Regions") {
                                                eventSearch.region_query = ""
                                                eventSearch.filter_events()
                                            }
                                            ForEach(eventSearch.regions_map, id: \.self) { region_name in
                                                Button(action: {
                                                    eventSearch.region_query = region_name
                                                    eventSearch.filter_events()
                                                }) {
                                                    Text(region_name)
                                                }
                                            }
                                        }
                                        Menu("Select State") {
                                            Button("All States") {
                                                eventSearch.state_query = ""
                                                eventSearch.filter_events()
                                            }
                                            ForEach(eventSearch.states_map, id: \.self) { state_name in
                                                Button(action: {
                                                    eventSearch.state_query = state_name
                                                    eventSearch.filter_events()
                                                }) {
                                                    Text(state_name)
                                                }
                                            }
                                        }
                                    } else {
                                        // For non-ADC programs, show only one "Select Region" menu,
                                        // and include only the regions derived from the API (stored in states_map).
                                        Menu("Select Region") {
                                            Button("All Regions") {
                                                eventSearch.region_query = ""
                                                eventSearch.filter_events()
                                            }
                                            ForEach(eventSearch.states_map, id: \.self) { regionName in
                                                Button(action: {
                                                    eventSearch.state_query = regionName
                                                    eventSearch.filter_events()
                                                }) {
                                                    Text(regionName)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Date filter toggle and clear filters remain unchanged.
                                    Button(action: {
                                        eventSearch.isDateFilterActive.toggle()
                                    }) {
                                        Text(eventSearch.isDateFilterActive ? "Remove Date Filter" : "Add Date Filter")
                                    }
                                    
                                    Button("Clear Filters") {
                                        clearFilters()
                                    }
                                }
                                .font(.system(size: 20))
                                .padding()
                                
                                if eventSearch.isLoading {
                                    VStack {
                                        Spacer()
                                        ProgressView("Loading events...")
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .font(.headline)
                                        Spacer()
                                    }
                                } else {
                                    List(eventSearch.event_indexes, id: \.self) { event_index in
                                        if let index = Int(event_index), index < eventSearch.filtered_events.count {
                                            EventRow(event: eventSearch.filtered_events[index])
                                                .environmentObject(dataController)
                                        } else {
                                            Text("Invalid Event")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
            .onAppear {
                // Update eventSearch.settings with the environment's settings
                eventSearch.settings = settings
                clearFilters()
                if selected_season != API.get_current_season_id(){
                    eventSearch.isDateFilterActive = false
                    print("Date Filter disabled")
                } else {
                    eventSearch.isDateFilterActive = eventSearch.isDateFilterActive
                    print("Date Filter not touched")
                }
            }
        }
    }
    
    func format_season_option(raw: String) -> String {
        let yearRange = raw.split(separator: "-")
        if yearRange.count == 2 {
            return "\(yearRange[0])-\(yearRange[1].suffix(2))"
        }
        return raw
    }
}

// MARK: - Modified EventSearch Class

class EventSearch: ObservableObject {
    // NEW: Use a normal stored property for settings (not an @EnvironmentObject) so we can assign it.
    var settings: UserSettings
    
    @Published var event_indexes: [String] = []
    @Published var all_events: [Event] = []
    @Published var filtered_events: [Event] = []
    @Published var states_map: [String] = []
    @Published var state_query: String = ""
    @Published var region_query: String = ""
    @Published var level_query: String = ""
    @Published var name_query: String = ""
    @Published var selected_season: Int
    @Published var isDateFilterActive: Bool = true
    @Published var isLoading: Bool = false
    
    let regions_map: [String] = ["Northeast", "North Central", "Southeast", "South Central", "West"]
    
    private var current_season_id: Int = API.get_current_season_id()
    private var cancellables = Set<AnyCancellable>()
    
    // Modified initializer that accepts a UserSettings instance.
    init(settings: UserSettings, season_query: Int? = nil) {
        self.settings = settings
        self.selected_season = season_query ?? API.selected_season_id()
        fetch_events(season_query: self.selected_season)
        setupSubscribers()
    }
    
    private func setupSubscribers() {
        $name_query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newNameQuery in
                guard let self = self else { return }
                if !newNameQuery.isEmpty && self.isDateFilterActive {
                    self.isDateFilterActive = false
                    self.fetch_events(season_query: self.selected_season, applyDateFilter: false)
                } else if newNameQuery.isEmpty {
                    self.fetch_events(season_query: self.selected_season, applyDateFilter: self.isDateFilterActive)
                }
            }
            .store(in: &cancellables)
        
        $isDateFilterActive
            .filter { [weak self] _ in self?.name_query.isEmpty ?? false }
            .sink { [weak self] _ in
                self?.fetch_events(season_query: self?.selected_season)
            }
            .store(in: &cancellables)
    }
    
    func fetch_events(season_query: Int? = nil, applyDateFilter: Bool = true) {
        if let season = season_query {
            self.selected_season = season
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            var params: [String: Any] = ["per_page": 250]
            if self.isDateFilterActive == true {
                // Use the getDateFilter() function from our settings instance.
                let defaultStartDate = Calendar.current.date(
                    byAdding: .day,
                    value: self.settings.getDateFilter(),
                    to: Date()
                ) ?? Date()
                
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime]
                let startDateString = dateFormatter.string(from: defaultStartDate)
                params["start"] = startDateString
                print("Fetching events starting from: \(startDateString)")
            } else {
                print("Fetching all events for season \(self.selected_season)")
            }
            
            let request_url = "/seasons/\(self.selected_season)/events"
            let data = ADCHubAPI.robotevents_request(request_url: request_url, params: params)
            
            DispatchQueue.main.async {
                self.all_events.removeAll()
                self.states_map.removeAll()
                for event_data in data {
                    var event = Event(id: event_data["id"] as? Int ?? 0, fetch: false, data: event_data)
                    if let normalizedRegion = StateRegionMapping.stateNameVariations[event.region] {
                        event.region = normalizedRegion
                    }
                    self.all_events.append(event)
                    if !event.region.isEmpty && !self.states_map.contains(event.region) {
                        self.states_map.append(event.region)
                    }
                }
                self.states_map.sort()
                print("Number of events fetched: \(self.all_events.count)")
                self.filter_events()
                self.isLoading = false
            }
        }
    }
    
    private func update_event_indexes() {
        event_indexes = filtered_events.indices.map { String($0) }
    }
    
    func filter_events() {
        print("Filtering Events - Name: \(name_query), State: \(state_query), Level: \(level_query), Region: \(region_query)")
        filtered_events = all_events.filter { event in
            var matches = true
            let eventType = event.type.lowercased()
            if eventType.contains("workshop") {
                print("Excluding event \(event.name) due to type: \(event.type)")
                return false
            }
            if !name_query.isEmpty && !event.name.lowercased().contains(name_query.lowercased()) {
                print("Excluding event \(event.name) due to name filter")
                matches = false
            }
            if !state_query.isEmpty && event.region.lowercased() != state_query.lowercased() {
                print("Excluding event \(event.name) due to state filter")
                matches = false
            }
            if !level_query.isEmpty && event.level.lowercased() != level_query.lowercased() {
                print("Excluding event \(event.name) due to level filter")
                matches = false
            }
            if !region_query.isEmpty && region_query != "All Regions" {
                if let statesInRegion = StateRegionMapping.regionToStatesMap[region_query] {
                    let eventRegion = event.region.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !statesInRegion.contains(where: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == eventRegion }) {
                        print("Excluding event \(event.name) due to region filter")
                        matches = false
                    }
                } else {
                    print("Region \(region_query) not found in regionToStatesMap")
                    matches = false
                }
            }
            return matches
        }
        update_event_indexes()
        print("Filtered Events Count: \(filtered_events.count)")
    }
}

struct Lookup_Previews: PreviewProvider {
    static var previews: some View {
        Lookup(lookup_type: .constant(0))
    }
}
