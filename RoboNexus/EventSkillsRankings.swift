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

/// Holds the sorted list of ranking indices for the event.
class EventSkillsRankingsList: ObservableObject {
    @Published var rankings_indexes: [Int]

    init(rankings_indexes: [Int] = []) {
        self.rankings_indexes = rankings_indexes.sorted()
    }
}

struct EventSkillsRankings: View {
    @EnvironmentObject var settings: UserSettings
    @State var event: Event
    @State var teams_map: [String: String]
    @State var event_skills_rankings_list = EventSkillsRankingsList()
    @State private var showLoading = true
    @State private var teamNumberQuery = ""

    // MARK: - Computed Labels
    private var autonomousLabel: String {
        if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
            return "Autonomous Flight:"
        } else {
            return "Autonomous Coding:"
        }
    }
    private var driverLabel: String {
        if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
            return "Piloting:"
        } else {
            return "Driver:"
        }
    }

    // MARK: - Search Filtering
    private var searchResults: [Int] {
        guard !teamNumberQuery.isEmpty else {
            return event_skills_rankings_list.rankings_indexes
        }
        return event_skills_rankings_list.rankings_indexes.filter { index in
            let idText = teams_map[String(event.skills_rankings[index].team.id)] ?? ""
            return idText.lowercased().contains(teamNumberQuery.lowercased())
        }
    }

    // MARK: - Data Fetching
    private func fetch_rankings() {
        showLoading = true
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            event.fetch_skills_rankings()
            let indices = Array(event.skills_rankings.indices)
            DispatchQueue.main.async {
                event_skills_rankings_list = EventSkillsRankingsList(rankings_indexes: indices)
                showLoading = false
            }
        }
    }

    // MARK: - Extracted Row (reduces type-check complexity)
    @ViewBuilder private func rankingRow(_ rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Team header
            HStack {
                Text(teams_map[String(event.skills_rankings[rank].team.id)] ?? "")
                    .font(.system(size: 20))
                    .bold()
                    .frame(width: 70, alignment: .leading)
                    .minimumScaleFactor(0.01)
                Text(event.get_team(id: event.skills_rankings[rank].team.id)?.name ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 20)

            // Scores detail
            HStack(alignment: .top) {
                // Rank & combined score
                VStack(alignment: .leading, spacing: 4) {
                    Text("# \(event.skills_rankings[rank].rank)")
                        .font(.system(size: 16))
                    Text("\(event.skills_rankings[rank].combined_score)")
                        .font(.system(size: 16))
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                // Autonomous section
                VStack(alignment: .leading, spacing: 4) {
                    Text(autonomousLabel)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    if settings.selectedProgram == "Aerial Drone Competition" {
                        Text("Runs: \(event.skills_rankings[rank].programming_attempts)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Score: \(event.skills_rankings[rank].programming_score)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Attempts: \(event.skills_rankings[rank].programming_attempts)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Score: \(event.skills_rankings[rank].programming_score)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 145, alignment: .leading)

                Spacer()

                // Driver section
                if settings.selectedProgram != "VEX AI Robotics Competition" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(driverLabel)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Attempts: \(event.skills_rankings[rank].driver_attempts)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("Score: \(event.skills_rankings[rank].driver_score)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 100, alignment: .leading)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - View Body
    var body: some View {
        VStack {
            if showLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if event.skills_rankings.isEmpty {
                NoData()
            } else {
                List(searchResults, id: \.self) { rank in
                    rankingRow(rank)
                }
                .searchable(text: $teamNumberQuery, prompt: "Enter a team number...")
                .tint(settings.topBarContentColor())
            }
        }
        .task { fetch_rankings() }
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Skills Rankings")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(settings.topBarContentColor())
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { fetch_rankings() }) {
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

// MARK: - Preview
struct EventSkillsRankings_Previews: PreviewProvider {
    static var previews: some View {
        EventSkillsRankings(event: Event(), teams_map: [:])
            .environmentObject(UserSettings())
    }
}
