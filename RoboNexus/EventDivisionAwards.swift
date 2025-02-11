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

// MARK: - AllAroundChampionEligibleTeams View

struct AllAroundChampionEligibleTeams: View {
    
    @State var event: Event
    @State var division: Division
    // This "middleSchool" flag indicates which eligibility page is being shown.
    // If true, only Middle School teams will be processed.
    @State var middleSchool: Bool
    // Bindings provided by the parent view.
    @Binding var allAroundChampionOffered: Bool
    @Binding var middleSchoolAllAroundChampionOffered: Bool
    @State var eligible_teams = [Team]()
    @State var showLoading = true

    /// Generates a location string from a team’s city, region, and country.
    func generate_location(team: Team) -> String {
        var location_array = [team.city, team.region, team.country]
        location_array = location_array.filter { !$0.isEmpty }
        return location_array.joined(separator: ", ")
    }
    
    /// Filters qualifier rankings (assumed to be [TeamRanking]) for the specified grade.
    func levelFilter(rankings: [TeamRanking], forGrade grade: String, isCombinedAward: Bool) -> [TeamRanking] {
        if isCombinedAward { return rankings }
        
        var output = [TeamRanking]()
        for ranking in rankings {
            if let team = event.get_team(id: ranking.team.id) {
                if grade == "Middle School" && team.grade == "Middle School" {
                    output.append(ranking)
                } else if grade == "High School" && team.grade != "Middle School" {
                    output.append(ranking)
                }
            }
        }
        print("Filtered Rankings Count for \(grade): \(output.count)")
        return output
    }
    
    /// Filters the skills rankings (assumed to be [TeamSkillsRanking]) for the specified grade.
    func filteredSkillsRankings(forGrade grade: String) -> [TeamSkillsRanking] {
        let allSkills = event.skills_rankings 
        return allSkills.filter { ranking in
            if let team = event.get_team(id: ranking.team.id) {
                return grade == "Middle School" ? (team.grade == "Middle School") : (team.grade != "Middle School")
            }
            return false
        }
    }
    
    /// Fetches and processes ranking and skills data asynchronously.
    func fetch_info() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            if (event.rankings[division] ?? [TeamRanking]()).isEmpty || event.skills_rankings.isEmpty {
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
            let overall_skills_sorted = (overall_skills_rankings ).sorted { $0.rank < $1.rank }
            let overall_skills_teams = overall_skills_sorted.prefix(overall_skills_cutoff).map { $0.team }
            
            print("Overall Skills Cutoff (Combined): \(overall_skills_cutoff)")
            print("Teams in Top \(overall_skills_cutoff) Overall Skills Rankings (Combined):")
            for team in overall_skills_teams {
                let teamData = event.get_team(id: team.id)
                print("Team: \(teamData?.number ?? team.number), Rank: \(overall_skills_sorted.first(where: { $0.team.id == team.id })?.rank ?? -1)")
            }
            
            var eligible_teams = [Team]()
            
            if isCombinedAward {
                // Combined Award Mode – process all teams.
                let qualifierRankings = event.rankings[division] ?? []
                print("DEBUG (Combined Award): Total Qualifier Rankings Count: \(qualifierRankings.count)")
                let total_rankings = qualifierRankings
                print("Total Rankings (Combined Award): \(total_rankings.count)")
                let ranking_cutoff = max(1, Int(ceil(Double(total_rankings.count) * 0.5)))
                print("Ranking Cutoff (Combined Award): \(ranking_cutoff)")
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                print("Teams in Top \(ranking_cutoff) (Combined Award):")
                for team in rankings_teams {
                    let fullTeam = event.get_team(id: team.id) ?? team
                    print("Team: \(fullTeam.number), Rank: \(rankings.first(where: { $0.team.id == team.id })?.rank ?? -1)")
                }
                
                for team in event.teams {
                    let hasProgrammingScore = event.skills_rankings.contains {
                        $0.team.id == team.id && $0.programming_score > 0
                    }
                    let hasDriverScore = event.skills_rankings.contains {
                        $0.team.id == team.id && $0.driver_score > 0
                    }
                    
                    if rankings_teams.contains(where: { $0.id == team.id }) &&
                        overall_skills_teams.contains(where: { $0.id == team.id }) &&
                        hasProgrammingScore && hasDriverScore {
                        eligible_teams.append(team)
                    } else {
                        print("Team \(team.number) excluded:")
                        if !rankings_teams.contains(where: { $0.id == team.id }) {
                            print("- Not in top \(ranking_cutoff) of qualifier rankings")
                        }
                        if !overall_skills_teams.contains(where: { $0.id == team.id }) {
                            print("- Not in top \(overall_skills_cutoff) of overall skills rankings")
                        }
                        if !hasProgrammingScore { print("- No programming score") }
                        if !hasDriverScore { print("- No driver score") }
                    }
                }
                
            } else {
                // Separate Award Mode – process only the grade corresponding to this view.
                let grade = middleSchool ? "Middle School" : "High School"
                
                // Process qualifier rankings for the grade.
                let qualifierRankings = event.rankings[division] ?? []
                let total_rankings = levelFilter(rankings: qualifierRankings, forGrade: grade, isCombinedAward: false)
                print("Total Qualifier Rankings for Grade (\(grade)): \(total_rankings.count)")
                for ranking in total_rankings {
                    if let team = event.get_team(id: ranking.team.id) {
                        print("Qualifier - Team: \(team.number), Grade: \(team.grade)")
                    }
                }
                let ranking_cutoff = max(1, Int(ceil(Double(total_rankings.count) * 0.5)))
                print("Qualifier Ranking Cutoff for Grade (\(grade)): \(ranking_cutoff)")
                let rankings = total_rankings.sorted { $0.rank < $1.rank }
                let rankings_teams = rankings.prefix(ranking_cutoff).map { $0.team }
                print("Teams in Top \(ranking_cutoff) Qualifier Rankings for Grade (\(grade)):")
                for team in rankings_teams {
                    let fullTeam = event.get_team(id: team.id) ?? team
                    print("Team: \(fullTeam.number), Qualifier Rank: \(rankings.first(where: { $0.team.id == team.id })?.rank ?? -1)")
                }
                
                // Process skills rankings for this grade.
                let skillsRankingsForGrade = filteredSkillsRankings(forGrade: grade)
                let skillsCutoff = max(1, Int(ceil(Double(skillsRankingsForGrade.count) * 0.5)))
                let sortedSkillsRankings = skillsRankingsForGrade.sorted { $0.rank < $1.rank }
                let eligibleSkillsTeams = sortedSkillsRankings.prefix(skillsCutoff).map { $0.team }
                print("Filtered Skills Rankings Count for Grade (\(grade)): \(skillsRankingsForGrade.count)")
                print("Teams in Top \(skillsCutoff) Skills Rankings for Grade (\(grade)):")
                for ranking in sortedSkillsRankings.prefix(skillsCutoff) {
                    let team = event.get_team(id: ranking.team.id) ?? ranking.team
                    print("Team: \(team.number), Skills Rank: \(ranking.rank)")
                }
                
                // Evaluate only teams of the specified grade.
                for team in event.teams where (event.get_team(id: team.id)?.grade ?? "") == grade {
                    let hasProgrammingScore = event.skills_rankings.contains {
                        $0.team.id == team.id && $0.programming_score > 0
                    }
                    let hasDriverScore = event.skills_rankings.contains {
                        $0.team.id == team.id && $0.driver_score > 0
                    }
                    
                    if rankings_teams.contains(where: { $0.id == team.id }) &&
                        eligibleSkillsTeams.contains(where: { $0.id == team.id }) &&
                        hasProgrammingScore && hasDriverScore {
                        eligible_teams.append(team)
                    } else {
                        print("Team \(team.number) excluded:")
                        if !rankings_teams.contains(where: { $0.id == team.id }) {
                            print("- Not in top \(ranking_cutoff) of qualifier rankings")
                        }
                        if !eligibleSkillsTeams.contains(where: { $0.id == team.id }) {
                            print("- Not in top \(skillsCutoff) of skills rankings")
                        }
                        if !hasProgrammingScore { print("- No programming score") }
                        if !hasDriverScore { print("- No driver score") }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.eligible_teams = eligible_teams
                self.showLoading = false
                print("Final Eligible Teams: \(eligible_teams.map { $0.number })")
            }
        }
    }
    
    // MARK: - View Body
    var body: some View {
        // Wrap the content in a NavigationView to restore the previous UI look.
        NavigationView {
            VStack {
                if showLoading {
                    ProgressView()
                        .padding()
                        .onAppear { fetch_info() }
                    Spacer()
                } else {
                    VStack(alignment: .leading) {
                        Text("Requirements:")
                        BulletList(listItems: [
                            "Be ranked in the top 50% of qualification rankings at the conclusion of qualifying teamwork matches.",
                            "Be ranked in the top 50% of overall skills rankings at the conclusion of autonomous flight and piloting skills matches.",
                            "Participation in both the Piloting Skills Mission and the Autonomous Flight Skills Mission is required, with a score of greater than 0 in each Mission."
                        ], listItemSpacing: 10)
                        Text("The following teams are eligible:")
                    }
                    if eligible_teams.isEmpty {
                        List { Text("No eligible teams") }
                        Spacer()
                    } else {
                        List($eligible_teams) { team in
                            HStack {
                                Text(team.wrappedValue.number)
                                    .font(.system(size: 20))
                                    .minimumScaleFactor(0.01)
                                    .frame(width: 80, height: 30, alignment: .leading)
                                    .bold()
                                VStack {
                                    Text(team.wrappedValue.name)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 20)
                                    Spacer().frame(height: 5)
                                    Text(generate_location(team: team.wrappedValue))
                                        .font(.system(size: 11))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 15)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationBarTitle("All-Around Champion Eligibility", displayMode: .inline)
        }
    }
}

// MARK: - EventDivisionAwards View

struct EventDivisionAwards: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    
    @State var event: Event
    @State var division: Division
    @State var showLoading = true
    @State var showingAllAroundChampionEligibility = false
    @State var showingMiddleSchoolAllAroundChampionEligibility = false
    @State var allAroundChampionOffered = false
    @State var middleSchoolAllAroundChampionOffered = false
    
    // New state variables for the disclaimer alert.
    @State var showEligibilityDisclaimerAlert = false
    @State var selectedEligibilitySheet: String? = nil
    
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
        VStack {
            if showLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if (event.awards[division] ?? [DivisionalAward]()).isEmpty {
                NoData()
            } else {
                List {
                    ForEach(0..<event.awards[division]!.count, id: \.self) { i in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(event.awards[division]![i].title)
                                Spacer()
                                if !event.awards[division]![i].qualifications.isEmpty {
                                    Menu {
                                        Text("Qualifies for:")
                                        ForEach(event.awards[division]![i].qualifications, id: \.self) { qual in
                                            Text(qual)
                                        }
                                    } label: {
                                        Image(systemName: "globe.americas")
                                    }
                                }
                            }
                            if event.awards[division]![i].teams.isEmpty &&
                                event.awards[division]![i].title.contains("All-Around Champion") &&
                                !(event.rankings[division] ?? [TeamRanking]()).isEmpty &&
                                !event.skills_rankings.isEmpty {
                                Spacer().frame(height: 5)
                                Button("Show eligible teams") {
                                    if event.awards[division]![i].title.contains("Middle") {
                                        selectedEligibilitySheet = "Middle"
                                    } else {
                                        selectedEligibilitySheet = "High"
                                    }
                                    showEligibilityDisclaimerAlert = true
                                }
                                .font(.system(size: 14))
                                .onAppear {
                                    if event.awards[division]![i].title.contains("Middle") {
                                        middleSchoolAllAroundChampionOffered = true
                                    } else {
                                        allAroundChampionOffered = true
                                    }
                                }
                            } else if !event.awards[division]![i].teams.isEmpty {
                                Spacer().frame(height: 5)
                                ForEach(0..<event.awards[division]![i].teams.count, id: \.self) { j in
                                    if !event.awards[division]![i].teams.isEmpty {
                                        HStack {
                                            Text(event.awards[division]![i].teams[j].number)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(width: 60)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                                .bold()
                                            Text(event.awards[division]![i].teams[j].name)
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
        }
        .task { fetch_awards() }
        .onAppear { navigation_bar_manager.title = "\(division.name) Awards" }
        .alert(isPresented: $showEligibilityDisclaimerAlert) {
            Alert(
                title: Text("Disclaimer"),
                message: Text("This is Unofficial, and is only accurate after both Qualification and Skills matches finish. It will no longer be accurate after Alliance Selection is completed. Please keep in mind that there are other factors that the app cannot calculate this is solely based on field performance."),
                dismissButton: .default(Text("I Understand"), action: {
                    
                    if selectedEligibilitySheet == "Middle" {
                        showingMiddleSchoolAllAroundChampionEligibility = true
                    } else if selectedEligibilitySheet == "High" {
                        showingAllAroundChampionEligibility = true
                    }
                    selectedEligibilitySheet = nil
                })
            )
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
    }
}

// MARK: - Preview Provider

struct EventDivisionAwards_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionAwards(event: Event(), division: Division())
    }
}
