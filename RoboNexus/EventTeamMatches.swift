//
//  EventTeamMatches.swift
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
import ActivityKit

enum AlertText: String {
    case enabled = "Match updates enabled. Your upcoming and most recent matches will be shown on your lock screen."
    case disabled = "Match updates disabled. You may reenable them at any time."
    case missingMatches = "Could not start match updates. Please try again when the match list has been released."
    case missingPermission = "You have disabled Live Activities for ADC Hub. Please reenable them in the settings app."
}

struct EventTeamMatches: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataController: ADCHubDataController
    
    @Binding var teams_map: [String: String]
    @State var event: Event
    @State var team: Team
    @State var division: Division?
    @State private var matches = [Match]()
    @State private var matches_list = [String]()
    @State private var showLoading = true
    @State private var showingTeamNotes = false
    @State private var alertText = AlertText.enabled
    @State private var showAlert = false
    
    @State var teamMatchNotes: [TeamMatchNote]? = nil
    
    private func updateDataSource() {
        self.dataController.fetchNotes(event: self.event, team: self.team) { (fetchNotesResult) in
            switch fetchNotesResult {
            case let .success(notes):
                self.teamMatchNotes = notes
            case .failure(_):
                print("Error fetching Core Data")
            }
        }
    }
    
    init(teams_map: Binding<[String: String]>, event: Event, team: Team, division: Division? = nil) {
        self._teams_map = teams_map
        self._event = State(initialValue: event)
        self._team = State(initialValue: team)
        self._division = State(initialValue: division)
    }
    
    func fetch_info() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            
            var matches = [Match]()
            
            if self.team.id == 0 || self.team.number == "" {
                self.team = Team(id: self.team.id, number: self.team.number)
            }
            
            if division == nil {
                let teamMatches = self.team.matches_at(event: event)
                if !teamMatches.isEmpty {
                    self.division = teamMatches[0].division
                }
            }
            
            if let division = division {
                do {
                    self.event.fetch_matches(division: division)
                    matches = self.event.matches[division]?.filter {
                        $0.alliance_for(team: self.team) != nil
                    } ?? []
                } catch {
                    matches = self.team.matches_at(event: event)
                }
            } else {
                matches = self.team.matches_at(event: event)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"

            DispatchQueue.main.async {
                self.matches = matches
                self.matches_list.removeAll()
                var count = 0
                for match in matches {
                    var name = match.name
                    name = name.replacingOccurrences(of: "Qualifier", with: "Q")
                    name = name.replacingOccurrences(of: "Practice", with: "P")
                    name = name.replacingOccurrences(of: "Match", with: "F")
                    name = name.replacingOccurrences(of: "TeamWork", with: "Q")
                    name = name.replacingOccurrences(of: "#", with: "")
                    
                    let date: String = {
                        if let started = match.started {
                            return formatter.string(from: started)
                        } else if let scheduled = match.scheduled {
                            return formatter.string(from: scheduled)
                        } else {
                            return " "
                        }
                    }()
                    
                    self.matches_list.append("\(count)&&\(name)&&\(match.red_alliance[0].id)&&\(match.red_alliance[1].id)&&\(match.blue_alliance[0].id)&&\(match.blue_alliance[1].id)&&\(match.red_score)&&\(match.blue_score)&&\(date)")
                    count += 1
                }
                self.showLoading = false
            }
        }
    }
    
    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else if matches.isEmpty {
                NoData()
            } else {
                List($matches_list, id: \.self) { matchString in
                    MatchRowView(
                        event: $event,
                        matches: $matches,
                        teams_map: $teams_map,
                        matchString: matchString,
                        team: $team
                    )
                }
            }
        }
        .onAppear {
            fetch_info()
        }
        .onChange(of: teams_map) { _ in
            // You may also trigger a refresh when teams_map changes, if needed.
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(team.number) Match List")
                    .fontWeight(.medium)
                    .font(.system(size: 19))
                    .foregroundColor(settings.topBarContentColor())
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Refresh button added similar to the note.text button.
                Button(action: {
                    showLoading = true
                    fetch_info()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(settings.topBarContentColor())
                }
                .accessibilityLabel("Refresh")
                
                Button(action: {
                    showingTeamNotes = true
                }) {
                    Image(systemName: "note.text")
                        .foregroundColor(settings.topBarContentColor())
                }
            }
        }
        .sheet(isPresented: $showingTeamNotes) {
            VStack {
                Text("\(team.number) Match Notes")
                    .font(.title)
                    .padding()
                    .foregroundStyle(Color.primary)
                if (teamMatchNotes ?? []).filter({ ($0.note ?? "") != "" }).isEmpty {
                    Text("No notes.")
                } else {
                    ScrollView {
                        ForEach((teamMatchNotes ?? []).filter { ($0.note ?? "") != "" }, id: \.self) { teamNote in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(teamNote.match_name ?? "Unknown Match")
                                        .font(.title2)
                                        .foregroundStyle(
                                            teamNote.winning_alliance == 0
                                                ? (teamNote.played ? Color.yellow : Color.primary)
                                                : (teamNote.winning_alliance == teamNote.team_alliance ? Color.green : Color.red)
                                        )
                                    Text(teamNote.note ?? "No note.")
                                        .foregroundStyle(Color.primary)
                                }
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertText.rawValue), dismissButton: .default(Text("OK")))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(settings.buttonColor())
        .background(.clear)
    }
}

struct EventTeamMatches_Previews: PreviewProvider {
    static var previews: some View {
        EventTeamMatches(teams_map: .constant([:]), event: Event(), team: Team())
    }
}
