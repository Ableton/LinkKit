// Copyright: 2021, Ableton AG, Berlin. All rights reserved.

import SwiftUI

@main
struct LinkHutApp: App {

  @StateObject var audioEngineController = AudioEngineController()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(audioEngineController)
    }
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .active:
        // Unconditionally activate Link when becoming active.
        // If the app is active, Link should be active.
        ABLLinkSetActive(audioEngineController.link, true)
        audioEngineController.startAudioEngine()
      case .background:
        // Deactivate Link if the app is not playing and it cannot be started from Start Stop Sync,
        // so that it won't continue to browse for connections while in the background.
        if !audioEngineController.isPlaying
          && !ABLLinkIsStartStopSyncEnabled(audioEngineController.link)
        {
          ABLLinkSetActive(audioEngineController.link, false)
          audioEngineController.stopAudioEngine()
        }
      default: ()
      }

    }
  }

}
