//
//  DataExporter.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import OrderedCollections

struct DataExporter: View {
    
    @EnvironmentObject var settings: UserSettings
    
    @State var event: Event
    @State var division: Division? = nil
    @State var teams_list: [String] = [String]()
    @State var showLoading = true
    @State var progress: Double = 0
    @State var csv_string: String = ""
    @State var show_option = 0
    @State var view_closed = false
    @State var selected: OrderedDictionary = [
        "Team Name": true,
        "Robot Name": true,
        "Team Location": true,
        "Average Qualifiers Ranking (slow)": false,
        "Total Events Attended (slow)": false,
        "Total Awards (slow)": false,
        "World Skills Ranking": true,
        "Combined Skills": true,
        "Autonomous Flight Skills": true,
        "Piloting Skills": true
    ]
    @State var sections: OrderedDictionary = [
        "Team Info": [0, 2],
        "Performance Statistics": [3, 10],
        "Skills Data": [11, 14]
    ]
    
    func generate_location(team: Team) -> String {
        var location_array = [team.city, team.region, team.country]
        location_array = location_array.filter{ $0 != "" }
        return location_array.joined(separator: " ")
    }
    
     func fetch_teams_list() {
         showLoading = true
         DispatchQueue.global(qos: .userInteractive).async { [self] in
             
             if self.division != nil && !self.event.rankings.keys.contains(self.division!) {
                 self.event.fetch_rankings(division: self.division!)
             }
             
             if self.division != nil && self.event.rankings[self.division!]!.isEmpty && !self.event.matches.keys.contains(self.division!) {
                 self.event.fetch_matches(division: self.division!)
             }
             
             DispatchQueue.main.async {
                 self.teams_list = [String]()
                 
                 if self.division != nil && !self.event.rankings[self.division!]!.isEmpty {
                     for ranking in self.event.rankings[self.division!]! {
                         self.teams_list.append(event.get_team(id: ranking.team.id)?.number ?? "")
                     }
                 }
                 else if self.division != nil {
                     for match in self.event.matches[self.division!]! {
                         var match_teams = match.red_alliance
                         match_teams.append(contentsOf: match.blue_alliance)
                         for team in match_teams {
                             if !self.teams_list.contains(event.get_team(id: team.id)?.number ?? "") {
                                 self.teams_list.append(event.get_team(id: team.id)?.number ?? "")
                             }
                         }
                     }
                 }
                 else {
                     self.teams_list = self.event.teams.map{ $0.number }
                 }
                 self.teams_list.sort()
                 self.teams_list.sort(by: {
                     (Int($0.filter("0123456789".contains)) ?? 0) < (Int($1.filter("0123456789".contains)) ?? 0)
                 })
                 showLoading = false
             }
         }
     }
    
    
    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            }
            else {
                Spacer()
                Text("\(teams_list.count) Teams")
                Spacer()
                ScrollView {
                    VStack(spacing: 40) {
                        // Team Info Section
                        VStack(spacing: 10) {
                            HStack {
                                Text("Team Info")
                                Spacer()
                                if show_option == 0 {
                                    Image(systemName: "chevron.up.circle")
                                }
                                else {
                                    Image(systemName: "chevron.down.circle")
                                }
                            }.contentShape(Rectangle()).onTapGesture{
                                show_option = 0
                            }
                            if show_option == 0 {
                                ForEach(Array(Array(selected.keys)[0...2]), id: \.self) { option in
                                    HStack {
                                        if option.contains("(slow)") {
                                            HStack {
                                                Text(option.replacingOccurrences(of: " (slow)", with: "")).foregroundColor(.secondary)
                                                Image(systemName: "timer").foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text(option).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selected[option] ?? false {
                                            Image(systemName: "checkmark").foregroundColor(.secondary)
                                        }
                                    }.contentShape(Rectangle()).onTapGesture{
                                        if progress == 0 || progress == 1 {
                                            selected[option] = !(selected[option] ?? false)
                                            progress = 0
                                        }
                                    }
                                }
                            }
                        }
                        // Skills Data Section
                        VStack(spacing: 10) {
                            HStack {
                                Text("Skills Data")
                                Spacer()
                                if show_option == 2 {
                                    Image(systemName: "chevron.up.circle")
                                }
                                else {
                                    Image(systemName: "chevron.down.circle")
                                }
                            }.contentShape(Rectangle()).onTapGesture{
                                show_option = 2
                            }
                            if show_option == 2 {
                                ForEach(Array(Array(selected.keys)[11...14]), id: \.self) { option in
                                    HStack {
                                        if option.contains("(slow)") {
                                            HStack {
                                                Text(option.replacingOccurrences(of: " (slow)", with: "")).foregroundColor(.secondary)
                                                Image(systemName: "timer").foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text(option).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selected[option] ?? false {
                                            Image(systemName: "checkmark").foregroundColor(.secondary)
                                        }
                                    }.contentShape(Rectangle()).onTapGesture{
                                        if progress == 0 || progress == 1 {
                                            selected[option] = !(selected[option] ?? false)
                                            progress = 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.padding()
                Spacer()
                ProgressView(value: progress).padding().tint(settings.buttonColor())
                if progress != 1 {
                    Button("Generate") {
                        if progress != 0 {
                            return
                        }
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
                                if view_closed {
                                    return
                                }
                                data += number
                                let team = event.teams.first(where: { $0.number == number })!
                                let world_skills = API.world_skills_for(team: team) ?? WorldSkills(team: team, data: [String: Any]())
                                for (option, state) in selected {
                                    guard state else { continue }
                                    if option == "Team Name" {
                                        data += ",\(team.name.replacingOccurrences(of: ",", with: ""))"
                                    }
                                    else if option == "Robot Name" {
                                        data += ",\(team.robot_name.replacingOccurrences(of: ",", with: ""))"
                                    }
                                    else if option == "Team Location" {
                                        data += ",\(generate_location(team: team).replacingOccurrences(of: ",", with: ""))"
                                    }
                                    else if option == "Average Qualifiers Ranking (slow)" {
                                        data += ",\(team.average_ranking())"
                                        sleep(2)
                                    }
                                    else if option == "Total Events Attended (slow)" {
                                        if selected["Average Qualifiers Ranking (slow)"]! {
                                            data += ",\(team.event_count)"
                                        }
                                        else {
                                            team.fetch_events()
                                            data += ",\(team.events.count)"
                                            sleep(2)
                                        }
                                    }
                                    else if option == "Total Awards (slow)" {
                                        team.fetch_awards()
                                        data += ",\(team.awards.count)"
                                        sleep(2)
                                    }
                                    else if option == "World Skills Ranking" {
                                        data += ",\(world_skills.ranking)"
                                    }
                                    else if option == "Combined Skills" {
                                        data += ",\(world_skills.combined)"
                                    }
                                    else if option == "Autonomous Flight Skills" {
                                        data += ",\(world_skills.programming)"
                                    }
                                    else if option == "piloting Skills" {
                                        data += ",\(world_skills.driver)"
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
                    }.padding(10)
                        .background(settings.buttonColor())
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                else {
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
                            if self.division != nil {
                                return "\(self.division!.name.convertedToSlug() ?? String(describing: self.division!.id))-\(self.event.name.convertedToSlug() ?? self.event.sku).csv"
                            }
                            else {
                                return "\(self.event.name.convertedToSlug() ?? self.event.sku).csv"
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
                    }.padding(10)
                        .background(settings.buttonColor())
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                Spacer()
            }
        }.onAppear{
            fetch_teams_list()
        }.onDisappear{
            view_closed = true
        }.background(.clear)
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
