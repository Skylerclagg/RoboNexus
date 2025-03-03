//
//  EventDivisionView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

struct EventDivisionView: View {
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @StateObject var navigation_bar_manager = NavigationBarManager(title: "Rankings")
    
    @State var event: Event
    @State var event_teams: [Team]
    @State var division: Division
    @State var teams_map: [String: String]
    @State var division_teams_list: [String]
    
    var body: some View {
        NavigationStack {
            TabView {
                // Teams Tab
                EventTeams(event: event,
                           division: division,
                           teams_map: $teams_map,
                           event_teams: $event_teams,
                           event_teams_list: division_teams_list)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "person.3.fill")
                        } else {
                            Label("Teams", systemImage: "person.3.fill")
                        }
                    }
                    .environmentObject(favorites)
                    .environmentObject(settings)
                    .environmentObject(dataController)
                    .environmentObject(navigation_bar_manager)
                
                // Match List Tab
                EventDivisionMatches(teams_map: $teams_map,
                                     event: event,
                                     division: division)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "clock.fill")
                        } else {
                            Label("Match List", systemImage: "clock.fill")
                        }
                    }
                    .environmentObject(favorites)
                    .environmentObject(settings)
                    .environmentObject(dataController)
                    .environmentObject(navigation_bar_manager)
                
                // Rankings Tab
                EventDivisionRankings(event: event,
                                      division: division,
                                      teams_map: teams_map)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "list.number")
                        } else {
                            Label("Rankings", systemImage: "list.number")
                        }
                    }
                    .environmentObject(favorites)
                    .environmentObject(settings)
                    .environmentObject(dataController)
                    .environmentObject(navigation_bar_manager)
                
                // Awards Tab
                EventDivisionAwards(event: event, division: division)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "trophy")
                        } else {
                            Label("Awards", systemImage: "trophy")
                        }
                    }
                    .environmentObject(favorites)
                    .environmentObject(settings)
                    .environmentObject(dataController)
                    .environmentObject(navigation_bar_manager)
            }
            .onAppear {
                // When the view appears, set the title to the event name.
                navigation_bar_manager.title = event.name
            }
            .toolbar {
                // Principal: Display the navigation title.
                ToolbarItem(placement: .principal) {
                    Text(navigation_bar_manager.title)
                        .fontWeight(.medium)
                        .font(.system(size: 19))
                        .foregroundColor(settings.topBarContentColor())
                }
                // Trailing group: Show buttons based on the current title.
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Favorites button: Only when the title exactly equals the event name.
                    if navigation_bar_manager.title == event.name {
                        Button(action: {
                            if favorites.favoriteEvents.contains(event.sku) {
                                favorites.removeEvent(event.sku)
                            } else {
                                favorites.addEvent(event.sku)
                            }
                        }) {
                            Image(systemName: favorites.favoriteEvents.contains(event.sku) ? "star.fill" : "star")
                        }
                        .foregroundColor(settings.topBarContentColor())
                    }
                    // Refresh button: Show when the title indicates a refreshable page.
                    if navigation_bar_manager.title.contains("Game Manual") ||
                        navigation_bar_manager.title.contains("Match List") ||
                        navigation_bar_manager.title.contains("Rankings") {
                        Button(action: {
                            navigation_bar_manager.shouldReload = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .foregroundColor(settings.topBarContentColor())
                        .accessibilityLabel("Refresh")
                    }
                    // World Skills link: When the title contains "Skills".
                    if navigation_bar_manager.title.contains("Skills") {
                        Link(destination: URL(string: "https://www.robotevents.com/robot-competitions/adc/standings/skills")!) {
                            Image(systemName: "link")
                        }
                        .foregroundColor(settings.topBarContentColor())
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(settings.tabColor(), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(settings.topBarContentColor())
        .background(.clear)
    }
}

struct EventDivisionView_Previews: PreviewProvider {
    static var previews: some View {
        EventDivisionView(
            event: Event(),
            event_teams: [Team](),
            division: Division(),
            teams_map: [String: String](),
            division_teams_list: []
        )
        .environmentObject(FavoriteStorage())
        .environmentObject(UserSettings())
        .environmentObject(ADCHubDataController())
    }
}
