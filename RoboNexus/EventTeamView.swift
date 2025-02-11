//
//  EventTeamView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import CoreData

struct EventTeamView: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataController: ADCHubDataController
    
    @Binding var teams_map: [String: String]
    
    @State var event: Event
    @State var division: Division?
    @State var teamNumber: String
    @State var selectedView = 0
    
    init(teams_map: Binding<[String: String]>, event: Event, teamNumber: String, division: Division? = nil) {
        self._teams_map = teams_map
        self._event = State(initialValue: event)
        self._teamNumber = State(initialValue: teamNumber)
        self._division = State(initialValue: division)
    }
    
    
    var body: some View {
        VStack {
            Picker("Team Information", selection: $selectedView) {
                Text("Matches").tag(UserSettings.getMatchTeamDefaultPage() == "matches" ? 0 : 1)
                Text("Statistics").tag(UserSettings.getMatchTeamDefaultPage() == "statistics" ? 0 : 1)
            }.pickerStyle(.segmented).padding()
            Spacer()
            if selectedView == (UserSettings.getMatchTeamDefaultPage() == "matches" ? 0 : 1) {
                EventTeamMatches(teams_map: $teams_map, event: event, team: Team(number: teamNumber, fetch: false), division: division)
                    .environmentObject(settings)
                    .environmentObject(dataController)
                Spacer()
            }
            else if selectedView == (UserSettings.getMatchTeamDefaultPage() == "statistics" ? 0 : 1) {
                TeamLookup(team_number: teamNumber, editable: false, fetch: true)
                    .environmentObject(settings)
                    .environmentObject(dataController)
            }
        }.background(.clear)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Team Info")
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
