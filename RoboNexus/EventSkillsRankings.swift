//
//  EventSkillsRankings.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

class EventSkillsRankingsList: ObservableObject {
    @Published var rankings_indexes: [Int]
    
    init(rankings_indexes: [Int] = [Int]()) {
        self.rankings_indexes = rankings_indexes.sorted()
    }
}

struct EventSkillsRankings: View {
    
    @EnvironmentObject var settings: UserSettings
    
    @State var event: Event
    @State var teams_map: [String: String]
    @State var event_skills_rankings_list: EventSkillsRankingsList
    @State var showLoading = true
    @State var teamNumberQuery = ""
    
    // Determine labels based on the selected program.
    var autonomousLabel: String {
        if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
            return "Autonomous Flight:"
        } else {
            return "Autonomous Coding:"
        }
    }
    var driverLabel: String {
        if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
            return "Piloting:"
        } else {
            return "Driver:"
        }
    }
    
    var searchResults: [Int] {
        if teamNumberQuery.isEmpty {
            return event_skills_rankings_list.rankings_indexes
        } else {
            return event_skills_rankings_list.rankings_indexes.filter { index in
                let mappedID = teams_map[String(team_ranking(rank: index).team.id)] ?? ""
                return mappedID.lowercased().contains(teamNumberQuery.lowercased())
            }
        }
    }
    
    init(event: Event, teams_map: [String: String]) {
        self.event = event
        self.teams_map = teams_map
        self.event_skills_rankings_list = EventSkillsRankingsList()
    }
    
    func fetch_rankings() {
        // Optionally set a loading flag to true for UI feedback.
        showLoading = true
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            event.fetch_skills_rankings()
            var fetched_rankings_indexes = [Int]()
            var counter = 0
            for _ in event.skills_rankings {
                fetched_rankings_indexes.append(counter)
                counter += 1
            }
            DispatchQueue.main.async {
                self.event_skills_rankings_list = EventSkillsRankingsList(rankings_indexes: fetched_rankings_indexes)
                self.showLoading = false
            }
        }
    }
    
    func team_ranking(rank: Int) -> TeamSkillsRanking {
        return event.skills_rankings[rank]
    }
    
    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else if event.skills_rankings.isEmpty {
                NoData()
            } else {
                // Use a simple List (remove the inner NavigationView if the parent provides one)
                List {
                    ForEach(searchResults, id: \.self) { rank in
                        VStack {
                            HStack {
                                HStack {
                                    Text(teams_map[String(team_ranking(rank: rank).team.id)] ?? "")
                                        .font(.system(size: 20))
                                        .minimumScaleFactor(0.01)
                                        .frame(width: 70, alignment: .leading)
                                        .bold()
                                    Text((event.get_team(id: team_ranking(rank: rank).team.id) ?? Team()).name)
                                        .frame(alignment: .leading)
                                }
                                Spacer()
                            }
                            .frame(height: 20, alignment: .leading)
                            HStack {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("# \(team_ranking(rank: rank).rank)")
                                            .font(.system(size: 16))
                                        Text("\(team_ranking(rank: rank).combined_score)")
                                            .font(.system(size: 16))
                                    }
                                    .frame(width: 60, alignment: .leading)
                                    Spacer()
                                    VStack(alignment: .leading) {
                                        Text(autonomousLabel)
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                        Text("Attempts: \(team_ranking(rank: rank).programming_attempts)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                        Text("Score: \(team_ranking(rank: rank).programming_score)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 145, alignment: .leading)
                                    Spacer()
                                    VStack(alignment: .leading) {
                                        Text(driverLabel)
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                        Text("Attempts: \(team_ranking(rank: rank).driver_attempts)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                        Text("Score: \(team_ranking(rank: rank).driver_score)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 100, alignment: .leading)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .searchable(text: $teamNumberQuery, prompt: "Enter a team number...")
                .tint(settings.topBarContentColor())
            }
        }
        .task {
            fetch_rankings()
        }
        .background(.clear)
        .toolbar {
            // Principal title in toolbar.
            ToolbarItem(placement: .principal) {
                Text("Skills Rankings")
                    .fontWeight(.medium)
                    .font(.system(size: 19))
                    .foregroundColor(settings.topBarContentColor())
            }
            // Add refresh button, styled like your note button.
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    // Trigger refresh.
                    fetch_rankings()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundColor(settings.topBarContentColor())
                .accessibilityLabel("Refresh")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(settings.buttonColor())
    }
}

struct EventSkillsRankings_Previews: PreviewProvider {
    static var previews: some View {
        EventSkillsRankings(event: Event(), teams_map: [String: String]())
    }
}
