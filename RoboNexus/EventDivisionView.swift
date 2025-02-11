//
//  EventDivisionView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI


struct EventDivisionView: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @StateObject var navigation_bar_manager = NavigationBarManager(title: "Rankings")
    @State var event: Event
    @State var event_teams: [Team]
    @State var division: Division
    @State var teams_map: [String: String]
    @State var division_teams_list: [String]
    @State var matchNotesByTeam = [String: [TeamMatchNote]]()
    @State var showingNotes = false
    @State var showingInfo = false
    
    func getMatchNotesByTeam() {
        var matchNotes = [TeamMatchNote]()
        self.dataController.fetchNotes(event: self.event) { (fetchNotesResult) in
            switch fetchNotesResult {
                case let .success(notes):
                    matchNotes = notes
                case .failure(_):
                    print("Error fetching Core Data")
            }
        }
        self.matchNotesByTeam = [String: [TeamMatchNote]]()
        for note in matchNotes {
            if !self.matchNotesByTeam.keys.contains(note.team_number ?? "") {
                self.matchNotesByTeam[note.team_number ?? ""] = [TeamMatchNote]()
            }
        }
        for note in matchNotes {
            self.matchNotesByTeam[note.team_number ?? ""]?.append(note)
        }
    }
    
    func shortenedMatchName(matchName: String) -> String {
        var name = matchName
        name.replace("Qualifier", with: "Q")
        name.replace("Practice", with: "P")
        name.replace("Final", with: "F")
        name.replace("#", with: "")
        return name
    }
    
    init(event: Event, event_teams: [Team], division: Division, teams_map: [String: String]) {
        self.event = event
        self.event_teams = event_teams
        self.division = division
        self.teams_map = teams_map
        self.division_teams_list = [String]()
    }
    
    var body: some View {
        TabView {
            EventTeams(event: self.event, division: self.division, teams_map: $teams_map, event_teams: $event_teams, event_teams_list: [String]())
                .tabItem {
                    if UserSettings.getMinimalistic() {
                        Image(systemName: "person.3.fill")
                    }
                    else {
                        Label("Teams", systemImage: "person.3.fill")
                    }
                }
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(navigation_bar_manager)
                .tint(settings.buttonColor())
            EventDivisionMatches(teams_map: $teams_map, event: self.event, division: self.division)
                .tabItem {
                    if UserSettings.getMinimalistic() {
                        Image(systemName: "clock.fill")
                    }
                    else {
                        Label("Match List", systemImage: "clock.fill")
                    }
                }
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(navigation_bar_manager)
                .environmentObject(dataController)
                .tint(settings.buttonColor())
            EventDivisionRankings(event: self.event, division: self.division, teams_map: teams_map)
                .tabItem {
                    if UserSettings.getMinimalistic() {
                        Image(systemName: "list.number")
                    }
                    else {
                        Label("Rankings", systemImage: "list.number")
                    }
                }
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(navigation_bar_manager)
                .tint(settings.buttonColor())
                .onAppear{
                    getMatchNotesByTeam()
                }
                .sheet(isPresented: $showingNotes) {
                    Text("\(division.name) Match Notes").font(.title).multilineTextAlignment(.center).padding()
                    if self.matchNotesByTeam.isEmpty {
                        Text("No notes.")
                    }
                    ScrollView {
                        ForEach(Array(matchNotesByTeam.keys.sorted().sorted(by: { (Int($0.filter("0123456789".contains)) ?? 0) < (Int($1.filter("0123456789".contains)) ?? 0) })), id: \.self) { team_number in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(team_number).font(.title2)
                                    ForEach(self.matchNotesByTeam[team_number] ?? [TeamMatchNote](), id: \.self) { note in
                                        HStack(spacing: 0) {
                                            Text("\(shortenedMatchName(matchName: note.match_name ?? "Unknown Match")): ").foregroundStyle(note.winning_alliance == 0 ? (note.played ? Color.yellow : Color.primary) : (note.winning_alliance == note.team_alliance ? Color.green : Color.red))
                                            Text(note.note ?? "")
                                        }
                                    }
                                }
                                Spacer()
                            }.padding()
                        }
                    }
                }
                
            EventDivisionAwards(event: self.event, division: self.division)
                .tabItem {
                    if UserSettings.getMinimalistic() {
                        Image(systemName: "trophy")
                    }
                    else {
                        Label("Awards", systemImage: "trophy")
                    }
                }
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(navigation_bar_manager)
                .tint(settings.buttonColor())
        }.onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }.tint(settings.buttonColor())
            .background(.clear)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigation_bar_manager.title)
                        .fontWeight(.medium)
                        .font(.system(size: 19))
                        .foregroundColor(settings.topBarContentColor())
                        .foregroundColor(settings.topBarContentColor())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(settings.tabColor(), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct EventDivisionView_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionView(event: Event(), event_teams: [Team](), division: Division(), teams_map: [String: String]())
    }
}
