//
//  EventDivisionMatches.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

struct EventDivisionMatches: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    @EnvironmentObject var dataController: ADCHubDataController
    
    @Binding var teams_map: [String: String]
    
    @State var event: Event
    @State var division: Division
    @State private var matches = [Match]()
    @State private var matches_list = [String]()
    @State private var showLoading = true
    
    func fetch_info() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in

            self.event.fetch_matches(division: division)
            let matches = self.event.matches[division] ?? [Match]()
            
            // Time should be in the format of "HH:mm a"
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"

            DispatchQueue.main.async {
                self.matches = matches
                self.matches_list.removeAll()
                var count = 0
                for match in matches {
                    var name = match.name
                    name.replace("Qualifier", with: "Q")
                    name.replace("Practice", with: "P")
                    name.replace("Match", with: "F")
                    name.replace("TeamWork", with: "Q")
                    name.replace("#", with: "")
                    
                    // Determine the match time
                    let date: String = {
                        if let started = match.started {
                            return formatter.string(from: started)
                        } else if let scheduled = match.scheduled {
                            return formatter.string(from: scheduled)
                        } else {
                            return " "
                        }
                    }()
                    
                    // Construct the match string
                    self.matches_list.append("\(count)&&\(name)&&\(match.red_alliance[0].id)&&\(match.red_alliance[1].id)&&\(match.blue_alliance[0].id)&&\(match.blue_alliance[1].id)&&\(match.red_score)&&\(match.blue_score)&&\(date)")
                    count += 1
                }
                self.showLoading = false
            }
        }
    }
        
    var body: some View {
        VStack {
            if showLoading {
                ProgressView().padding()
                Spacer()
            } else if matches.isEmpty {
                NoData()
            } else {
                List($matches_list, id: \.self) { matchString in
                    MatchRowView(
                        event: $event,
                        matches: $matches,
                        teams_map: $teams_map,
                        matchString: matchString,
                        team: .constant(Team())
                    )
                }
            }
        }
        .task {
            fetch_info()
        }
        .onAppear {
            navigation_bar_manager.title = "\(division.name) Match List"
        }
        .background(.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct EventDivisionMatches_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionMatches(
            teams_map: .constant([String: String]()),
            event: Event(),
            division: Division()
        )
    }
}
