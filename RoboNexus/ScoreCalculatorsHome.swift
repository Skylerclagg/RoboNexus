//
//  ScoreCalculatorsHome.swift
//  ADC Hub
//
//  Created by Skyler Clagg on 10/30/24.
//

import SwiftUI

struct ScoreCalculatorsHome: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var favorites: FavoriteStorage
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager

    var body: some View {
        VStack(spacing: 20) {
            NavigationLink(destination: TeamworkScoreCalculator()
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(navigation_bar_manager)
            ) {
                Text("Teamwork Match Calculator")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(settings.buttonColor())
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            NavigationLink(destination: PilotingSkillsCalculator()
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(navigation_bar_manager)
            ) {
                Text("Piloting Skills Calculator")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(settings.buttonColor())
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            NavigationLink(destination: AutonomousFlightSkillsCalculator()
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(navigation_bar_manager)
            ) {
                Text("Autonomous Flight Skills Calculator")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(settings.buttonColor())
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Scoring Calculators")
        .onAppear {
            navigation_bar_manager.title = "Scoring Calculators"
        }
    }
}

struct ScoreCalculatorsHome_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScoreCalculatorsHome()
                .environmentObject(UserSettings())
                .environmentObject(ADCHubDataController())
                .environmentObject(NavigationBarManager(title: "Calculators"))
        }
    }
}
