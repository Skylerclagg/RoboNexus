//
//  Favorites.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

// MARK: - FavoriteTeamsRow

struct FavoriteTeamsRow: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController

    var team: String

    var body: some View {
        NavigationLink(destination:
            TeamInfoView(teamNumber: team)
                .environmentObject(settings)
                .environmentObject(dataController)
        ) {
            Text(team)
        }
    }
}

// MARK: - FavoriteEventsRow

struct FavoriteEventsRow: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController

    var sku: String
    var data: [String: Event]

    func generate_location(event: Event) -> String {
        var location_array = [event.city, event.region, event.country]
        location_array = location_array.filter { !$0.isEmpty }
        return location_array.joined(separator: ", ")
            .replacingOccurrences(of: "United States", with: "USA")
    }

    var body: some View {
        NavigationLink(destination:
            EventView(event: (data[sku] ?? Event(sku: sku, fetch: false)))
                .environmentObject(settings)
                .environmentObject(dataController)
        ) {
            VStack {
                Text((data[sku] ?? Event(sku: sku, fetch: false)).name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20)
                Spacer().frame(height: 5)
                HStack {
                    Text(generate_location(event: data[sku] ?? Event(sku: sku, fetch: false)))
                        .font(.system(size: 11))
                    Spacer()
                    Text((data[sku] ?? Event(sku: sku, fetch: false)).start ?? Date(), style: .date)
                        .font(.system(size: 11))
                }
            }
        }
    }
}

// MARK: - FavoriteStorage
//
// This now stores separate favorites for each program in two dictionaries:
// programFavoriteTeams[program], programFavoriteEvents[program].
class FavoriteStorage: ObservableObject {

    // Dictionary of program -> array of team numbers
    @Published var programFavoriteTeams: [String: [String]]
    // Dictionary of program -> array of event SKUs
    @Published var programFavoriteEvents: [String: [String]]

    // A helper to get the current program from the user settings.
    private var currentProgram: String {
        // If using the "Aerial Drone Competition" name, match it here as well if needed
        return UserSettings.getSelectedProgram() ?? "ADC"
    }

    init() {
        // Attempt to read from UserDefaults. If not found, initialize empty.
        // If you want to do a migration from the old single arrays, do so here.
        if let dataTeams = UserDefaults.standard.data(forKey: "programFavoriteTeams"),
           let decodedTeams = try? JSONDecoder().decode([String: [String]].self, from: dataTeams) {
            self.programFavoriteTeams = decodedTeams
        } else {
            self.programFavoriteTeams = [:]
        }

        if let dataEvents = UserDefaults.standard.data(forKey: "programFavoriteEvents"),
           let decodedEvents = try? JSONDecoder().decode([String: [String]].self, from: dataEvents) {
            self.programFavoriteEvents = decodedEvents
        } else {
            self.programFavoriteEvents = [:]
        }
    }

    // MARK: - Favorites for the Current Program (Teams)

    // Returns the teams for the *current* program
    var favoriteTeams: [String] {
        get {
            let list = programFavoriteTeams[currentProgram] ?? []
            return list.sorted(by: favoriteTeamSort)
        }
        set {
            programFavoriteTeams[currentProgram] = newValue
            persistTeams()
        }
    }

    // Add a team for the current program
    func addTeam(_ team: String) {
        var list = programFavoriteTeams[currentProgram] ?? []
        guard !list.contains(team) else { return }
        list.append(team)
        programFavoriteTeams[currentProgram] = list
        persistTeams()
    }

    // Remove a team for the current program
    func removeTeam(_ team: String) {
        guard var list = programFavoriteTeams[currentProgram] else { return }
        if let idx = list.firstIndex(of: team) {
            list.remove(at: idx)
            programFavoriteTeams[currentProgram] = list
            persistTeams()
        }
    }

    // Sort function for teams
    private func favoriteTeamSort(_ a: String, _ b: String) -> Bool {
        // Sort first lexically, then numerically
        let aNum = Int(a.filter("0123456789".contains)) ?? 0
        let bNum = Int(b.filter("0123456789".contains)) ?? 0
        if aNum == bNum {
            return a < b
        } else {
            return aNum < bNum
        }
    }

    // MARK: - Favorites for the Current Program (Events)

    // Returns the events for the current program
    var favoriteEvents: [String] {
        get {
            let list = programFavoriteEvents[currentProgram] ?? []
            // Possibly sort them in some order. We'll keep them as is for now.
            return list
        }
        set {
            programFavoriteEvents[currentProgram] = newValue
            persistEvents()
        }
    }

    // Add an event for the current program
    func addEvent(_ sku: String) {
        var list = programFavoriteEvents[currentProgram] ?? []
        guard !list.contains(sku) else { return }
        list.append(sku)
        programFavoriteEvents[currentProgram] = list
        persistEvents()
    }

    // Remove an event for the current program
    func removeEvent(_ sku: String) {
        guard var list = programFavoriteEvents[currentProgram] else { return }
        if let idx = list.firstIndex(of: sku) {
            list.remove(at: idx)
            programFavoriteEvents[currentProgram] = list
            persistEvents()
        }
    }

    // Check if an event is favorited for the current program
    func isFavoritedEvent(_ sku: String) -> Bool {
        let list = programFavoriteEvents[currentProgram] ?? []
        return list.contains(sku)
    }

    // MARK: - Persist

    func persistTeams() {
        if let data = try? JSONEncoder().encode(programFavoriteTeams) {
            UserDefaults.standard.set(data, forKey: "programFavoriteTeams")
        }
    }

    func persistEvents() {
        if let data = try? JSONEncoder().encode(programFavoriteEvents) {
            UserDefaults.standard.set(data, forKey: "programFavoriteEvents")
        }
    }
}

// MARK: - Favorites View
struct Favorites: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager

    @State var event_sku_map = [String: Event]()
    @State var showEvents = false

    @Binding var tab_selection: Int
    @Binding var lookup_type: Int

    // Return the teams for the current program from FavoriteStorage
    private var programTeams: [String] {
        favorites.favoriteTeams
    }

    // Return the events for the current program from FavoriteStorage
    private var programEvents: [String] {
        favorites.favoriteEvents
    }

    func generate_event_sku_map() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            let data = ADCHubAPI.robotevents_request(request_url: "/events",
                                                    params: ["sku": programEvents]) // Use programEvents
            var map = [String: Event]()

            for event_data in data {
                let event = Event(fetch: false, data: event_data)
                map[event.sku] = event
            }

            DispatchQueue.main.async {
                event_sku_map = map
                sort_events_by_date()
                showEvents = true
            }
        }
    }

    func sort_events_by_date() {
        // Sort programEvents in descending order by start date
        favorites.favoriteEvents = programEvents.sorted { sku1, sku2 in
            let e1 = event_sku_map[sku1] ?? Event(sku: sku1, fetch: false)
            let e2 = event_sku_map[sku2] ?? Event(sku: sku2, fetch: false)
            return (e1.start ?? Date()) > (e2.start ?? Date())
        }
    }

    // Deletions now use the program-specific methods:
    func deleteTeam(at offsets: IndexSet) {
        let teams = programTeams
        for idx in offsets {
            if idx < teams.count {
                let removedTeam = teams[idx]
                favorites.removeTeam(removedTeam)
            }
        }
    }

    func deleteEvent(at offsets: IndexSet) {
        let events = programEvents
        for idx in offsets {
            if idx < events.count {
                let removedSKU = events[idx]
                favorites.removeEvent(removedSKU)
            }
        }
    }

    var body: some View {
        VStack {
            Form {
                // Favorite Teams
                Section(programTeams.count > 0
                        ? "Favorite Teams (\(settings.selectedProgram))"
                        : "To add a Favorite Team, search for them in the Lookup tab") {
                    if !programTeams.isEmpty {
                        List {
                            ForEach(programTeams, id: \.self) { teamNum in
                                FavoriteTeamsRow(team: teamNum)
                                    .environmentObject(favorites)
                                    .environmentObject(dataController)
                            }
                            .onDelete(perform: deleteTeam)
                        }
                    } else {
                        List {
                            Button("Lookup a Team") {
                                tab_selection = 2
                                lookup_type = 0
                            }
                        }
                    }
                }

                // Favorite Events
                Section(programEvents.count > 0
                        ? "Favorite Events (\(settings.selectedProgram))"
                        : "To add a Favorite Event, search for it in the Lookup tab") {
                    if showEvents && !programEvents.isEmpty {
                        List {
                            ForEach(programEvents, id: \.self) { sku in
                                FavoriteEventsRow(sku: sku, data: event_sku_map)
                                    .environmentObject(favorites)
                                    .environmentObject(dataController)
                            }
                            .onDelete(perform: deleteEvent)
                        }
                    } else if !programEvents.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        List {
                            Button("Lookup an Event") {
                                tab_selection = 2
                                lookup_type = 1
                            }
                        }
                    }
                }
            }
            .onAppear {
                navigation_bar_manager.title = "Favorites"
                if event_sku_map.count != programEvents.count {
                    generate_event_sku_map()
                }
            }
        }
    }
}

struct Favorites_Previews: PreviewProvider {
    static var previews: some View {
        Favorites(tab_selection: .constant(0), lookup_type: .constant(0))
            .environmentObject(UserSettings())
            .environmentObject(FavoriteStorage())
            .environmentObject(ADCHubDataController())
            .environmentObject(NavigationBarManager(title: "Preview Favorites"))
    }
}
