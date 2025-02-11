//
//  AutonomousFlightSkillsCalculator.swift
//  ADC Hub
//
//  Created by Skyler Clagg on 10/30/24.
//

import SwiftUI

struct AutonomousFlightSkillsCalculator: View {
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    @EnvironmentObject var settings: UserSettings  // Must have `enableHaptics`
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode

    // State variables for tasks
    @State private var takeOffCount: Int = 0 // Max 2
    @State private var identifyColorCount: Int = 0 // Max 2
    @State private var figure8Count: Int = 0 // Max 2
    @State private var smallHoleCount: Int = 0 // Max 2
    @State private var largeHoleCount: Int = 0 // Max 2
    @State private var archGateCount: Int = 0 // Max 4 (2 per arch gate)
    @State private var keyholeCount: Int = 0 // Max 4 (2 per keyhole)

    enum LandingOption: String, CaseIterable, Identifiable {
        case none = "None"
        case landOnPad = "Landing Pad"
        case landingCubeSmall = "Small Cube"
        case landingCubeLarge = "Large Cube"

        var id: String { self.rawValue }
    }

    @State private var selectedLandingOption: LandingOption = .none

    // Total score computed property
    var totalScore: Int {
        var score = 0
        score += takeOffCount * 10
        score += identifyColorCount * 15
        score += figure8Count * 40
        score += archGateCount * 5
        score += keyholeCount * 15
        score += smallHoleCount * 40
        score += largeHoleCount * 20

        switch selectedLandingOption {
        case .none: break
        case .landOnPad: score += 15
        case .landingCubeSmall: score += 40
        case .landingCubeLarge: score += 25
        }

        return score
    }

    var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Form {
            // Display total score at the top
            Section(header: Text("Total Score").foregroundStyle(textColor)) {
                Text("\(totalScore)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) // Gradient color for total score
            }

            // Per Color Mat Tasks Section
            Section(header: Text("Tasks:").foregroundStyle(textColor)) {
                Stepper(value: $takeOffCount, in: 0...2) {
                    HStack {
                        Text("Take Off:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(takeOffCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: takeOffCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $identifyColorCount, in: 0...2) {
                    HStack {
                        Text("Identify Color Count:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(identifyColorCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: identifyColorCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $figure8Count, in: 0...2) {
                    HStack {
                        Text("Complete a Figure 8:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(figure8Count)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: figure8Count) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $smallHoleCount, in: 0...2) {
                    HStack {
                        Text("Fly Through Small Hole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(smallHoleCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: smallHoleCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $largeHoleCount, in: 0...2) {
                    HStack {
                        Text("Fly Through Large Hole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(largeHoleCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: largeHoleCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $archGateCount, in: 0...4) {
                    HStack {
                        Text("Fly Under Arch Gate:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(archGateCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: archGateCount) { _ in
                    triggerHapticsIfEnabled()
                }
                .help("Max 2 per Arch Gate (2 Arch Gates)")

                Stepper(value: $keyholeCount, in: 0...4) {
                    HStack {
                        Text("Fly Through Keyhole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(keyholeCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: keyholeCount) { _ in
                    triggerHapticsIfEnabled()
                }
                .help("Max 2 per Keyhole (2 Keyholes)")
            }

            // Landing Options Section
            Section(header: Text("Landing Options:").foregroundStyle(textColor)) {
                Picker("Select Landing Option", selection: $selectedLandingOption) {
                    ForEach(LandingOption.allCases) { option in
                        Text(option.rawValue)
                            .tag(option)
                            .foregroundStyle(.green)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedLandingOption) { _ in
                    triggerHapticsIfEnabled()
                }
            }
        }
        .accentColor(.green) // Make + and - buttons green
        .navigationTitle("Autonomous Flight Calculator")
        .toolbar {
            // Clear Scores Button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: clearInputs) {
                    Image(systemName: "trash")
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Clear Scores")
            }
        }
        .onAppear {
            navigation_bar_manager.title = "Autonomous Flight Calculator"
        }
    }

    // Function to reset all inputs
    func clearInputs() {
        takeOffCount = 0
        identifyColorCount = 0
        figure8Count = 0
        smallHoleCount = 0
        largeHoleCount = 0
        archGateCount = 0
        keyholeCount = 0
        selectedLandingOption = .none

        // HAPTICS: Trigger on clear
        triggerHapticsIfEnabled()
    }

    // MARK: - Haptic Trigger Helper
    private func triggerHapticsIfEnabled() {
        if settings.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

struct AutonomousFlightSkillsCalculator_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AutonomousFlightSkillsCalculator()
                .environmentObject(UserSettings())
                .environmentObject(NavigationBarManager(title: "Autonomous Flight Calculator"))
        }
    }
}
