//
//  EventInformation.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI

struct EventInformation: View {
    
    @EnvironmentObject var settings: UserSettings
    
    @State var event: Event
    @State private var livestream_link = ""
    @State private var calendarAlert = false
    
    let dateFormatter = DateFormatter()
    
    init(event: Event) {
        self.event = event
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // eventRegion uses a mapping if needed.
    var eventRegion: String {
        let state = event.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedState = state.capitalized
        let normalizedState = StateRegionMapping.stateNameVariations[formattedState] ?? formattedState
        return StateRegionMapping.stateToRegionMap[normalizedState] ?? "Unknown Region"
    }
        
    var body: some View {
        VStack {
            Spacer()
            Text(event.name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
            if !livestream_link.isEmpty {
                HStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.tv")
                            .foregroundColor(settings.buttonColor())
                        Link("Watch Livestream", destination: URL(string: self.livestream_link)!)
                    }
                    Spacer()
                }
            } else {
                Text("")
                    .frame(height: 20)
                    .onAppear {
                        DispatchQueue.global(qos: .userInteractive).async { [self] in
                            let link = self.event.fetch_livestream_link()
                            DispatchQueue.main.async {
                                self.livestream_link = link ?? ""
                            }
                        }
                    }
            }
            VStack {
                List {
                    HStack {
                        Text("Teams")
                        Spacer()
                        Text(String(event.teams.count))
                    }
                    HStack {
                        Menu("Divisions") {
                            ForEach(event.divisions.map { $0.name }, id: \.self) {
                                Text($0)
                            }
                        }
                        Spacer()
                        Text(String(event.divisions.count))
                    }
                    HStack {
                        Text("City")
                        Spacer()
                        Text(event.city)
                    }
                    
                    // Conditionally show State and Region rows:
                    if settings.selectedProgram == "ADC" || settings.selectedProgram == "Aerial Drone Competition" {
                        HStack {
                            Text("State")
                            Spacer()
                            Text(event.region)
                        }
                        HStack {
                            Text("Region")
                            Spacer()
                            Text(eventRegion)
                        }
                    } else {
                        HStack {
                            Text("Region")
                            Spacer()
                            Text(event.region)
                        }
                    }
                    
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(event.country)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        if let startDate = event.start {
                            Text(startDate, style: .date)
                        }
                    }
                    HStack {
                        Text("Season")
                        Spacer()
                        Text(API.season_id_map[UserSettings.getGradeLevel() != "College" ? 0 : 1][event.season] ?? "")
                    }
                    HStack {
                        Menu("Developer") {
                            Text("ID: \(String(event.id))")
                            Text("SKU: \(event.sku)")
                        }
                        Spacer()
                    }
                }
            }
        }
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Event Info")
                    .fontWeight(.medium)
                    .font(.system(size: 19))
                    .foregroundColor(settings.topBarContentColor())
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Link(destination: URL(string: "https://www.robotevents.com/robot-competitions/adc/\(self.event.sku).html")!) {
                    Image(systemName: "link")
                        .foregroundColor(settings.topBarContentColor())
                }
                Button(action: {
                    self.event.add_to_calendar()
                    calendarAlert = true
                }, label: {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(settings.topBarContentColor())
                })
                .alert(isPresented: $calendarAlert) {
                    Alert(title: Text("Added to calendar"), dismissButton: .default(Text("OK")))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(settings.tabColor(), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(settings.buttonColor())
    }
}

struct EventInformation_Previews: PreviewProvider {
    static var previews: some View {
        EventInformation(event: Event())
    }
}
