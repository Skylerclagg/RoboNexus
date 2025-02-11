//
//  RootView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

class NavigationBarManager: ObservableObject {
    @Published var title: String
    @Published var shouldReload: Bool = false
    init(title: String) {
        self.title = title
    }
}

struct RootView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var configManager: ConfigManager  // So we have access to current program if needed

    @StateObject var navigation_bar_manager = NavigationBarManager(title: "Favorites")
    
    @State private var tab_selection = 0
    @State private var lookup_type = 0 // 0 is teams, 1 is events
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tab_selection) {
                
                // 1) Favorites tab
                Favorites(tab_selection: $tab_selection, lookup_type: $lookup_type)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "star")
                        } else {
                            Label("Favorites", systemImage: "star")
                        }
                    }
                    .tag(0)
                
                // 2) World Skills tab
                WorldSkillsRankings()
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "globe")
                        } else {
                            Label("World Skills", systemImage: "globe")
                        }
                    }
                    .tag(1)
                
                // 3) Lookup tab
                Lookup(lookup_type: $lookup_type)
                    .tabItem {
                        if UserSettings.getMinimalistic() {
                            Image(systemName: "magnifyingglass")
                        } else {
                            Label("Lookup", systemImage: "magnifyingglass")
                        }
                    }
                    .tag(2)
                
                // Conditionally show these tabs only if the selected program is "Aerial Drone Competition"
                if settings.selectedProgram == "Aerial Drone Competition" {
                    
                    // 4) Game Manual tab
                    GameManual()
                        .tabItem {
                            if UserSettings.getMinimalistic() {
                                Image(systemName: "book")
                            } else {
                                Label("Game Manual", systemImage: "book")
                            }
                        }
                        .tag(3)
                    
                    // 5) Score Calculators tab
                    ScoreCalculatorsHome()
                        .tabItem {
                            if UserSettings.getMinimalistic() {
                                Image(systemName: "candybarphone")
                            } else {
                                Label("Calculators", systemImage: "candybarphone")
                            }
                        }
                        .tag(4)
                }
            }
            // Environment objects injected into child views
            .environmentObject(favorites)
            .environmentObject(settings)
            .environmentObject(dataController)
            .environmentObject(navigation_bar_manager)
            .environmentObject(configManager)
            .tint(settings.buttonColor())
            .onAppear {
                // Configure tab bar appearance on iOS 15+
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithDefaultBackground()
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(navigation_bar_manager.title)
                            .fontWeight(.medium)
                            .font(.system(size: 19))
                            .foregroundColor(settings.topBarContentColor())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination:
                        Settings()
                            .environmentObject(favorites)
                            .environmentObject(settings)
                            .environmentObject(dataController)
                            .environmentObject(navigation_bar_manager)
                            .environmentObject(configManager)
                            .tint(settings.buttonColor())
                    ) {
                        Image(systemName: "gearshape")
                    }
                }
                
                // If the user is on the Game Manual screen, show a refresh button
                if navigation_bar_manager.title.contains("Game Manual") {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            navigation_bar_manager.shouldReload = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .foregroundColor(settings.topBarContentColor())
                        .accessibilityLabel("Refresh")
                    }
                }
                // If the user is on the World Skills screen, show a link
                if navigation_bar_manager.title.contains("Skills") {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(FavoriteStorage())
            .environmentObject(UserSettings())
            .environmentObject(ADCHubDataController())
            .environmentObject(NavigationBarManager(title: "Preview"))
            .environmentObject(ConfigManager())
    }
}
