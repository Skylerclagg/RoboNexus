
/*
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

private let eligibilityFeaturesEnabled: Bool = true


// MARK: - Ineligibility Reasons Detail View
struct ADCIneligibilityReasonsView: View {
    let team: Team
    let reasons: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why \(team.number) is NOT Eligible")
                .font(.headline)
                .padding(.bottom, 5)
            if reasons.isEmpty {
                Text("No reasons available.")
            } else {
                ForEach(reasons, id: \.self) { reason in
                    // Ranking-related and programming issues shown in red, other messages in green.
                    Text(reason)
                        .foregroundColor((reason.contains("Ranking:") || reason.contains("programming")) ? .red : .green)
                        .padding(.vertical, 2)
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


struct ExcellenceEligibleTeams: View {
    
    var event: Event
    let middleSchool: Bool
    let excellenceOffered: Bool
    let middleSchoolExcellenceOffered: Bool
    @State var eligible_teams: [Team] = []
    @State var ineligibleTeams: [Team] = []
    @State var ineligibleTeamsReasons: [Int: [String]] = [:]
    @State var showLoading = true
    @State var division: Division

    // Helper function to generate a location string for a team.
    func generate_location(team: Team) -> String {
        let parts = [team.city, team.region, team.country].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
    
    // (Assume levelFilter and filteredSkillsRankings are similar to those in AllAroundChampionEligibleTeams.)
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
    
    // Use your excellence-specific filtering logic here.
    func fetch_info_excellence() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            // If there is no ranking or skills data, stop loading.
            guard !(event.rankings[division] ?? []).isEmpty, !event.skills_rankings.isEmpty else {
                DispatchQueue.main.async { self.showLoading = false }
                return
            }
            
            // (Your excellence-specific filtering criteria can be applied here.
            // For simplicity, we assume it’s similar to your existing logic.)
            
            let awardsForDivision = event.awards[division] ?? []
            let excellenceAwards = awardsForDivision.filter { $0.title.contains("Excellence Award") }
            let hasMiddleSchoolAward = excellenceAwards.contains { $0.title.contains("Middle School") }
            let hasHighSchoolAward = excellenceAwards.contains { $0.title.contains("High School") }
            let isCombinedAward = !(hasMiddleSchoolAward && hasHighSchoolAward)
            
            let THRESHOLD = 0.4
            let overall_skills_rankings = event.skills_rankings
            let overall_skills_cutoff = max(1, Int(ceil(Double(event.teams.count) * THRESHOLD)))
            let overall_skills_sorted = overall_skills_rankings.sorted { $0.rank < $1.rank }
            let overall_skills_teams = overall_skills_sorted.prefix(overall_skills_cutoff).map { $0.team }
            
            var eligible_teams_local = [Team]()
            var ineligibleTeams_local = [Team]()
            var ineligibleTeamsReasons_local = [Int: [String]]()
            
            if isCombinedAward {
                let qualifierRankings = event.rankings[division] ?? []
                let ranking_cutoff = max(1, Int(ceil(Double(qualifierRankings.count) * THRESHOLD)))
                let rankings = qualifierRankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                for team in event.teams {
                    var reasons = [String]()
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    let isInSkillsCutoff = overall_skills_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && isInSkillsCutoff && hasProgrammingScore && hasDriverScore {
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
                        if !isInSkillsCutoff {
                            if event.skills_rankings.isEmpty {
                                reasons.append("- Skills Ranking: 0 (no skills data)")
                            } else if let index = overall_skills_sorted.firstIndex(where: { $0.team.id == team.id }) {
                                let skillsRank = index + 1
                                reasons.append("- Skills Ranking: \(skillsRank) (cutoff: \(overall_skills_cutoff))")
                            } else {
                                reasons.append("- Skills Ranking: Not ranked (cutoff: \(overall_skills_cutoff))")
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
                        ineligibleTeams_local.append(team)
                        ineligibleTeamsReasons_local[team.id] = reasons
                    }
                }
            } else {
                let grade = middleSchool ? "Middle School" : "High School"
                let qualifierRankings = event.rankings[division] ?? []
                let total_rankings = levelFilter(rankings: qualifierRankings, forGrade: grade, isCombinedAward: false)
                let ranking_cutoff = max(1, Int(ceil(Double(total_rankings.count) * THRESHOLD)))
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                let skillsRankingsForGrade = filteredSkillsRankings(forGrade: grade)
                let skillsCutoff = max(1, Int(ceil(Double(skillsRankingsForGrade.count) * THRESHOLD)))
                let sortedSkillsRankings = skillsRankingsForGrade.sorted { $0.rank < $1.rank }
                let eligibleSkillsTeams = sortedSkillsRankings.prefix(skillsCutoff).map { $0.team }
                
                for team in event.teams where (event.get_team(id: team.id)?.grade ?? "") == grade {
                    var reasons = [String]()
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    let isInSkillsCutoff = eligibleSkillsTeams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && isInSkillsCutoff && hasProgrammingScore && hasDriverScore {
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
                        if !isInSkillsCutoff {
                            if let index = sortedSkillsRankings.firstIndex(where: { $0.team.id == team.id }) {
                                let skillsRank = index + 1
                                reasons.append("- Skills Ranking: \(skillsRank) (cutoff: \(skillsCutoff))")
                            } else {
                                reasons.append("- Skills Ranking: Not ranked (cutoff: \(skillsCutoff))")
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
                            Text("All teams that meet the criteria are eligible.")
                        } else {
                            ForEach(ineligibleTeams, id: \.id) { team in
                                NavigationLink(destination: ADCIneligibilityReasonsView(
                                    team: team,
                                    reasons: ineligibleTeamsReasons[team.id] ?? []
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
    // Indicates whether this view is for Middle School or High School.
    @State var middleSchool: Bool
    // Bindings provided by the parent view.
    @Binding var allAroundChampionOffered: Bool
    @Binding var middleSchoolAllAroundChampionOffered: Bool
    
    @State var eligible_teams = [Team]()
    @State var ineligibleTeams: [Team] = []
    @State var ineligibleTeamsReasons: [Int: [String]] = [:]
    
    @State var showLoading = true
    @State var showRequirementsSheet = false   // Controls display of the requirements sheet.
    
    /// Generates a location string from a team’s city, region, and country.
    func generate_location(team: Team) -> String {
        let parts = [team.city, team.region, team.country].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
    
    /// Filters qualifier rankings for the specified grade.
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
    
    /// Filters the skills rankings for the specified grade.
    func filteredSkillsRankings(forGrade grade: String) -> [TeamSkillsRanking] {
        event.skills_rankings.filter { ranking in
            if let team = event.get_team(id: ranking.team.id) {
                return grade == "Middle School" ? (team.grade == "Middle School") : (team.grade != "Middle School")
            }
            return false
        }
    }
    
    /// Fetches and processes ranking and skills data asynchronously.
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
            // If both exist then separate awards are given; otherwise, treat as combined.
            let isCombinedAward = !(hasMiddleSchoolAward && hasHighSchoolAward)
            print("Awards for Division: \(allAroundAwards.map { $0.title })")
            print("isCombinedAward = \(isCombinedAward)")
            
            // Process overall skills rankings (for combined mode we use the full list).
            let overall_skills_rankings = event.skills_rankings
            let overall_skills_cutoff = max(1, Int(ceil(Double(overall_skills_rankings.count) * 0.5)))
            let overall_skills_sorted = overall_skills_rankings.sorted { $0.rank < $1.rank }
            let overall_skills_teams = overall_skills_sorted.prefix(overall_skills_cutoff).map { $0.team }
            
            // Temporary arrays to store final results.
            var eligible_teams_local = [Team]()
            var ineligibleTeams_local = [Team]()
            var ineligibleTeamsReasons_local = [Int: [String]]()
            
            if isCombinedAward {
                let qualifierRankings = event.rankings[division] ?? []
                let ranking_cutoff = max(1, Int(ceil(Double(qualifierRankings.count) * 0.5)))
                let rankings = qualifierRankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                for team in event.teams {
                    var reasons = [String]()
                    
                    // Retrieve programming ranking for this team.
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    let isInSkillsCutoff = overall_skills_teams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && isInSkillsCutoff && hasProgrammingScore && hasDriverScore {
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
                        if !isInSkillsCutoff {
                            if let index = overall_skills_sorted.firstIndex(where: { $0.team.id == team.id }) {
                                let skillsRank = index + 1
                                reasons.append("- Skills Ranking: \(skillsRank) (cutoff: \(overall_skills_cutoff))")
                            } else {
                                reasons.append("- Skills Ranking: Not ranked (cutoff: \(overall_skills_cutoff))")
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
                        print("Team \(team.number) excluded: \(reasons)")
                    }
                }
            } else {
                let grade = middleSchool ? "Middle School" : "High School"
                let qualifierRankings = event.rankings[division] ?? []
                let total_rankings = levelFilter(rankings: qualifierRankings, forGrade: grade, isCombinedAward: false)
                let ranking_cutoff = max(1, Int(ceil(Double(total_rankings.count) * 0.5)))
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                
                let skillsRankingsForGrade = filteredSkillsRankings(forGrade: grade)
                let skillsCutoff = max(1, Int(ceil(Double(skillsRankingsForGrade.count) * 0.5)))
                let sortedSkillsRankings = skillsRankingsForGrade.sorted { $0.rank < $1.rank }
                let eligibleSkillsTeams = sortedSkillsRankings.prefix(skillsCutoff).map { $0.team }
                
                for team in event.teams where (event.get_team(id: team.id)?.grade ?? "") == grade {
                    var reasons = [String]()
                    
                    let programmingRanking = event.skills_rankings.first(where: { $0.team.id == team.id })
                    let hasProgrammingScore = programmingRanking != nil && programmingRanking!.programming_score > 0
                    
                    let hasDriverScore = event.skills_rankings.contains { $0.team.id == team.id && $0.driver_score > 0 }
                    
                    let isInRankingCutoff = rankings_teams.contains(where: { $0.id == team.id })
                    let isInSkillsCutoff = eligibleSkillsTeams.contains(where: { $0.id == team.id })
                    
                    if isInRankingCutoff && isInSkillsCutoff && hasProgrammingScore && hasDriverScore {
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
                        if !isInSkillsCutoff {
                            if let index = sortedSkillsRankings.firstIndex(where: { $0.team.id == team.id }) {
                                let skillsRank = index + 1
                                reasons.append("- Skills Ranking: \(skillsRank) (cutoff: \(skillsCutoff))")
                            } else {
                                reasons.append("- Skills Ranking: Not ranked (cutoff: \(skillsCutoff))")
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
                        print("Team \(team.number) excluded: \(reasons)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.eligible_teams = eligible_teams_local
                self.ineligibleTeams = ineligibleTeams_local
                self.ineligibleTeamsReasons = ineligibleTeamsReasons_local
                self.showLoading = false
                print("Final Eligible Teams: \(eligible_teams_local.map { $0.number })")
                print("Final Ineligible Teams: \(ineligibleTeams_local.map { $0.number })")
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
                                NavigationLink(destination: ADCIneligibilityReasonsView(
                                    team: team,
                                    reasons: ineligibleTeamsReasons[team.id] ?? []
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
                                        }
                                    }
                                    // ADC eligibility button branch.
                                    if eligibilityFeaturesEnabled &&
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
                                        .font(.system(size: 14))
                                        .onAppear {
                                            if awardsArray[i].title.contains("Middle") {
                                                showingMiddleSchoolAllAroundChampionEligibility = true
                                            } else {
                                                showingAllAroundChampionEligibility = true
                                            }
                                        }
                                    }
                                    // Excellence eligibility button branch.
                                    else if eligibilityFeaturesEnabled &&
                                            awardsArray[i].teams.isEmpty &&
                                            awardsArray[i].title.contains("Excellence Award") &&
                                            !(event.rankings[division] ?? [TeamRanking]()).isEmpty {
                                        Spacer().frame(height: 5)
                                        Button("Show Excellence eligible teams") {
                                            print("Excellence eligible teams button tapped")
                                            if awardsArray[i].title.contains("Middle") {
                                                selectedEligibilitySheet = .excellenceMiddle
                                                print("Set selectedEligibilitySheet to Excellence-Middle")
                                            } else {
                                                selectedEligibilitySheet = .excellenceHigh
                                                print("Set selectedEligibilitySheet to Excellence-High")
                                            }
                                        }
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
        // Combined alert for both ADC and Excellence eligibility.
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
        // Sheet modifiers for presenting the eligibility sheets.
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
        .task { fetch_awards() }.onAppear{
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
*/
