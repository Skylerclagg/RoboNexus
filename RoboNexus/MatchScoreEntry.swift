//
//  MatchScoreEntry.swift
//  RoboNexus
//
//  Created by Skyler Clagg on 3/25/25.
//


import SwiftUI

// MARK: - Helper Structure & Extensions

/// Represents one match’s score, alliance partner, and match details.
struct MatchScoreEntry: Identifiable {
    let id: Int               // Match ID
    let score: Double         // Score from your alliance (head-to-head)
    let matchName: String     // Name of the match (e.g., "Match #1")
    let alliancePartner: String  // Opponent team(s) (i.e. your alliance partner in head-to-head)
    let eventName: String     // The event name
    let matchDate: String     // The match start date (as provided by the API)
    let matchNumber: Int      // The match number (e.g., 1, 2, etc.)
}

/// Array extension to calculate the average of doubles.
extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0.0, +) / Double(count)
    }
}

// MARK: - TeamworkMatchStatsSheet View

struct TeamworkMatchStatsSheet: View {
    let team: Team
    let season: Int

    @State private var matchEntries: [MatchScoreEntry] = []
    @State private var overallAverage: Double = 0.0
    @State private var top5Average: Double = 0.0
    @State private var top10Average: Double = 0.0
    @State private var top20Average: Double = 0.0
    @State private var isLoading: Bool = true
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Match Stats...")
                        .padding()
                } else {
                    List {
                        Section(header: Text("Top 4 Matches")) {
                            ForEach(Array(matchEntries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("#\(index + 1)")
                                        .font(.headline)
                                    Text(entry.matchName)
                                        .font(.subheadline)
                                    Text("Event: \(entry.eventName)")
                                        .font(.subheadline)
                                    Text("Date: \(entry.matchDate)")
                                        .font(.subheadline)
                                    HStack {
                                        Text("Score: \(String(format: "%.0f", entry.score))")
                                        Spacer()
                                        Text("Partner: \(entry.alliancePartner.isEmpty ? "N/A" : entry.alliancePartner)")
                                    }
                                    .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        Section(header: Text("Averages")) {
                            HStack {
                                Text("Overall Avg:")
                                Spacer()
                                Text(String(format: "%.2f", overallAverage))
                            }
                            HStack {
                                Text("Top 5 Avg:")
                                Spacer()
                                Text(String(format: "%.2f", top5Average))
                            }
                            HStack {
                                Text("Top 10 Avg:")
                                Spacer()
                                Text(String(format: "%.2f", top10Average))
                            }
                            HStack {
                                Text("Top 20 Avg:")
                                Spacer()
                                Text(String(format: "%.2f", top20Average))
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Teamwork Match Stats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadMatchStats()
            }
        }
    }
    
    /// Converts an ISO8601 date string to "MM/dd/yyyy" format.
    private func formattedDate(from isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: isoString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            return formatter.string(from: date)
        }
        return isoString
    }
    
    // MARK: - Load and Process Match Data
    func loadMatchStats() {
        // Fetch the matches data for the team and season.
        let matchesData = ADCHubAPI.teamMatchesForSeason(teamID: team.id, season: season)
        
        var entries: [MatchScoreEntry] = []
        
        for matchDict in matchesData {
            // Extract basic match info.
            guard let matchId = matchDict["id"] as? Int,
                  let matchName = matchDict["name"] as? String,
                  let alliances = matchDict["alliances"] as? [[String: Any]] else { continue }
            
            // Extract event details.
            let eventDict = matchDict["event"] as? [String: Any]
            let eventName = eventDict?["name"] as? String ?? "Unknown Event"
            let matchNumber = matchDict["matchnum"] as? Int ?? 0
            // Retrieve the raw date string and format it.
            let rawDate = (matchDict["started"] as? String) ?? (matchDict["scheduled"] as? String) ?? "No Date"
            let matchDate = formattedDate(from: rawDate)
            
            // Use head-to-head logic: if there are exactly two alliances.
            if alliances.count == 2 {
                var myAlliance: [String: Any]? = nil
                var opponentAlliance: [String: Any]? = nil
                
                for alliance in alliances {
                    guard let teams = alliance["teams"] as? [[String: Any]] else { continue }
                    let teamIDs = teams.compactMap { teamInfo -> Int? in
                        if let teamContainer = teamInfo["team"] as? [String: Any],
                           let id = teamContainer["id"] as? Int {
                            return id
                        }
                        return nil
                    }
                    if teamIDs.contains(team.id) {
                        myAlliance = alliance
                    } else {
                        opponentAlliance = alliance
                    }
                }
                
                if let myAlliance = myAlliance, let opponentAlliance = opponentAlliance {
                    var score: Double? = nil
                    if let scoreDouble = myAlliance["score"] as? Double {
                        score = scoreDouble
                    } else if let scoreInt = myAlliance["score"] as? Int {
                        score = Double(scoreInt)
                    }
                    if let teams = opponentAlliance["teams"] as? [[String: Any]] {
                        // Extract the opponent team's "name" (which is their team number).
                        let partnerNames = teams.compactMap { teamInfo -> String? in
                            if let teamContainer = teamInfo["team"] as? [String: Any],
                               let teamNumber = teamContainer["name"] as? String {
                                return teamNumber
                            }
                            return nil
                        }
                        let partnerString = partnerNames.joined(separator: ", ")
                        if let score = score {
                            let entry = MatchScoreEntry(
                                id: matchId,
                                score: score,
                                matchName: matchName,
                                alliancePartner: partnerString.isEmpty ? "N/A" : partnerString,
                                eventName: eventName,
                                matchDate: matchDate,
                                matchNumber: matchNumber
                            )
                            entries.append(entry)
                        }
                    }
                    continue
                }
            }
            
            // Fallback: if not exactly two alliances.
            for alliance in alliances {
                guard let teams = alliance["teams"] as? [[String: Any]] else { continue }
                for teamInfo in teams {
                    if let teamContainer = teamInfo["team"] as? [String: Any],
                       let id = teamContainer["id"] as? Int,
                       id == team.id {
                        var score: Double? = nil
                        if let scoreDouble = alliance["score"] as? Double {
                            score = scoreDouble
                        } else if let scoreInt = alliance["score"] as? Int {
                            score = Double(scoreInt)
                        }
                        let partners = teams.compactMap { info -> String? in
                            if let container = info["team"] as? [String: Any],
                               let teamNum = container["name"] as? String,
                               let teamId = container["id"] as? Int,
                               teamId != team.id {
                                return teamNum
                            }
                            return nil
                        }
                        let partnerString = partners.joined(separator: ", ")
                        if let score = score {
                            let entry = MatchScoreEntry(
                                id: matchId,
                                score: score,
                                matchName: matchName,
                                alliancePartner: partnerString.isEmpty ? "N/A" : partnerString,
                                eventName: eventName,
                                matchDate: matchDate,
                                matchNumber: matchNumber
                            )
                            entries.append(entry)
                        }
                        break
                    }
                }
            }
        }
        
        // Sort entries in descending order by score.
        entries.sort { $0.score > $1.score }
        matchEntries = entries
        
        let allScores = entries.map { $0.score }
        overallAverage = allScores.average
        top5Average = entries.prefix(5).map { $0.score }.average
        top10Average = entries.prefix(10).map { $0.score }.average
        top20Average = entries.prefix(20).map { $0.score }.average
        
        isLoading = false
    }
}
