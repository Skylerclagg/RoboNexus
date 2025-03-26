//
//  TeamInfoView.swift
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

struct TeamInfoView: View {
    
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataController: ADCHubDataController
    
    @State var teamNumber: String
    @State var selectedView = 0
    @State private var selected_season: Int = API.selected_season_id()
    
    var body: some View {
        VStack {
            Picker("Team Information", selection: $selectedView) {
                Text("Events").tag(UserSettings.getTeamInfoDefaultPage() == "events" ? 0 : 1)
                Text("Statistics").tag(UserSettings.getTeamInfoDefaultPage() == "statistics" ? 0 : 1)
            }
            .pickerStyle(.segmented)
            .padding()
            Spacer()
            if selectedView == (UserSettings.getTeamInfoDefaultPage() == "events" ? 0 : 1) {
                TeamEventsView(team_number: teamNumber)
                    // Removed watch session environment object
                    // .environmentObject(wcSession)
                    .environmentObject(settings)
                    .environmentObject(dataController)
            } else if selectedView == (UserSettings.getTeamInfoDefaultPage() == "statistics" ? 0 : 1) {
                TeamLookup(team_number: teamNumber, editable: false, fetch: true, selectedSeason: selected_season)

                    .environmentObject(settings)
                    .environmentObject(dataController)
            }
        }
        .background(.clear)
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
