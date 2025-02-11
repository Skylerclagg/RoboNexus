//
//  EventDivisionRankings.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

class EventDivisionRankingsList: ObservableObject {
    @Published var rankings_indexes: [Int]
    
    init(rankings_indexes: [Int] = []) {
        // Sort them if needed; here, we just store them.
        self.rankings_indexes = rankings_indexes.sorted()
    }
    
    func sort_by(option: Int, event: Event, division: Division) {
        // For now, we only support a "rank" sort (option == 0).
        // If you have more advanced sorting, add it here.
        if option == 0 {
            // Just create an array of indexes in ascending order
            self.rankings_indexes = Array(0 ..< (event.rankings[division]?.count ?? 0))
        }
    }
}

struct EventDivisionRankings: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    
    @State var event: Event
    @State var division: Division
    @State var teams_map: [String: String]
    
    @State var event_rankings_list: EventDivisionRankingsList
    @State var showLoading = true
    @State var showingSheet = false
    @State var sortingOption = 0
    @State var teamNumberQuery = ""
    
    var searchResults: [Int] {
        if teamNumberQuery.isEmpty {
            return event_rankings_list.rankings_indexes.reversed()
        } else {
            return event_rankings_list.rankings_indexes.reversed().filter { index in
                let mappedID = teams_map[String(team_ranking(rank: index).team.id)] ?? ""
                return mappedID.lowercased().contains(teamNumberQuery.lowercased())
            }
        }
    }
    
    init(event: Event, division: Division, teams_map: [String: String]) {
        self.event = event
        self.division = division
        self.teams_map = teams_map
        self.event_rankings_list = EventDivisionRankingsList()
    }
    
    func fetch_rankings() {
        DispatchQueue.global(qos: .userInteractive).async {
            event.fetch_rankings(division: division)
            var fetchedIndexes = [Int]()
            if let divisionRankings = event.rankings[division] {
                for i in 0..<divisionRankings.count {
                    fetchedIndexes.append(i)
                }
            }
            DispatchQueue.main.async {
                self.event_rankings_list = EventDivisionRankingsList(rankings_indexes: fetchedIndexes)
                self.showLoading = false
            }
        }
    }
    
    func team_ranking(rank: Int) -> TeamRanking {
        return event.rankings[division]![rank]
    }
    
    var body: some View {
        VStack {
            if settings.selectedProgram == "Aerial Drone Competition" || settings.selectedProgram == "VEX IQ Robotics Competition" {
                adcOrIqView
            } else {
                otherProgramView
            }
        }
        .task {
            fetch_rankings()
        }
        .onAppear {
            navigation_bar_manager.title = "\(division.name) Rankings"
        }
    }
    
    // MARK: - ADC or IQ View (Only AVG Points)
    @ViewBuilder
    var adcOrIqView: some View {
        Group {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else if (event.rankings[division] ?? []).isEmpty {
                NoData()
            } else {
                VStack {
                    // Sorting Picker
                    Picker("Sort", selection: $sortingOption) {
                        Text("Rank").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .padding([.top, .leading, .trailing], 10)
                    .onChange(of: sortingOption) { option in
                        self.event_rankings_list.sort_by(option: option, event: self.event, division: self.division)
                        self.showLoading.toggle()
                        self.showLoading.toggle()
                    }
                    .onShake {
                        self.sortingOption = 0
                        self.event_rankings_list.sort_by(option: self.sortingOption, event: self.event, division: self.division)
                        self.showLoading.toggle()
                        self.showLoading.toggle()
                        let sel = UISelectionFeedbackGenerator()
                        sel.selectionChanged()
                    }
                    
                    // Rankings List
                    NavigationView {
                        List {
                            ForEach(searchResults, id: \.self) { rankIndex in
                                let ranking = team_ranking(rank: rankIndex)
                                let teamID = String(ranking.team.id)
                                let mappedNumber = teams_map[teamID] ?? ""
                                
                                NavigationLink(
                                    destination: EventTeamMatches(
                                        teams_map: $teams_map,
                                        event: self.event,
                                        team: Team(id: ranking.team.id, fetch: false),
                                        division: self.division
                                    )
                                    .environmentObject(settings)
                                    .environmentObject(dataController)
                                ) {
                                    TeamRankingRow(ranking: ranking, mappedNumber: mappedNumber, event: event, showAdditionalStats: false)
                                        .environmentObject(favorites)
                                }
                            }
                        }
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .searchable(text: $teamNumberQuery, prompt: "Enter a team number...")
                    .tint(settings.topBarContentColor())
                }
            }
        }
    }
    
    // MARK: - Other Program View (Full Stats)
    @ViewBuilder
    var otherProgramView: some View {
        Group {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else if (event.rankings[division] ?? []).isEmpty {
                NoData()
            } else {
                VStack {
                    List {
                        ForEach(searchResults, id: \.self) { rank in
                            let ranking = team_ranking(rank: rank)
                            let mappedNumber = teams_map[String(ranking.team.id)] ?? ""
                            
                            NavigationLink(
                                destination: EventTeamMatches(
                                    teams_map: $teams_map,
                                    event: self.event,
                                    team: Team(id: ranking.team.id, fetch: false),
                                    division: self.division
                                )
                                .environmentObject(settings)
                                .environmentObject(dataController)
                            ){
                                TeamRankingRow(ranking: ranking, mappedNumber: mappedNumber, event: event, showAdditionalStats: true)
                                    .environmentObject(favorites)
                            }
                        }
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .searchable(text: $teamNumberQuery, prompt: "Enter a team number...")
                    .tint(settings.topBarContentColor())
                }
            }
        }
    }
}

// MARK: - TeamRankingRow (Reusable View)
struct TeamRankingRow: View {
    let ranking: TeamRanking
    let mappedNumber: String
    let event: Event
    let showAdditionalStats: Bool
    @EnvironmentObject var favorites: FavoriteStorage
    
    var body: some View {
        VStack {
            // Top row with team number, team name, and star for favorites
            HStack {
                Text(mappedNumber)
                    .font(.system(size: 20))
                    .minimumScaleFactor(0.01)
                    .frame(width: 70, alignment: .leading)
                    .bold()
                
                Text(event.get_team(id: ranking.team.id)?.name ?? "")
                    .frame(alignment: .leading)
                Spacer()
                
                if favorites.favoriteTeams.contains(mappedNumber) {
                    Image(systemName: "star.fill")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 20)
            
            // Bottom row with stats
            if showAdditionalStats {
                // Full stats for other programs
                HStack {
                    VStack(alignment: .leading) {
                        Text("# \(ranking.rank)")
                            .font(.system(size: 16))
                        Text("\(ranking.wins)-\(ranking.losses)-\(ranking.ties)")
                            .font(.system(size: 16))
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("WP: \(ranking.wp)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("AP: \(ranking.ap)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("AVG: " + displayRounded(number: ranking.average_points))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("SP: \(ranking.sp)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("TTL: \(ranking.total_points)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Only AVG for ADC and IQ
                HStack {
                    VStack(alignment: .leading) {
                        Text("# \(ranking.rank)")
                            .font(.system(size: 32))
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("AVG Points: " + displayRounded(number: ranking.average_points))
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct EventDivisionRankings_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionRankings(
            event: Event(),
            division: Division(id: 123, name: "Sample Division"),
            teams_map: ["10": "12345A"]
        )
    }
}
