///
///  FavoriteTeamsMatches.swift
///  ADC Hub
///
///  Aggregates and displays all matches for the user's favorited teams in a single list.
///
///  Created by Skyler Clagg on 4/21/25.
///

import SwiftUI
import CoreData

/// A view that aggregates and shows all matches for the teams the user has favorited.
struct FavoriteTeamsMatches: View {
    // MARK: - Environment Objects
    @EnvironmentObject var settings: UserSettings           // For theming (colors, etc.)
    @EnvironmentObject var favorites: FavoriteStorage       // Provides favorited team numbers
    @EnvironmentObject var dataController: ADCHubDataController  // For fetching notes, caching, etc.

    // MARK: - Inputs
    @Binding var teams_map: [String: String]                // Maps team IDs → team numbers
    @State var event: Event                                 // Current event reference
    @State var event_teams: [Team]                          // All teams at this event

    // MARK: - View State
    @State private var matches = [Match]()                  // Filtered matches for favorites
    @State private var matchOwners = [Team]()               // Which favorite team owns each match
    @State private var matches_list = [String]()            // Encoded strings for MatchRowView
    @State private var showLoading = true                   // Controls loading state

    // MARK: - Data Loading
    private func fetchFavoriteTeamMatches() {
        // 1) Capture favorited team numbers
        let favoriteNums = favorites.favoriteTeams

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // 2) Ensure event matches are fetched
            for division in event.divisions {
                try? event.fetch_matches(division: division)
            }

            // 3) Filter event_teams to favorited
            let favoriteEventTeams = event_teams.filter { favoriteNums.contains($0.number) }

            // 4) Collect (match, owner) pairs
            var tuples: [(match: Match, owner: Team)] = []
            for team in favoriteEventTeams {
                let teamMatches = team.matches_at(event: event)
                for match in teamMatches {
                    tuples.append((match: match, owner: team))
                }
            }

            // 5) Sort by match start or scheduled date
            let sortedTuples = tuples.sorted(by: { lhs, rhs in
                let date1 = lhs.match.started ?? lhs.match.scheduled ?? Date.distantPast
                let date2 = rhs.match.started ?? rhs.match.scheduled ?? Date.distantPast
                return date1 < date2
            })

            // 6) Separate into arrays
            let sortedMatches = sortedTuples.map { $0.match }
            let owners = sortedTuples.map { $0.owner }

            // 7) Encode matches for MatchRowView
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"

            let encoded: [String] = sortedMatches.enumerated().map { idx, match in
                let shortName = match.name
                    .replacingOccurrences(of: "Qualifier", with: "Q")
                    .replacingOccurrences(of: "Practice",   with: "P")
                    .replacingOccurrences(of: "Match",      with: "F")
                    .replacingOccurrences(of: "#",          with: "")

                let timeString: String = {
                    if let started   = match.started   { return formatter.string(from: started) }
                    if let scheduled = match.scheduled { return formatter.string(from: scheduled) }
                    return " "
                }()

                return "\(idx)&&\(shortName)&&"
                     + "\(match.red_alliance[0].id)&&\(match.red_alliance[1].id)&&"
                     + "\(match.blue_alliance[0].id)&&\(match.blue_alliance[1].id)&&"
                     + "\(match.red_score)&&\(match.blue_score)&&"
                     + timeString
            }

            // 8) Publish to main thread
            DispatchQueue.main.async {
                self.matches = sortedMatches
                self.matchOwners = owners
                self.matches_list = encoded
                self.showLoading = false
            }
        }
    }

    // MARK: - View Body
    var body: some View {
        VStack {
            if showLoading {
                ProgressView("Loading…").padding()
                Spacer()

            } else if matches.isEmpty {
                NoData()

            } else {
                List(matches_list.indices, id: \.self) { idx in
                    MatchRowView(
                        event:      $event,
                        matches:    $matches,
                        teams_map:  $teams_map,
                        matchString: .constant(matches_list[idx]),
                        team:       .constant(matchOwners[idx])
                    )
                }
            }
        }
        .onAppear { fetchFavoriteTeamMatches() }
        .navigationTitle("Favorite Teams Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible,            for: .navigationBar)
        .tint(settings.buttonColor())
        .background(.clear)
    }
}

// MARK: - Preview
struct FavoriteTeamsMatches_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FavoriteTeamsMatches(
                teams_map:   .constant([:]),
                event:       Event(),
                event_teams: []
            )
            .environmentObject(UserSettings())
            .environmentObject(FavoriteStorage())
            .environmentObject(ADCHubDataController())
        }
    }
}
