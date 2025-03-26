//
//  DataExporter.swift
//
//  ADC Hub
//
//  Based on
//VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import OrderedCollections

// MARK: - VRC Data Analysis Stub

struct VRCDataAnalysis {
    var total_wins: Int = 0
    var total_losses: Int = 0
    var total_ties: Int = 0
}

func vrc_data_analysis_for(team: Team, fetch_re_match_statistics: Bool = false) -> VRCDataAnalysis {
    // This is a stub. Replace with your actual data analysis logic.
    var analysis = VRCDataAnalysis()
    // Example: Try to get rankings data from the (stubbed) API call.
    let re_rankings_data = ADCHubAPI.robotevents_request(request_url: "/teams/\(team.id)/rankings", params: ["season": API.selected_season_id()])
    for comp in re_rankings_data {
        analysis.total_wins += comp["wins"] as? Int ?? 0
        analysis.total_losses += comp["losses"] as? Int ?? 0
        analysis.total_ties += comp["ties"] as? Int ?? 0
    }
    // You might also add some match analysis here.
    return analysis
}

// MARK: - DataExporter View

struct DataExporter: View {
    
    @EnvironmentObject var settings: UserSettings
    
    // MARK: - Properties
    
    @State var event: Event
    @State var division: Division? = nil
    @State var teams_list: [String] = []
    @State var showLoading = true
    @State var progress: Double = 0
    @State var csv_string: String = ""
    @State var show_option = 0
    @State var view_closed = false
    
    // The export options dictionary (key: export field; value: include it)
    @State var selected: OrderedDictionary<String, Bool> = OrderedDictionary<String, Bool>()
    // The sections dictionary maps section names to index ranges in the keys array.
    @State var sections: OrderedDictionary<String, [Int]> = OrderedDictionary<String, [Int]>()
    
    /// Optional external team numbers. If non-nil, these team numbers will be used instead of fetching from event.rankings or event.matches.
    var externalTeamNumbers: [String]? = nil
    
    // MARK: - Helper Functions
    
    func generate_location(team: Team) -> String {
        let location_array = [team.city, team.region, team.country].filter { !$0.isEmpty }
        return location_array.joined(separator: " ")
    }
    
    /// Local helper function to extract season scores for a given team.
    func seasonScores(for team: Team) -> [Double] {
        let matchesData = ADCHubAPI.teamMatchesForSeason(teamID: team.id, season: API.selected_season_id())
        var scores: [Double] = []
        
        for matchDict in matchesData {
            guard let alliances = matchDict["alliances"] as? [[String: Any]] else { continue }
            if alliances.count == 2 {
                var myAlliance: [String: Any]? = nil
                for alliance in alliances {
                    if let teams = alliance["teams"] as? [[String: Any]] {
                        let teamIDs = teams.compactMap { teamInfo -> Int? in
                            if let teamContainer = teamInfo["team"] as? [String: Any],
                               let id = teamContainer["id"] as? Int {
                                return id
                            }
                            return nil
                        }
                        if teamIDs.contains(team.id) {
                            myAlliance = alliance
                            break
                        }
                    }
                }
                if let myAlliance = myAlliance {
                    if let score = myAlliance["score"] as? Double {
                        scores.append(score)
                    } else if let scoreInt = myAlliance["score"] as? Int {
                        scores.append(Double(scoreInt))
                    }
                }
            } else {
                for alliance in alliances {
                    if let teams = alliance["teams"] as? [[String: Any]] {
                        for teamInfo in teams {
                            if let teamContainer = teamInfo["team"] as? [String: Any],
                               let id = teamContainer["id"] as? Int,
                               id == team.id {
                                if let score = alliance["score"] as? Double {
                                    scores.append(score)
                                } else if let scoreInt = alliance["score"] as? Int {
                                    scores.append(Double(scoreInt))
                                }
                                break
                            }
                        }
                    }
                }
            }
        }
        return scores
    }
    
    func fetch_teams_list() {
        showLoading = true
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            
            if let division = self.division, !self.event.rankings.keys.contains(division) {
                self.event.fetch_rankings(division: division)
            }
            if let division = self.division, self.event.rankings[division]?.isEmpty ?? true,
               !self.event.matches.keys.contains(division) {
                self.event.fetch_matches(division: division)
            }
            
            DispatchQueue.main.async {
                self.teams_list = []
                if let division = self.division, let rankings = self.event.rankings[division], !rankings.isEmpty {
                    for ranking in rankings {
                        self.teams_list.append(event.get_team(id: ranking.team.id)?.number ?? "")
                    }
                } else if let division = self.division {
                    for match in self.event.matches[division] ?? [] {
                        var match_teams = match.red_alliance
                        match_teams.append(contentsOf: match.blue_alliance)
                        for team in match_teams {
                            let t = event.get_team(id: team.id)?.number ?? ""
                            if !self.teams_list.contains(t) { self.teams_list.append(t) }
                        }
                    }
                } else {
                    self.teams_list = self.event.teams.map { $0.number }
                }
                self.teams_list.sort()
                self.teams_list.sort {
                    (Int($0.filter("0123456789".contains)) ?? 0) < (Int($1.filter("0123456789".contains)) ?? 0)
                }
                showLoading = false
            }
        }
    }
    
    // MARK: - Extracted UI Sections
    
    var teamInfoSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Team Info")
                Spacer()
                Image(systemName: show_option == 0 ? "chevron.up.circle" : "chevron.down.circle")
            }
            .contentShape(Rectangle())
            .onTapGesture { show_option = 0 }
            if show_option == 0 {
                ForEach(Array(Array(selected.keys)[0...2]), id: \.self) { option in
                    HStack {
                        Text(option.replacingOccurrences(of: " (slow)", with: ""))
                            .foregroundColor(.secondary)
                        Spacer()
                        if selected[option] ?? false {
                            Image(systemName: "checkmark")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if progress == 0 || progress == 1 {
                            selected[option] = !(selected[option] ?? false)
                            progress = 0
                        }
                    }
                }
            }
        }
    }
    
    var performanceSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Performance Statistics")
                Spacer()
                Image(systemName: show_option == 1 ? "chevron.up.circle" : "chevron.down.circle")
            }
            .contentShape(Rectangle())
            .onTapGesture { show_option = 1 }
            if show_option == 1 {
                if settings.selectedProgram == "Aerial Drone Competition" ||
                   settings.selectedProgram == "VEX IQ Robotics Competition" {
                    ForEach(Array(Array(selected.keys)[3...6]), id: \.self) { option in
                        HStack {
                            Text(option.replacingOccurrences(of: " (slow)", with: ""))
                                .foregroundColor(.secondary)
                            Spacer()
                            if selected[option] ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if progress == 0 || progress == 1 {
                                selected[option] = !(selected[option] ?? false)
                                progress = 0
                            }
                        }
                    }
                } else {
                    ForEach(Array(Array(selected.keys)[3...10]), id: \.self) { option in
                        HStack {
                            Text(option.replacingOccurrences(of: " (slow)", with: ""))
                                .foregroundColor(.secondary)
                            Spacer()
                            if selected[option] ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if progress == 0 || progress == 1 {
                                selected[option] = !(selected[option] ?? false)
                                progress = 0
                            }
                        }
                    }
                }
            }
        }
    }
    
    var skillsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Skills Data")
                Spacer()
                Image(systemName: show_option == 2 ? "chevron.up.circle" : "chevron.down.circle")
            }
            .contentShape(Rectangle())
            .onTapGesture { show_option = 2 }
            if show_option == 2 {
                if settings.selectedProgram == "Aerial Drone Competition" ||
                   settings.selectedProgram == "VEX IQ Robotics Competition" {
                    ForEach(Array(Array(selected.keys)[7...10]), id: \.self) { option in
                        HStack {
                            Text(option.replacingOccurrences(of: " (slow)", with: ""))
                                .foregroundColor(.secondary)
                            Spacer()
                            if selected[option] ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if progress == 0 || progress == 1 {
                                selected[option] = !(selected[option] ?? false)
                                progress = 0
                            }
                        }
                    }
                } else {
                    ForEach(Array(Array(selected.keys)[11...14]), id: \.self) { option in
                        HStack {
                            Text(option.replacingOccurrences(of: " (slow)", with: ""))
                                .foregroundColor(.secondary)
                            Spacer()
                            if selected[option] ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if progress == 0 || progress == 1 {
                                selected[option] = !(selected[option] ?? false)
                                progress = 0
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else {
                Spacer()
                Text("\(teams_list.count) Teams")
                Spacer()
                ScrollView {
                    VStack(spacing: 40) {
                        teamInfoSection
                        performanceSection
                        skillsSection
                        // Show Season Scores section for the relevant programs.
                        if settings.selectedProgram == "Aerial Drone Competition" ||
                           settings.selectedProgram == "VEX IQ Robotics Competition" {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Season Scores")
                                    Spacer()
                                }
                                ForEach(Array(Array(selected.keys)[11...15]), id: \.self) { option in
                                    HStack {
                                        Text(option)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if selected[option] ?? false {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if progress == 0 || progress == 1 {
                                            selected[option] = !(selected[option] ?? false)
                                            progress = 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                Spacer()
                ProgressView(value: progress)
                    .padding()
                    .tint(settings.buttonColor())
                if progress != 1 {
                    Button("Generate") {
                        if progress != 0 { return }
                        progress = 0.001
                        DispatchQueue.global(qos: .userInteractive).async { [self] in
                            var data = "Team Number"
                            for (option, state) in selected {
                                guard state else { continue }
                                data += ",\(option)"
                            }
                            data += "\n"
                            var count = 0
                            for number in teams_list {
                                if view_closed { return }
                                data += number
                                let team = event.teams.first(where: { $0.number == number })!
                                let world_skills = API.world_skills_for(team: team) ?? WorldSkills(team: team, data: [:])
                                let analysis = vrc_data_analysis_for(team: team, fetch_re_match_statistics: false)
                                
                                for (option, state) in selected {
                                    guard state else { continue }
                                    if option == "Team Name" {
                                        data += ",\(team.name.replacingOccurrences(of: ",", with: ""))"
                                    } else if option == "Robot Name" || option == "Drone Name" {
                                        data += ",\(team.robot_name.replacingOccurrences(of: ",", with: ""))"
                                    } else if option == "Team Location" {
                                        data += ",\(generate_location(team: team).replacingOccurrences(of: ",", with: ""))"
                                    } else if option == "Average Qualifiers Ranking (slow)" {
                                        data += ",\(team.average_ranking())"
                                        sleep(2)
                                    } else if option == "Total Events Attended (slow)" {
                                        if selected["Average Qualifiers Ranking (slow)"]! {
                                            data += ",\(team.event_count)"
                                        } else {
                                            team.fetch_events()
                                            data += ",\(team.events.count)"
                                            sleep(2)
                                        }
                                    } else if option == "Total Awards (slow)" {
                                        team.fetch_awards()
                                        data += ",\(team.awards.count)"
                                        sleep(2)
                                    } else if option == "Total Matches" {
                                        data += ",\(analysis.total_wins + analysis.total_losses + analysis.total_ties)"
                                    } else if option == "Total Wins" {
                                        data += ",\(analysis.total_wins)"
                                    } else if option == "Total Losses" {
                                        data += ",\(analysis.total_losses)"
                                    } else if option == "Total Ties" {
                                        data += ",\(analysis.total_ties)"
                                    } else if option == "Winrate" {
                                        let total = analysis.total_wins + analysis.total_losses + analysis.total_ties
                                        let winrate = total > 0 ? (Double(analysis.total_wins) / Double(total)) : 0
                                        data += ",\(String(format: "%.1f", winrate))"
                                    } else if option == "World Skills Ranking" {
                                        data += ",\(world_skills.ranking)"
                                    } else if option == "Combined Skills" {
                                        data += ",\(world_skills.combined)"
                                    } else if option == "Programming Skills" || option == "Autonomous Flight Skills" {
                                        data += ",\(world_skills.programming)"
                                    } else if option == "Driver Skills" || option == "Piloting Skills" {
                                        data += ",\(world_skills.driver)"
                                    }
                                    // New season score fields.
                                    else if option == "Top 4 Highest Scores" {
                                        let seasonScores = seasonScores(for: team)
                                        let top4 = seasonScores.sorted(by: >).prefix(4)
                                        data += ",\(top4.map { String(format: "%.1f", $0) }.joined(separator: ";"))"
                                    } else if option == "Season Average" {
                                        let seasonScores = seasonScores(for: team)
                                        let overallAvg = seasonScores.isEmpty ? 0.0 : seasonScores.reduce(0, +) / Double(seasonScores.count)
                                        data += ",\(String(format: "%.1f", overallAvg))"
                                    } else if option == "Top 5 Average" {
                                        let seasonScores = seasonScores(for: team)
                                        let top5 = seasonScores.sorted(by: >).prefix(5)
                                        let avg = top5.isEmpty ? 0.0 : top5.reduce(0, +) / Double(top5.count)
                                        data += ",\(String(format: "%.1f", avg))"
                                    } else if option == "Top 10 Average" {
                                        let seasonScores = seasonScores(for: team)
                                        let top10 = seasonScores.sorted(by: >).prefix(10)
                                        let avg = top10.isEmpty ? 0.0 : top10.reduce(0, +) / Double(top10.count)
                                        data += ",\(String(format: "%.1f", avg))"
                                    } else if option == "Top 20 Average" {
                                        let seasonScores = seasonScores(for: team)
                                        let top20 = seasonScores.sorted(by: >).prefix(20)
                                        let avg = top20.isEmpty ? 0.0 : top20.reduce(0, +) / Double(top20.count)
                                        data += ",\(String(format: "%.1f", avg))"
                                    }
                                }
                                data += "\n"
                                count += 1
                                DispatchQueue.main.async {
                                    progress = Double(count) / Double(teams_list.count)
                                }
                            }
                            csv_string = data
                            progress = 1
                        }
                    }
                    .padding(10)
                    .background(settings.buttonColor())
                    .foregroundColor(.white)
                    .cornerRadius(20)
                } else {
                    Button("Save") {
                        let dataPath = URL.documentsDirectory.appendingPathComponent("ScoutingData")
                        if !FileManager.default.fileExists(atPath: dataPath.path) {
                            do {
                                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                            } catch {
                                print("Error")
                                print(error.localizedDescription)
                            }
                        }
                        var fileName: String {
                            if let division = division {
                                return "\(division.name.convertedToSlug() ?? String(describing: division.id))-\(event.name.convertedToSlug() ?? event.sku).csv"
                            } else {
                                return "\(event.name.convertedToSlug() ?? event.sku).csv"
                            }
                        }
                        let url = dataPath.appending(path: fileName)
                        let csvData = csv_string.data(using: .utf8)!
                        try! csvData.write(to: url)
                        if let sharedUrl = URL(string: "shareddocuments://\(url.path)") {
                            if UIApplication.shared.canOpenURL(sharedUrl) {
                                UIApplication.shared.open(sharedUrl, options: [:])
                            }
                        }
                    }
                    .padding(10)
                    .background(settings.buttonColor())
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                Spacer()
            }
        }
        .onAppear {
            // If externalTeamNumbers is provided, use it; otherwise, fetch the teams list normally.
            if let external = externalTeamNumbers {
                teams_list = external
                showLoading = false
            } else {
                fetch_teams_list()
            }
            
            // Set up export options based on the selected program.
            let program = settings.selectedProgram
            if program == "Aerial Drone Competition" {
                selected = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Name", true),
                    ("Drone Name", true),
                    ("Team Location", true),
                    ("Average Qualifiers Ranking (slow)", false),
                    ("Total Events Attended (slow)", false),
                    ("Total Awards (slow)", false),
                    ("Total Matches", true),
                    ("World Skills Ranking", true),
                    ("Combined Skills", true),
                    ("Autonomous Flight Skills", true),
                    ("Piloting Skills", true),
                    ("Top 4 Highest Scores", true),
                    ("Season Average", true),
                    ("Top 5 Average", true),
                    ("Top 10 Average", true),
                    ("Top 20 Average", true)
                ])
                sections = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Info", [0, 2]),
                    ("Performance Statistics", [3, 6]),
                    ("Skills Data", [7, 10]),
                    ("Season Scores", [11, 15])
                ])
            } else if program == "VEX IQ Robotics Competition" {
                selected = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Name", true),
                    ("Robot Name", true),
                    ("Team Location", true),
                    ("Average Qualifiers Ranking (slow)", false),
                    ("Total Events Attended (slow)", false),
                    ("Total Awards (slow)", false),
                    ("Total Matches", true),
                    ("World Skills Ranking", true),
                    ("Combined Skills", true),
                    ("Programming Skills", true),
                    ("Driver Skills", true),
                    ("Top 4 Highest Scores", true),
                    ("Season Average", true),
                    ("Top 5 Average", true),
                    ("Top 10 Average", true),
                    ("Top 20 Average", true)
                ])
                sections = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Info", [0, 2]),
                    ("Performance Statistics", [3, 6]),
                    ("Skills Data", [7, 10]),
                    ("Season Scores", [11, 15])
                ])
            } else if program == "VEX University Robotics Competition" {
                selected = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Name", true),
                    ("Robot Name", true),
                    ("Team Location", true),
                    ("Average Qualifiers Ranking (slow)", false),
                    ("Total Events Attended (slow)", false),
                    ("Total Awards (slow)", false),
                    ("Total Matches", true),
                    ("Total Wins", true),
                    ("Total Losses", true),
                    ("Total Ties", true),
                    ("Winrate", true),
                    ("World Skills Ranking", true),
                    ("Combined Skills", true),
                    ("Programming Skills", true),
                    ("Driver Skills", true)
                ])
                sections = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Info", [0, 2]),
                    ("Performance Statistics", [3, 10]),
                    ("Skills Data", [11, 14])
                ])
            } else { // VEX V5 Robotics Competition (default)
                selected = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Name", true),
                    ("Robot Name", true),
                    ("Team Location", true),
                    ("Average Qualifiers Ranking (slow)", false),
                    ("Total Events Attended (slow)", false),
                    ("Total Awards (slow)", false),
                    ("Total Matches", true),
                    ("Total Wins", true),
                    ("Total Losses", true),
                    ("Total Ties", true),
                    ("Winrate", true),
                    ("World Skills Ranking", true),
                    ("Combined Skills", true),
                    ("Programming Skills", true),
                    ("Driver Skills", true)
                ])
                sections = OrderedDictionary(uniqueKeysWithValues: [
                    ("Team Info", [0, 2]),
                    ("Performance Statistics", [3, 10]),
                    ("Skills Data", [11, 14])
                ])
            }
        }
        .onDisappear {
            view_closed = true
        }
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Export Data")
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

struct DataExporter_Previews: PreviewProvider {
    static var previews: some View {
        DataExporter(event: Event())
    }
}
