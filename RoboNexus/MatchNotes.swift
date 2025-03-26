//
//  MatchNotes.swift
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

// MARK: - TeamStatsSheet
/// A separate view for displaying team statistics.
struct TeamStatsSheet: View {
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var settings: UserSettings
    var team: Team
    var match: Match
    @Binding var showingSheet: Bool
    
    var body: some View {
        VStack {
            Text("Team Statistics")
                .font(.title)
                .padding()
            // Pass the selected season as needed. (You might need to adjust this if you store the season elsewhere.)
            TeamLookup(team_number: team.number, editable: false, fetch: true, selectedSeason: API.selected_season_id())
                .environmentObject(settings)
                .environmentObject(dataController)
                .onAppear {
                    showingSheet = true
                }
                .onDisappear {
                    showingSheet = false
                }
        }
    }
}

// MARK: - TeamNotesSheet
/// A separate view for displaying match notes for a team.
struct TeamNotesSheet: View {
    var team: Team
    var matchNotes: [TeamMatchNote]
    @Binding var showingSheet: Bool
    
    var body: some View {
        VStack {
            Text("\(team.number) Match Notes")
                .font(.title)
                .padding()
            let filteredNotes: [TeamMatchNote] = matchNotes.filter { ($0.note ?? "") != "" && $0.team_id == Int32(team.id) }
            if filteredNotes.isEmpty {
                Text("No notes.")
            } else {
                ScrollView {
                    ForEach(filteredNotes, id: \.self) { teamNote in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(teamNote.match_name ?? "Unknown Match")
                                    .font(.title2)
                                    .foregroundStyle(teamNote.winning_alliance == 0
                                                      ? (teamNote.played ? Color.yellow : Color.primary)
                                                      : (teamNote.winning_alliance == teamNote.team_alliance ? Color.green : Color.red))
                                Text(teamNote.note ?? "No note.")
                            }
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            showingSheet = true
        }
        .onDisappear {
            showingSheet = false
        }
    }
}

// MARK: - TeamNotes View
struct TeamNotes: View {
    
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var settings: UserSettings
    
    @State var event: Event
    @State var match: Match
    @State var team: Team
    @State var showingNotes: Bool = false
    @State var showingStats: Bool = false
    @FocusState var focused: Bool
    
    @Binding var showingSheet: Bool
    @Binding var matchNotes: [TeamMatchNote]
    
    @State var matchNote: String = ""
    @State var teamMatchNote: TeamMatchNote? = nil

    init(event: Event, match: Match, team: Team, showingSheet: Binding<Bool>, matchNotes: Binding<[TeamMatchNote]>) {
        self._event = State(initialValue: event)
        self._match = State(initialValue: match)
        self._team = State(initialValue: team)
        self._showingSheet = showingSheet
        self._matchNotes = matchNotes
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Header with team number and name.
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(team.number)
                        .font(.title)
                    Text(team.name)
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                        .lineLimit(1)
                }
                Spacer()
                // Stats and Notes Buttons.
                HStack(spacing: 10) {
                    // Stats Button.
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 20, height: 16)
                        Text("View Stats")
                            .font(.system(size: 10))
                    }
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                    .background(match.alliance_for(team: team) == Alliance.red ? Color.red.opacity(0.3) : Color.blue.opacity(0.3))
                    .cornerRadius(13)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingStats = true
                    }
                    .sheet(isPresented: $showingStats) {
                        TeamStatsSheet(team: team, match: match, showingSheet: $showingSheet)
                            .environmentObject(settings)
                            .environmentObject(dataController)
                    }
                    
                    // Notes Button.
                    VStack {
                        Image(systemName: "note.text")
                            .frame(width: 20, height: 16)
                        Text("View Notes")
                            .font(.system(size: 10))
                    }
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                    .background(match.alliance_for(team: team) == Alliance.red ? Color.red.opacity(0.3) : Color.blue.opacity(0.3))
                    .cornerRadius(13)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingNotes = true
                    }
                    .sheet(isPresented: $showingNotes) {
                        TeamNotesSheet(team: team, matchNotes: matchNotes, showingSheet: $showingSheet)
                    }
                }
                .frame(width: 160)
            }
            // Text field for editing match note.
            VStack {
                TextField("Write a match note for team \(team.number)...", text: $matchNote, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .background(Color(UIColor.secondarySystemBackground))
                    .font(.system(size: 15))
                    .cornerRadius(13)
                    .focused($focused)
                    .toolbar {
                        if focused {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    focused = false
                                }
                            }
                        }
                    }
                    .onChange(of: focused) { (newValue: Bool) in
                        // Update the note when focus changes.
                        if let note = teamMatchNote {
                            note.note = matchNote
                            dataController.saveContext()
                        }
                    }
            }
        }
        .onAppear {
            // Load an existing note if available; otherwise create a new one.
            if let note = matchNotes.first(where: { $0.match_id == match.id && $0.team_id == Int32(team.id) }) {
                teamMatchNote = note
                matchNote = note.note ?? ""
            } else {
                let note = dataController.createNewNote()
                note.event_id = Int32(event.id)
                note.match_id = Int32(match.id)
                note.match_name = match.name
                note.note = ""
                note.team_id = Int32(team.id)
                note.team_name = team.name
                note.team_number = team.number
                if let winner = match.winning_alliance() {
                    note.winning_alliance = winner == Alliance.red ? 1 : 2
                } else {
                    note.winning_alliance = 0
                }
                note.played = match.completed()
                if let team_alliance = match.alliance_for(team: team) {
                    note.team_alliance = team_alliance == Alliance.red ? 1 : 2
                } else {
                    note.team_alliance = 0
                }
                note.time = match.started ?? match.scheduled ?? Date.distantFuture
                
                teamMatchNote = note
                matchNotes.append(note)
                matchNote = note.note ?? ""
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(match.alliance_for(team: team) == Alliance.red ? Color.red.opacity(0.5) : Color.blue.opacity(0.5))
        .cornerRadius(20)
    }
}

// MARK: - MatchNotes View
struct MatchNotes: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    
    @State var event: Event
    @State var match: Match
    
    @State var showingSheet: Bool = false
    @State var matchNotes: [TeamMatchNote] = []
    
    private func updateDataSource() {
        dataController.fetchNotes(event: event) { (fetchNotesResult: FetchNotesResult) in
            switch fetchNotesResult {
            case let .success(notes):
                self.matchNotes = notes
            case .failure(_):
                print("Error fetching Core Data")
            }
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 11) {
                    // For each alliance, display a TeamNotes view.
                    TeamNotes(event: event,
                              match: match,
                              team: (event.get_team(id: match.red_alliance[0].id) ?? Team()),
                              showingSheet: $showingSheet,
                              matchNotes: $matchNotes)
                    
                    if match.red_alliance.count > 1 && match.red_alliance[1].id != 0 {
                        TeamNotes(event: event,
                                  match: match,
                                  team: (event.get_team(id: match.red_alliance[1].id) ?? Team()),
                                  showingSheet: $showingSheet,
                                  matchNotes: $matchNotes)
                    }
                    
                    TeamNotes(event: event,
                              match: match,
                              team: (event.get_team(id: match.blue_alliance[0].id) ?? Team()),
                              showingSheet: $showingSheet,
                              matchNotes: $matchNotes)
                    
                    if match.blue_alliance.count > 1 && match.blue_alliance[1].id != 0 {
                        TeamNotes(event: event,
                                  match: match,
                                  team: (event.get_team(id: match.blue_alliance[1].id) ?? Team()),
                                  showingSheet: $showingSheet,
                                  matchNotes: $matchNotes)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 40)
                Spacer()
            }
            // This overlay helps manage hit testing while the sheet is visible.
            Color.white.opacity(0.01)
                .containerShape(Rectangle())
                .allowsHitTesting(showingSheet)
        }
        .onAppear {
            updateDataSource()
        }
        .onDisappear {
            dataController.deleteEmptyNotes()
        }
        .navigationBarBackButtonHidden(showingSheet)
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(match.name) Notes")
                    .fontWeight(.medium)
                    .font(.system(size: 19))
                    .foregroundColor(settings.topBarContentColor())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(settings.buttonColor())
    }
}

struct MatchNotes_Previews: PreviewProvider {
    static var previews: some View {
        MatchNotes(event: Event(), match: Match())
    }
}
