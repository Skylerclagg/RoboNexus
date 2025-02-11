//
//  MatchRowView.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import Foundation
import SwiftUI

struct MatchRowView: View {
    
    @EnvironmentObject var dataController: ADCHubDataController
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var configManager: ConfigManager  // Now using configManager for current program info
    
    @Binding var event: Event
    @Binding var matches: [Match]
    @Binding var teams_map: [String: String]
    @Binding var matchString: String
    @Binding var team: Team
    
    // Helper: Determine if the combined score should be shown in green.
    // For ADC and VIQRC, when scores are equal, show a single green score.
    // For V5RC and VURC, always show separate red and blue scores.
    func shouldDisplayCombinedScoreInGreen() -> Bool {
        if settings.selectedProgram == "Aerial Drone Competition" || settings.selectedProgram == "VEX IQ Robotics Competition" {
            return true
        }else{
            return false
        }
    }
    
    func conditionalUnderline(matchString: String, index: Int) -> Bool {
        let split = matchString.split(separator: "&&")
        
        guard team.id != 0 else { return false }
        
        if let intVal = Int(split[index]), intVal == self.team.id {
            return true
        }
        
        let match = matches[Int(split[0]) ?? 0]
        let alliance = match.alliance_for(team: self.team)
        
        if alliance == nil { return false }
        
        if (alliance! == Alliance.red && index == 6) || (alliance! == Alliance.blue && index == 7) {
            return true
        }
        return false
    }
    
    func conditionalColor(matchString: String) -> Color {
        let split = matchString.split(separator: "&&")
        let match = matches[Int(split[0]) ?? 0]
        
        guard team.id != 0 && match.completed() else {
            return .primary
        }
        
        if let victor = match.winning_alliance() {
            if victor == match.alliance_for(team: self.team) {
                return .green
            } else {
                return .red
            }
        } else {
            return .yellow
        }
    }
    
    @ViewBuilder
    func centerDisplay(matchString: String) -> some View {
        let split = matchString.split(separator: "&&")
        let match = matches[Int(split[0]) ?? 0]
        
        if match.completed() {
            HStack {
                if match.red_score != match.blue_score {
                    // Different scores: always show red and blue separately.
                    Text(String(describing: match.red_score))
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                        .frame(alignment: .leading)
                        .underline(conditionalUnderline(matchString: matchString, index: 6))
                        .bold()
                    Spacer()
                    Text(String(describing: match.blue_score))
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                        .frame(alignment: .trailing)
                        .underline(conditionalUnderline(matchString: matchString, index: 7))
                        .bold()
                } else {
                    // Equal scores: if current program is ADC/VIQRC, show green; if V5RC/VURC, show separate scores.
                    if shouldDisplayCombinedScoreInGreen() {
                        Text(String(describing: match.red_score))
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                            .frame(alignment: .center)
                            .underline(conditionalUnderline(matchString: matchString, index: 6))
                            .bold()
                    } else {
                        HStack {
                            Text(String(describing: match.red_score))
                                .foregroundColor(.red)
                                .font(.system(size: 18))
                                .bold()
                            Spacer()
                            Text(String(describing: match.blue_score))
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                                .bold()
                        }
                    }
                }
            }
        } else {
            Spacer()
            Text(match.field)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    var body: some View {
        NavigationLink(destination: MatchNotes(event: event, match: matches[Int($matchString.wrappedValue.split(separator: "&&")[0])!])
                        .environmentObject(settings)
                        .environmentObject(dataController)
        ) {
            HStack {
                VStack(alignment: .leading) {
                    Text($matchString.wrappedValue.split(separator: "&&")[1])
                        .font(.system(size: 15))
                        .foregroundColor(conditionalColor(matchString: $matchString.wrappedValue))
                        .bold()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer().frame(height: 4)
                    Text($matchString.wrappedValue.split(separator: "&&")[8])
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 60, alignment: .leading)
                
                VStack {
                    if let team3 = teams_map[String($matchString.wrappedValue.split(separator: "&&")[3])], !team3.isEmpty {
                        Text(teams_map[String($matchString.wrappedValue.split(separator: "&&")[2])] ?? "")
                            .foregroundColor(.red)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 2))
                        Text(team3)
                            .foregroundColor(.red)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 3))
                    } else {
                        Text(teams_map[String($matchString.wrappedValue.split(separator: "&&")[2])] ?? "")
                            .foregroundColor(.red)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 2))
                    }
                }
                .frame(width: 70)
                
                centerDisplay(matchString: $matchString.wrappedValue)
                    .frame(maxWidth: .infinity)
                
                VStack(alignment: .trailing) {
                    if let team5 = teams_map[String($matchString.wrappedValue.split(separator: "&&")[5])], !team5.isEmpty {
                        Text(teams_map[String($matchString.wrappedValue.split(separator: "&&")[4])] ?? "")
                            .foregroundColor(.blue)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 4))
                        Text(team5)
                            .foregroundColor(.blue)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 5))
                    } else {
                        Text(teams_map[String($matchString.wrappedValue.split(separator: "&&")[4])] ?? "")
                            .foregroundColor(.blue)
                            .font(.system(size: 15))
                            .underline(conditionalUnderline(matchString: $matchString.wrappedValue, index: 4))
                    }
                }
                .frame(width: 70, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, maxHeight: 30)
        }
    }
}
