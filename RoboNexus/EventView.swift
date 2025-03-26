//
//  EventView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

struct EventDivisionRow: View {

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController

    @Binding var teams_map: [String: String]
    @Binding var event_teams: [Team]

    var division: String
    var event: Event
    // Added a local binding for the teams list from the event.
    // (Assuming the parent view holds this as state.)
    var event_teams_list: [String]

    var body: some View {
        NavigationLink(
            destination: EventDivisionView(
                event: event,
                event_teams: event_teams,
                division: Division(
                    id: Int(division.split(separator: "&&")[0]) ?? 0,
                    name: String(division.split(separator: "&&")[1])
                ),
                teams_map: teams_map,
                division_teams_list: event_teams_list
            )
            .environmentObject(settings)
            .environmentObject(favorites)
            .environmentObject(dataController)
        ) {
            Text(division.split(separator: "&&")[1])
        }
    }
}

class EventDivisions: ObservableObject {
    @Published var event_divisions: [String]

    init(event_divisions: [String]) {
        self.event_divisions = event_divisions
    }

    public func as_array() -> [String] {
        var out_list = [String]()
        for division in self.event_divisions {
            out_list.append(division)
        }
        return out_list
    }
}

struct EventView: View {

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController

    @State private var event: Event
    @State private var team: Team?
    @State private var teams_map = [String: String]()
    @State private var event_teams = [Team]()
    @State private var event_teams_list = [String]()
    @State private var showLoading = true
    @State private var event_divisions: EventDivisions
    @State private var favorited = false

    init(event: Event, team: Team? = nil) {
        self.event = event
        self.team = team
        // Convert Divisions -> "[id]&&[name]"
        self.event_divisions = EventDivisions(
            event_divisions: event.divisions.map { "\($0.id)&&\($0.name)" }
        )
    }

    func fetch_event_data() {
        // Use the new per-program event favorites approach
        favorited = favorites.favoriteEvents.contains(event.sku)

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            if showLoading == false {
                return
            }

            if event.name.isEmpty {
                event.fetch_info()
                event_divisions = EventDivisions(
                    event_divisions: event.divisions.map { "\($0.id)&&\($0.name)" }
                )
            }

            if event.teams.isEmpty {
                event.fetch_teams()
            }
            self.event_teams = event.teams

            DispatchQueue.main.async {
                self.event_teams_list.removeAll()
                for t in self.event_teams {
                    self.teams_map[String(t.id)] = t.number
                    self.event_teams_list.append(t.number)
                }
                showLoading = false
            }
        }
    }

    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else {
                Form {
                    Section("Event") {
                        NavigationLink(
                            destination: EventInformation(event: event)
                                .environmentObject(settings)
                        ) {
                            Text("Information")
                        }
                        
                        // New Agenda NavigationLink added below the Information button.
                        NavigationLink(
                            destination: AgendaView(event: event)
                                .environmentObject(settings)
                        ) {
                            Text("Agenda")
                        }
                        
                        NavigationLink(
                            destination: EventTeams(
                                event: event,
                                teams_map: $teams_map,
                                event_teams: $event_teams,
                                event_teams_list: event_teams_list
                            )
                            .environmentObject(settings)
                            .environmentObject(dataController)
                        ) {
                            Text("Teams")
                        }
                        
                        if let team = team {
                            NavigationLink(
                                destination: EventTeamMatches(
                                    teams_map: $teams_map,
                                    event: event,
                                    team: team
                                )
                                .environmentObject(settings)
                                .environmentObject(dataController)
                            ) {
                                Text("\(team.number) Match List")
                            }
                        }
                    }
                    
                    Section("Skills") {
                        NavigationLink(
                            destination: EventSkillsRankings(event: event, teams_map: teams_map)
                                .environmentObject(settings)
                        ) {
                            Text("Skills Rankings")
                        }
                    }
                    Section("Divisions") {
                        List($event_divisions.event_divisions) { division in
                            // Pass event_teams_list along to the row view.
                            EventDivisionRow(
                                teams_map: $teams_map,
                                event_teams: $event_teams,
                                division: division.wrappedValue,
                                event: event,
                                event_teams_list: event_teams_list
                            )
                            .environmentObject(settings)
                            .environmentObject(favorites)
                        }
                    }
                    
                    // Show a section for "Favorite Teams Match Lists"
                    let favoriteEventTeams = event_teams.filter { favorites.favoriteTeams.contains($0.number) }
                    if !favoriteEventTeams.isEmpty {
                        Section("Favorite Teams Match Lists") {
                            ForEach(favoriteEventTeams, id: \.id) { favTeam in
                                NavigationLink(
                                    destination: EventTeamMatches(
                                        teams_map: $teams_map,
                                        event: event,
                                        team: favTeam
                                    )
                                    .environmentObject(settings)
                                    .environmentObject(dataController)
                                ) {
                                    Text("\(favTeam.number) Match List")
                                }
                            }
                        }
                    }
                }
            }
        }
        .tint(settings.buttonColor())
        .task {
            fetch_event_data()
        }
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(event.name)
                    .fontWeight(.medium)
                    .font(.system(size: 19))
                    .foregroundColor(settings.topBarContentColor())
            }
            // Using a ToolbarItemGroup for trailing items so both buttons appear.
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Favorites toggle button.
                Button(action: {
                    if favorites.favoriteEvents.contains(event.sku) {
                        favorites.removeEvent(event.sku)
                        favorited = false
                    } else {
                        favorites.addEvent(event.sku)
                        favorited = true
                    }
                }, label: {
                    if favorited {
                        Image(systemName: "star.fill")
                            .foregroundColor(settings.topBarContentColor())
                    } else {
                        Image(systemName: "star")
                            .foregroundColor(settings.topBarContentColor())
                    }
                })
                            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventView(event: Event(), team: nil)
                .environmentObject(FavoriteStorage())
                .environmentObject(UserSettings())
                .environmentObject(ADCHubDataController())
        }
    }
}
