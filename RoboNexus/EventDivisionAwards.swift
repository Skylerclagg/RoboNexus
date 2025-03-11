//
//  EventDivisionAwards.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

private let allAroundEligibilityFeaturesEnabled: Bool = false
private let excellenceEligibilityFeaturesEnabled: Bool = true

// MARK: - Helper Structure for Precomputed Values (ADC & Excellence flows)
struct PrecomputedValues {
    let qualifierRank: Int
    let qualifierCutoff: Int
    let skillsRank: Int
    let skillsCutoff: Int
    let skillsData: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int)
}

// MARK: - Ineligibility Reasons Detail View
struct ADCIneligibilityReasonsView: View {
    let team: Team
    let reasons: [String]
    
    // Precomputed ranking values.
    let qualifierRank: Int
    let qualifierCutoff: Int
    let skillsRank: Int
    let skillsCutoff: Int
    
    // Precomputed skills data (scores and attempts).
    let skillsData: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int)
    
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why \(team.number) is NOT Eligible")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Display ranking info.
            let rankingEligible = (qualifierRank > 0 && qualifierRank <= qualifierCutoff)
            HStack {
                Text("Ranking:")
                Spacer()
                Text((qualifierRank > 0 ? "# \(qualifierRank)" : "No Data") + " (Cutoff: \(qualifierCutoff))")
                    .foregroundColor(rankingEligible ? .green : .red)
            }
            
            // Display skills ranking info.
            let skillsEligible = (skillsRank > 0 && skillsRank <= skillsCutoff)
            HStack {
                Text("Skills Ranking:")
                Spacer()
                Text((skillsRank > 0 ? "# \(skillsRank)" : "No Skills Ranking") + " (Cutoff: \(skillsCutoff))")
                    .foregroundColor(skillsEligible ? .green : .red)
            }
            
            Divider()
            
            // Display the ineligibility reasons.
            if reasons.isEmpty {
                Text("No reasons available.")
            } else {
                ForEach(reasons, id: \.self) { reason in
                    let transformed: String = {
                        if reason.contains("No programming attempts") {
                            return "- Programming: No Data"
                        } else if reason.contains("Programming score: 0") {
                            return "- Programming: Zero Score"
                        }
                        return reason
                    }()
                    
                    let color: Color = (transformed.contains("Qualifier Ranking:") || transformed.contains("Skills Ranking:") || transformed.contains("No")) ? .red : .green
                    Text(transformed)
                        .foregroundColor(color)
                        .padding(.vertical, 2)
                }
            }
            
            Divider()
            
            // Display skills scores based on the selected program.
            if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
                HStack {
                    Text("Autonomous Flight Skills Score:")
                    Spacer()
                    Text("\(skillsData.programming)")
                }
                HStack {
                    Text("Autonomous Flight Skills Attempts:")
                    Spacer()
                    Text("\(skillsData.programming_attempts)")
                }
                HStack {
                    Text("Piloting Skills Score:")
                    Spacer()
                    Text("\(skillsData.driver)")
                }
                HStack {
                    Text("Piloting Skills Attempts:")
                    Spacer()
                    Text("\(skillsData.driver_attempts)")
                }
            } else {
                HStack {
                    Text("Programming Skills Score:")
                    Spacer()
                    Text("\(skillsData.programming)")
                }
                HStack {
                    Text("Programming Skills Attempts:")
                    Spacer()
                    Text("\(skillsData.programming_attempts)")
                }
                HStack {
                    Text("Driver Skills Score:")
                    Spacer()
                    Text("\(skillsData.driver)")
                }
                HStack {
                    Text("Driver Skills Attempts:")
                    Spacer()
                    Text("\(skillsData.driver_attempts)")
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationBarTitle("Ineligibility Details", displayMode: .inline)
    }
}

// MARK: - Eligible Team Details View
struct EligibleTeamDetailsView: View {
    let event: Event
    let division: Division
    let team: Team
    
    // Compute the team’s qualifier ranking.
    var qualifierRank: Int {
        if let rankings = event.rankings[division] {
            let sorted = rankings.sorted { $0.rank < $1.rank }
            if let index = sorted.firstIndex(where: { $0.team.id == team.id }) {
                return index + 1
            }
        }
        return -1
    }
    
    // Compute the team’s skills ranking.
    var skillsRank: Int {
        let sorted = event.skills_rankings.sorted { $0.rank < $1.rank }
        if let index = sorted.firstIndex(where: { $0.team.id == team.id }) {
            return index + 1
        }
        return -1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Team \(team.number) Details")
                .font(.headline)
                .padding(.bottom, 5)
            if qualifierRank > 0 {
                Text("Qualifier Ranking: \(qualifierRank)")
                    .foregroundColor(.green)
            } else {
                Text("Qualifier Ranking: Not Ranked")
                    .foregroundColor(.green)
            }
            if skillsRank > 0 {
                Text("Skills Ranking: \(skillsRank)")
                    .foregroundColor(.green)
            } else {
                Text("Skills Ranking: Not Ranked")
                    .foregroundColor(.green)
            }
            Spacer()
        }
        .padding()
        .navigationBarTitle("Eligible Team Details", displayMode: .inline)
    }
}

// MARK: - Requirements Sheet View
struct RequirementsView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Requirements:")
                    .font(.headline)
                    .padding(.bottom, 5)
                BulletList(listItems: [
                    "Be ranked in the top 50% of qualification rankings at the conclusion of qualifying teamwork matches.",
                    "Be ranked in the top 50% of overall skills rankings at the conclusion of autonomous flight and piloting skills matches.",
                    "Participation in both the Piloting Skills Mission and the Autonomous Flight Skills Mission is required, with a score of greater than 0 in each Mission."
                ], listItemSpacing: 10)
                Spacer()
            }
            .padding()
            .navigationBarTitle("Requirements", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                // Dismissal handled by presenting view.
            })
        }
    }
}

// MARK: - Subviews for Excellence Eligibility

/// A row view for an eligible team (Excellence).
struct EligibleTeamRow: View {
    let team: Team
    let event: Event
    let division: Division
    let generateLocation: (Team) -> String
    
    var body: some View {
        NavigationLink(destination: EligibleTeamDetailsView(event: event, division: division, team: team)) {
            HStack {
                Text(team.number)
                    .font(.system(size: 20))
                    .frame(width: 80, alignment: .leading)
                    .bold()
                VStack(alignment: .leading) {
                    Text(team.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 20)
                    Spacer().frame(height: 5)
                    Text(generateLocation(team))
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// A row view for an ineligible team (Excellence) that now uses precomputed values.
struct IneligibleTeamRowExcellence: View {
    let team: Team
    let ineligibleReasons: [String]
    let precomputed: PrecomputedValues
    let generateLocation: (Team) -> String
    
    var body: some View {
        NavigationLink(destination: ADCIneligibilityReasonsView(
            team: team,
            reasons: ineligibleReasons,
            qualifierRank: precomputed.qualifierRank,
            qualifierCutoff: precomputed.qualifierCutoff,
            skillsRank: precomputed.skillsRank,
            skillsCutoff: precomputed.skillsCutoff,
            skillsData: precomputed.skillsData
        )) {
            HStack {
                Text(team.number)
                    .font(.system(size: 20))
                    .frame(width: 80, alignment: .leading)
                    .bold()
                VStack(alignment: .leading) {
                    Text(team.name)
                    Spacer().frame(height: 5)
                    Text(generateLocation(team))
                        .font(.system(size: 11))
                }
            }
        }
    }
}

/// A section view for eligible teams (Excellence).
struct EligibleTeamsSectionExcellence: View {
    let eligibleTeams: [Team]
    let event: Event
    let division: Division
    let generateLocation: (Team) -> String
    
    var body: some View {
        Section(header: Text("Eligible Teams")) {
            if eligibleTeams.isEmpty {
                Text("No eligible teams")
            } else {
                ForEach(eligibleTeams, id: \.id) { team in
                    EligibleTeamRow(team: team,
                                    event: event,
                                    division: division,
                                    generateLocation: generateLocation)
                }
            }
        }
    }
}

/// A section view for ineligible teams (Excellence).
struct IneligibleTeamsSectionExcellence: View {
    let ineligibleTeams: [Team]
    let ineligibleTeamsReasons: [Int: [String]]
    let precomputedExcellence: [Int: PrecomputedValues]
    let generateLocation: (Team) -> String
    
    var body: some View {
        Section(header: Text("Ineligible Teams")) {
            if ineligibleTeams.isEmpty {
                Text("All teams that meet the grade requirement are eligible.")
            } else {
                ForEach(ineligibleTeams, id: \.id) { team in
                    if let pre = precomputedExcellence[team.id] {
                        IneligibleTeamRowExcellence(
                            team: team,
                            ineligibleReasons: ineligibleTeamsReasons[team.id] ?? [],
                            precomputed: pre,
                            generateLocation: generateLocation
                        )
                    } else {
                        // Fallback in case precomputed value is missing.
                        NavigationLink(destination: ADCIneligibilityReasonsView(
                            team: team,
                            reasons: ineligibleTeamsReasons[team.id] ?? [],
                            qualifierRank: -1,
                            qualifierCutoff: 1,
                            skillsRank: -1,
                            skillsCutoff: 1,
                            skillsData: (0, 0, 0, 0)
                        )) {
                            HStack {
                                Text(team.number)
                                    .font(.system(size: 20))
                                    .frame(width: 80, alignment: .leading)
                                    .bold()
                                VStack(alignment: .leading) {
                                    Text(team.name)
                                    Spacer().frame(height: 5)
                                    Text(generateLocation(team))
                                        .font(.system(size: 11))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Excellence Eligible Teams View
struct ExcellenceEligibleTeams: View {
    // MARK: - Properties
    var event: Event
    let middleSchool: Bool
    let excellenceOffered: Bool
    let middleSchoolExcellenceOffered: Bool
    @State var eligible_teams: [Team] = []
    @State var ineligibleTeams: [Team] = []
    @State var ineligibleTeamsReasons: [Int: [String]] = [:]
    @State var showLoading = true
    @State var division: Division
    @State var precomputedExcellence: [Int: PrecomputedValues] = [:]

    // MARK: - Helper Functions
    func generate_location(team: Team) -> String {
        let parts = [team.city, team.region, team.country].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
    
    // We assume levelFilter and filteredSkillsRankings are similar to ADC flow.
    
    func fetch_info_excellence() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            guard !(event.rankings[division] ?? []).isEmpty, !event.skills_rankings.isEmpty else {
                DispatchQueue.main.async { self.showLoading = false }
                return
            }
            
            let awardsForDivision = event.awards[division] ?? []
            let excellenceAwards = awardsForDivision.filter { $0.title.contains("Excellence Award") }
            let hasMiddleSchoolAward = excellenceAwards.contains { $0.title.contains("Middle School") }
            let hasHighSchoolAward = excellenceAwards.contains { $0.title.contains("High School") }
            let isCombinedAward = !(hasMiddleSchoolAward && hasHighSchoolAward)
            let THRESHOLD = 0.4
            
            var eligible_teams_local = [Team]()
            var ineligibleTeams_local = [Team]()
            var ineligibleTeamsReasons_local = [Int: [String]]()
            precomputedExcellence = [:]
            
            if isCombinedAward {
                let qualifierRankings = event.rankings[division] ?? []
                let ranking_cutoff = max(1, Int((Double(qualifierRankings.count) * THRESHOLD).rounded(.toNearestOrAwayFromZero)))
                let rankings = qualifierRankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                let overall_skills_rankings = event.skills_rankings
                let overall_skills_sorted = overall_skills_rankings.sorted { $0.rank < $1.rank }
                let overall_skills_cutoff = max(1, Int(ceil(Double(overall_skills_rankings.count) * 0.5)))
                
                for team in event.teams {
                    var reasons = [String]()
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && hasProgrammingScore {
                        eligible_teams_local.append(team)
                    } else {
                        if !isInRankingCutoff {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                let qualifierRank = index + 1
                                reasons.append("- Qualifier Ranking: \(qualifierRank) (cutoff: \(ranking_cutoff))")
                            } else {
                                reasons.append("- Qualifier Ranking: Not ranked (cutoff: \(ranking_cutoff))")
                            }
                        }
                        if !hasProgrammingScore {
                            if let pr = programmingRanking {
                                if pr.programming_attempts == 0 {
                                    reasons.append("- No Autonomous Flight attempts")
                                } else {
                                    reasons.append("- Autonomous Flight Skills score: \(pr.programming_score) (attempts: \(pr.programming_attempts))")
                                }
                            } else {
                                reasons.append("- No Autonomous Flight Skills score")
                            }
                        }
                        if !hasDriverScore {
                            reasons.append("- No Piloting score")
                        }
                        ineligibleTeams_local.append(team)
                        ineligibleTeamsReasons_local[team.id] = reasons
                        
                        // Compute precomputed values.
                        let qualifierRankComputed: Int = {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsRankComputed: Int = {
                            if let index = overall_skills_sorted.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsDataComputed: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int) = {
                            if let sr = event.skills_rankings.first(where: { $0.team.id == team.id }) {
                                return (sr.programming_score, sr.programming_attempts, sr.driver_score, sr.driver_attempts)
                            }
                            return (0,0,0,0)
                        }()
                        precomputedExcellence[team.id] = PrecomputedValues(
                            qualifierRank: qualifierRankComputed,
                            qualifierCutoff: ranking_cutoff,
                            skillsRank: skillsRankComputed,
                            skillsCutoff: overall_skills_cutoff,
                            skillsData: skillsDataComputed
                        )
                    }
                }
            } else {
                let grade = middleSchool ? "Middle School" : "High School"
                let qualifierRankings = event.rankings[division] ?? []
                let total_rankings = qualifierRankings.filter {
                    if let t = event.get_team(id: $0.team.id) {
                        return grade == "Middle School" ? (t.grade == "Middle School") : (t.grade != "Middle School")
                    }
                    return false
                }
                let ranking_cutoff = max(1, Int((Double(total_rankings.count) * THRESHOLD).rounded(.toNearestOrAwayFromZero)))
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                let skillsRankingsForGrade = event.skills_rankings.filter {
                    if let t = event.get_team(id: $0.team.id) {
                        return grade == "Middle School" ? (t.grade == "Middle School") : (t.grade != "Middle School")
                    }
                    return false
                }
                let skillsCutoff = ranking_cutoff
                let sortedSkillsRankings = skillsRankingsForGrade.sorted { $0.rank < $1.rank }
                
                for team in event.teams where (event.get_team(id: team.id)?.grade ?? "") == grade {
                    var reasons = [String]()
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && hasProgrammingScore {
                        eligible_teams_local.append(team)
                    } else {
                        if !isInRankingCutoff {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                let qualifierRank = index + 1
                                reasons.append("- Qualifier Ranking: \(qualifierRank) (cutoff: \(ranking_cutoff))")
                            } else {
                                reasons.append("- Qualifier Ranking: Not ranked (cutoff: \(ranking_cutoff))")
                            }
                        }
                        if !hasProgrammingScore {
                            if let pr = programmingRanking {
                                if pr.programming_attempts == 0 {
                                    reasons.append("- No programming attempts")
                                } else {
                                    reasons.append("- Programming score: \(pr.programming_score) (attempts: \(pr.programming_attempts))")
                                }
                            } else {
                                reasons.append("- No programming score")
                            }
                        }
                        if !hasDriverScore {
                            reasons.append("- No driver score")
                        }
                        ineligibleTeams_local.append(team)
                        ineligibleTeamsReasons_local[team.id] = reasons
                        
                        // Compute precomputed values.
                        let qualifierRankComputed: Int = {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsRankComputed: Int = {
                            if let index = sortedSkillsRankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsDataComputed: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int) = {
                            if let sr = event.skills_rankings.first(where: { $0.team.id == team.id }) {
                                return (sr.programming_score, sr.programming_attempts, sr.driver_score, sr.driver_attempts)
                            }
                            return (0,0,0,0)
                        }()
                        precomputedExcellence[team.id] = PrecomputedValues(
                            qualifierRank: qualifierRankComputed,
                            qualifierCutoff: ranking_cutoff,
                            skillsRank: skillsRankComputed,
                            skillsCutoff: skillsCutoff,
                            skillsData: skillsDataComputed
                        )
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.eligible_teams = eligible_teams_local
                self.ineligibleTeams = ineligibleTeams_local
                self.ineligibleTeamsReasons = ineligibleTeamsReasons_local
                self.showLoading = false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            if showLoading {
                ProgressView()
                    .padding()
                    .onAppear { fetch_info_excellence() }
                    .navigationBarTitle("Excellence Eligibility", displayMode: .inline)
            } else {
                List {
                    // Eligible Teams Section
                    EligibleTeamsSectionExcellence(
                        eligibleTeams: eligible_teams,
                        event: event,
                        division: division,
                        generateLocation: { team in generate_location(team: team) }
                    )
                    
                    // Ineligible Teams Section
                    IneligibleTeamsSectionExcellence(
                        ineligibleTeams: ineligibleTeams,
                        ineligibleTeamsReasons: ineligibleTeamsReasons,
                        precomputedExcellence: precomputedExcellence,
                        generateLocation: { team in generate_location(team: team) }
                    )
                }
                .listStyle(InsetGroupedListStyle())
                .navigationBarTitle("Excellence Eligibility", displayMode: .inline)
            }
        }
    }
}

// MARK: - AllAroundChampionEligibleTeams View
struct AllAroundChampionEligibleTeams: View {
    
    @State var event: Event
    @State var division: Division
    @State var middleSchool: Bool
    @Binding var allAroundChampionOffered: Bool
    @Binding var middleSchoolAllAroundChampionOffered: Bool
    
    @State var eligible_teams = [Team]()
    @State var ineligibleTeams: [Team] = []
    @State var ineligibleTeamsReasons: [Int: [String]] = [:]
    @State var precomputedIneligible: [Int: PrecomputedValues] = [:]
    
    @State var showLoading = true
    @State var showRequirementsSheet = false   // Controls display of the requirements sheet.
    
    /// Generates a location string from a team’s city, region, and country.
    func generate_location(team: Team) -> String {
        let parts = [team.city, team.region, team.country].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
    
    func levelFilter(rankings: [TeamRanking], forGrade grade: String, isCombinedAward: Bool) -> [TeamRanking] {
        if isCombinedAward { return rankings }
        var output = [TeamRanking]()
        for ranking in rankings {
            if let team = event.get_team(id: ranking.team.id) {
                if (grade == "Middle School" && team.grade == "Middle School") ||
                   (grade == "High School" && team.grade != "Middle School") {
                    output.append(ranking)
                }
            }
        }
        print("Filtered Rankings Count for \(grade): \(output.count)")
        return output
    }
    
    func filteredSkillsRankings(forGrade grade: String) -> [TeamSkillsRanking] {
        event.skills_rankings.filter { ranking in
            if let team = event.get_team(id: ranking.team.id) {
                return grade == "Middle School" ? (team.grade == "Middle School") : (team.grade != "Middle School")
            }
            return false
        }
    }
    
    /// Fetches and processes ranking and skills data asynchronously for ADC eligibility.
    func fetch_info_adc() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            guard !(event.rankings[division] ?? []).isEmpty, !event.skills_rankings.isEmpty else {
                DispatchQueue.main.async { self.showLoading = false }
                return
            }
            
            let awardsForDivision = event.awards[division] ?? []
            let allAroundAwards = awardsForDivision.filter { $0.title.contains("All-Around Champion") }
            let hasMiddleSchoolAward = allAroundAwards.contains { $0.title.contains("Middle School") }
            let hasHighSchoolAward = allAroundAwards.contains { $0.title.contains("High School") }
            let isCombinedAward = !(hasMiddleSchoolAward && hasHighSchoolAward)
            print("Awards for Division: \(allAroundAwards.map { $0.title })")
            print("isCombinedAward = \(isCombinedAward)")
            
            let overall_skills_rankings = event.skills_rankings
            let overall_skills_cutoff = max(1, Int(ceil(Double(overall_skills_rankings.count) * 0.5)))
            let overall_skills_sorted = overall_skills_rankings.sorted { $0.rank < $1.rank }
            let overall_skills_teams = overall_skills_sorted.prefix(overall_skills_cutoff).map { $0.team }
            
            var eligible_teams_local = [Team]()
            var ineligibleTeams_local = [Team]()
            var ineligibleTeamsReasons_local = [Int: [String]]()
            precomputedIneligible = [:]
            
            if isCombinedAward {
                let qualifierRankings = event.rankings[division] ?? []
                let ranking_cutoff = max(1, Int(ceil(Double(qualifierRankings.count) * 0.5)))
                let rankings = qualifierRankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                for team in event.teams {
                    var reasons = [String]()
                    
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && hasProgrammingScore && hasDriverScore {
                        eligible_teams_local.append(team)
                    } else {
                        if !isInRankingCutoff {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                let qualifierRank = index + 1
                                reasons.append("- Qualifier Ranking: \(qualifierRank) (cutoff: \(ranking_cutoff))")
                            } else {
                                reasons.append("- Qualifier Ranking: Not ranked (cutoff: \(ranking_cutoff))")
                            }
                        }
                        if !hasProgrammingScore {
                            if let pr = programmingRanking {
                                if pr.programming_attempts == 0 {
                                    reasons.append("- No programming attempts")
                                } else {
                                    reasons.append("- Programming score: \(pr.programming_score) (attempts: \(pr.programming_attempts))")
                                }
                            } else {
                                reasons.append("- No programming score")
                            }
                        }
                        if !hasDriverScore {
                            reasons.append("- No driver score")
                        }
                        ineligibleTeams_local.append(team)
                        ineligibleTeamsReasons_local[team.id] = reasons
                        
                        // Compute precomputed values.
                        let qualifierRankComputed: Int = {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsRankComputed: Int = {
                            if let index = overall_skills_sorted.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsDataComputed: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int) = {
                            if let sr = event.skills_rankings.first(where: { $0.team.id == team.id }) {
                                return (sr.programming_score, sr.programming_attempts, sr.driver_score, sr.driver_attempts)
                            }
                            return (0,0,0,0)
                        }()
                        precomputedIneligible[team.id] = PrecomputedValues(
                            qualifierRank: qualifierRankComputed,
                            qualifierCutoff: ranking_cutoff,
                            skillsRank: skillsRankComputed,
                            skillsCutoff: overall_skills_cutoff,
                            skillsData: skillsDataComputed
                        )
                    }
                }
            } else {
                let grade = middleSchool ? "Middle School" : "High School"
                let qualifierRankings = event.rankings[division] ?? []
                let total_rankings = qualifierRankings.filter {
                    if let t = event.get_team(id: $0.team.id) {
                        return grade == "Middle School" ? (t.grade == "Middle School") : (t.grade != "Middle School")
                    }
                    return false
                }
                let ranking_cutoff = max(1, Int(ceil(Double(total_rankings.count) * 0.5)))
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                let skillsRankingsForGrade = event.skills_rankings.filter {
                    if let t = event.get_team(id: $0.team.id) {
                        return grade == "Middle School" ? (t.grade == "Middle School") : (t.grade != "Middle School")
                    }
                    return false
                }
                let skillsCutoff = ranking_cutoff
                let sortedSkillsRankings = skillsRankingsForGrade.sorted { $0.rank < $1.rank }
                
                for team in event.teams where (event.get_team(id: team.id)?.grade ?? "") == grade {
                    var reasons = [String]()
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && hasProgrammingScore {
                        eligible_teams_local.append(team)
                    } else {
                        if !isInRankingCutoff {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                let qualifierRank = index + 1
                                reasons.append("- Qualifier Ranking: \(qualifierRank) (cutoff: \(ranking_cutoff))")
                            } else {
                                reasons.append("- Qualifier Ranking: Not ranked (cutoff: \(ranking_cutoff))")
                            }
                        }
                        if !hasProgrammingScore {
                            if let pr = programmingRanking {
                                if pr.programming_attempts == 0 {
                                    reasons.append("- No programming attempts")
                                } else {
                                    reasons.append("- Programming score: \(pr.programming_score) (attempts: \(pr.programming_attempts))")
                                }
                            } else {
                                reasons.append("- No programming score")
                            }
                        }
                        if !hasDriverScore {
                            reasons.append("- No driver score")
                        }
                        ineligibleTeams_local.append(team)
                        ineligibleTeamsReasons_local[team.id] = reasons
                        
                        // Compute precomputed values.
                        let qualifierRankComputed: Int = {
                            if let index = rankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsRankComputed: Int = {
                            if let index = sortedSkillsRankings.firstIndex(where: { $0.team.id == team.id }) {
                                return index + 1
                            }
                            return -1
                        }()
                        let skillsDataComputed: (programming: Int, programming_attempts: Int, driver: Int, driver_attempts: Int) = {
                            if let sr = event.skills_rankings.first(where: { $0.team.id == team.id }) {
                                return (sr.programming_score, sr.programming_attempts, sr.driver_score, sr.driver_attempts)
                            }
                            return (0,0,0,0)
                        }()
                        precomputedIneligible[team.id] = PrecomputedValues(
                            qualifierRank: qualifierRankComputed,
                            qualifierCutoff: ranking_cutoff,
                            skillsRank: skillsRankComputed,
                            skillsCutoff: skillsCutoff,
                            skillsData: skillsDataComputed
                        )
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.eligible_teams = eligible_teams_local
                self.ineligibleTeams = ineligibleTeams_local
                self.ineligibleTeamsReasons = ineligibleTeamsReasons_local
                self.showLoading = false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            if showLoading {
                ProgressView()
                    .padding()
                    .onAppear { fetch_info_adc() }
                    .navigationBarTitle("All-Around Champion Eligibility", displayMode: .inline)
            } else {
                List {
                    // Eligible Teams Section
                    Section(header: Text("Eligible Teams")) {
                        if eligible_teams.isEmpty {
                            Text("No eligible teams")
                        } else {
                            ForEach(eligible_teams, id: \.id) { team in
                                NavigationLink(destination: EligibleTeamDetailsView(event: event, division: division, team: team)) {
                                    HStack {
                                        Text(team.number)
                                            .font(.system(size: 20))
                                            .frame(width: 80, alignment: .leading)
                                            .bold()
                                        VStack(alignment: .leading) {
                                            Text(team.name)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(height: 20)
                                            Spacer().frame(height: 5)
                                            Text(generate_location(team: team))
                                                .font(.system(size: 11))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Ineligible Teams Section
                    Section(header: Text("Ineligible Teams")) {
                        if ineligibleTeams.isEmpty {
                            Text("All teams that meet the grade requirement are eligible.")
                        } else {
                            ForEach(ineligibleTeams, id: \.id) { team in
                                if let pre = precomputedIneligible[team.id] {
                                    NavigationLink(destination: ADCIneligibilityReasonsView(
                                        team: team,
                                        reasons: ineligibleTeamsReasons[team.id] ?? [],
                                        qualifierRank: pre.qualifierRank,
                                        qualifierCutoff: pre.qualifierCutoff,
                                        skillsRank: pre.skillsRank,
                                        skillsCutoff: pre.skillsCutoff,
                                        skillsData: pre.skillsData
                                    )) {
                                        HStack {
                                            Text(team.number)
                                                .font(.system(size: 20))
                                                .frame(width: 80, alignment: .leading)
                                                .bold()
                                            VStack(alignment: .leading) {
                                                Text(team.name)
                                                Spacer().frame(height: 5)
                                                Text(generate_location(team: team))
                                                    .font(.system(size: 11))
                                            }
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: ADCIneligibilityReasonsView(
                                        team: team,
                                        reasons: ineligibleTeamsReasons[team.id] ?? [],
                                        qualifierRank: -1,
                                        qualifierCutoff: 1,
                                        skillsRank: -1,
                                        skillsCutoff: 1,
                                        skillsData: (0, 0, 0, 0)
                                    )) {
                                        HStack {
                                            Text(team.number)
                                                .font(.system(size: 20))
                                                .frame(width: 80, alignment: .leading)
                                                .bold()
                                            VStack(alignment: .leading) {
                                                Text(team.name)
                                                Spacer().frame(height: 5)
                                                Text(generate_location(team: team))
                                                    .font(.system(size: 11))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationBarTitle("All-Around Champion Eligibility", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showRequirementsSheet = true }) {
                            Image(systemName: "info.circle")
                                .imageScale(.large)
                        }
                    }
                }
                .sheet(isPresented: $showRequirementsSheet) {
                    NavigationView {
                        RequirementsView()
                            .navigationBarItems(trailing: Button("Done") {
                                showRequirementsSheet = false
                            })
                    }
                }
            }
        }
    }
}

// MARK: - EligibilitySheet Enum
enum EligibilitySheet: String, Identifiable {
    case adcMiddle = "ADC-Middle"
    case adcHigh = "ADC-High"
    case excellenceMiddle = "Excellence-Middle"
    case excellenceHigh = "Excellence-High"
    
    var id: String { self.rawValue }
}

// MARK: - EventDivisionAwards View
struct EventDivisionAwards: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    
    @State var event: Event
    @State var division: Division
    @State var showLoading = true
    
    // ADC Eligibility state variables
    @State var showingAllAroundChampionEligibility = false
    @State var showingMiddleSchoolAllAroundChampionEligibility = false
    @State var allAroundChampionOffered: Bool = false
    @State var middleSchoolAllAroundChampionOffered: Bool = false
    
    // Excellence Eligibility state variables
    @State var showingExcellenceEligibility = false
    @State var showingMiddleSchoolExcellenceEligibility = false
    @State var excellenceOffered = false
    @State var middleSchoolExcellenceOffered = false
    @State var selectedGradeCategory: String = "Middle School"
    
    // Combined alert state.
    @State var selectedEligibilitySheet: EligibilitySheet? = nil
    
    @State var showRequirementsSheet = false   // Controls display of the requirements sheet.
    
    init(event: Event, division: Division) {
        self.event = event
        self.division = division
    }
    
    /// Fetches awards and rankings asynchronously.
    func fetch_awards() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            event.fetch_awards(division: division)
            event.fetch_rankings(division: division)
            event.fetch_skills_rankings()
            DispatchQueue.main.async { self.showLoading = false }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if showLoading {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if (event.awards[division] ?? [DivisionalAward]()).isEmpty {
                    NoData()
                } else {
                    if let awardsArray = event.awards[division] {
                        List {
                            ForEach(awardsArray.indices, id: \.self) { i in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(awardsArray[i].title)
                                        Spacer()
                                        if !awardsArray[i].qualifications.isEmpty {
                                            Menu {
                                                Text("Qualifies for:")
                                                ForEach(awardsArray[i].qualifications, id: \.self) { qual in
                                                    Text(qual)
                                                }
                                            } label: {
                                                Image(systemName: "globe.americas")
                                            }
                                            .tint(settings.buttonColor())
                                        }
                                    }
                                    // ADC eligibility button branch.
                                    if allAroundEligibilityFeaturesEnabled &&
                                        awardsArray[i].teams.isEmpty &&
                                       awardsArray[i].title.contains("All-Around Champion") &&
                                       !(event.rankings[division] ?? [TeamRanking]()).isEmpty {
                                        Spacer().frame(height: 5)
                                        Button("Show Eligible Teams") {
                                            if awardsArray[i].title.contains("Middle") {
                                                selectedEligibilitySheet = .adcMiddle
                                                print("ADC Button tapped, selectedEligibilitySheet: \(selectedEligibilitySheet!.rawValue)")
                                            } else {
                                                selectedEligibilitySheet = .adcHigh
                                                print("ADC Button tapped, selectedEligibilitySheet: \(selectedEligibilitySheet!.rawValue)")
                                            }
                                        }
                                        .foregroundColor(settings.buttonColor())
                                        .font(.system(size: 14))
                                        .onAppear {
                                            if awardsArray[i].title.contains("Middle") {
                                                middleSchoolAllAroundChampionOffered = true
                                                print("Middle School All Around Champion Award offered")
                                            } else {
                                                allAroundChampionOffered = true
                                                print("All Around Champion Award offered")
                                            }
                                        }
                                    }
                                    // Excellence eligibility button branch.
                                    else if excellenceEligibilityFeaturesEnabled &&
                                            awardsArray[i].teams.isEmpty &&
                                            awardsArray[i].title.contains("Excellence Award") &&
                                            !(event.rankings[division] ?? [TeamRanking]()).isEmpty {
                                        Spacer().frame(height: 5)
                                        Button("Show Eligible Teams") {
                                            print("Excellence eligible teams button tapped")
                                            if awardsArray[i].title.contains("Middle") {
                                                selectedEligibilitySheet = .excellenceMiddle
                                                print("Set selectedEligibilitySheet to Excellence-Middle")
                                            } else {
                                                selectedEligibilitySheet = .excellenceHigh
                                                print("Set selectedEligibilitySheet to Excellence-High")
                                            }
                                        }
                                        .foregroundColor(settings.buttonColor())
                                        .font(.system(size: 14))
                                        .onAppear {
                                            if awardsArray[i].title.contains("Middle") {
                                                middleSchoolExcellenceOffered = true
                                                print("Middle School Excellence Award offered")
                                            } else {
                                                excellenceOffered = true
                                                print("High School Excellence Award offered")
                                            }
                                        }
                                    }
                                    // Otherwise, show existing teams.
                                    else if !awardsArray[i].teams.isEmpty {
                                        Spacer().frame(height: 5)
                                        ForEach(awardsArray[i].teams.indices, id: \.self) { j in
                                            HStack {
                                                Text(awardsArray[i].teams[j].number)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .frame(width: 60)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                                    .bold()
                                                Text(awardsArray[i].teams[j].name)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .alert(item: $selectedEligibilitySheet) { sheet in
            switch sheet {
            case .excellenceMiddle:
                return Alert(
                    title: Text("Disclaimer"),
                    message: Text("This is Unofficial and may be inaccurate, and can only possibly be accurate after both Qualification and Skills matches finish. Please keep in mind that there are other factors that no app can calculate – this is solely based on field performance."),
                    dismissButton: .default(Text("I Understand"), action: {
                        print("Excellence Middle alert dismissed. Scheduling sheet presentation...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showingMiddleSchoolExcellenceEligibility = true
                            print("Now showing Excellence Middle eligibility sheet (flag set).")
                        }
                        selectedEligibilitySheet = nil
                    })
                )
            case .excellenceHigh:
                return Alert(
                    title: Text("Disclaimer"),
                    message: Text("This is Unofficial and may be inaccurate, and can only possibly be accurate after both Qualification and Skills matches finish. Please keep in mind that there are other factors that no app can calculate – this is solely based on field performance."),
                    dismissButton: .default(Text("I Understand"), action: {
                        print("Excellence High alert dismissed. Scheduling sheet presentation...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showingExcellenceEligibility = true
                            print("Now showing Excellence High eligibility sheet (flag set).")
                        }
                        selectedEligibilitySheet = nil
                    })
                )
            case .adcMiddle:
                return Alert(
                    title: Text("Disclaimer"),
                    message: Text("This is Unofficial, and is only accurate after both Qualification and Skills matches finish. It will no longer be accurate after Alliance Selection is completed. Please keep in mind that there are other factors that the app cannot calculate – this is solely based on field performance."),
                    dismissButton: .default(Text("I Understand"), action: {
                        DispatchQueue.main.async {
                            showingMiddleSchoolAllAroundChampionEligibility = true
                            print("Now showing ADC Middle eligibility sheet (flag set).")
                        }
                        selectedEligibilitySheet = nil
                    })
                )
            case .adcHigh:
                return Alert(
                    title: Text("Disclaimer"),
                    message: Text("This is Unofficial, and is only accurate after both Qualification and Skills matches finish. It will no longer be accurate after Alliance Selection is completed. Please keep in mind that there are other factors that the app cannot calculate – this is solely based on field performance."),
                    dismissButton: .default(Text("I Understand"), action: {
                        DispatchQueue.main.async {
                            showingAllAroundChampionEligibility = true
                            print("Now showing ADC High eligibility sheet (flag set).")
                        }
                        selectedEligibilitySheet = nil
                    })
                )
            }
        }
        .sheet(isPresented: $showingMiddleSchoolAllAroundChampionEligibility) {
            AllAroundChampionEligibleTeams(event: event,
                                           division: division,
                                           middleSchool: true,
                                           allAroundChampionOffered: $allAroundChampionOffered,
                                           middleSchoolAllAroundChampionOffered: $middleSchoolAllAroundChampionOffered)
        }
        .sheet(isPresented: $showingAllAroundChampionEligibility) {
            AllAroundChampionEligibleTeams(event: event,
                                           division: division,
                                           middleSchool: false,
                                           allAroundChampionOffered: $allAroundChampionOffered,
                                           middleSchoolAllAroundChampionOffered: $middleSchoolAllAroundChampionOffered)
        }
        .sheet(isPresented: $showingMiddleSchoolExcellenceEligibility) {
            ExcellenceEligibleTeams(event: event,
                                    middleSchool: true,
                                    excellenceOffered: excellenceOffered,
                                    middleSchoolExcellenceOffered: middleSchoolExcellenceOffered,
                                    division: division)
        }
        .sheet(isPresented: $showingExcellenceEligibility) {
            ExcellenceEligibleTeams(event: event,
                                    middleSchool: false,
                                    excellenceOffered: excellenceOffered,
                                    middleSchoolExcellenceOffered: middleSchoolExcellenceOffered,
                                    division: division)
        }
        .task { fetch_awards() }
        .onAppear{
            navigation_bar_manager.title = "\(division.name) Awards"
        }
    }
}

// MARK: - Preview Provider
struct EventDivisionAwards_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionAwards(event: Event(), division: Division())
    }
}
