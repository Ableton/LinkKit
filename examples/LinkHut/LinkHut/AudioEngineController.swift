// Copyright: 2021, Ableton AG, Berlin. All rights reserved.

import AVFAudio
import CoreAudio
import Foundation
import SwiftUI

struct LinkAudioChannel: Identifiable, Hashable {
  let id: ABLLinkAudioChannelId
  let peerId: ABLLinkAudioPeerId
  let name: String
  let peerName: String
}

class AudioEngineController: ObservableObject {

  @Published var isPlaying = false {
    didSet {
      if isPlaying {
        audioEngine?.requestTransportStart()
      } else {
        audioEngine?.requestTransportStop()
      }
    }
  }

  @Published private(set) var beatTime = 0.0

  @Published var tempo = 120.0 {
    didSet {
      audioEngine?.proposeTempo(tempo)
    }
  }

  @Published var quantum = 4.0 {
    didSet {
      audioEngine?.setQuantum(quantum)
    }
  }

  @Published private(set) var availableChannels: [LinkAudioChannel] = []

  @Published private(set) var isAudioEnabled = false

  @Published var pingPongChannel: LinkAudioChannel? {
    didSet {
      audioEngine?.setPingPongChannelId(pingPongChannel?.id ?? 0)
    }
  }

  var link: ABLLinkRef? {
    audioEngine?.linkRef()
  }

  func startAudioEngine() {
    audioEngine?.start()
  }

  func stopAudioEngine() {
    audioEngine?.stop()
  }

  private let audioEngine = AudioEngine.init(tempo: 120)
  private var timer: Timer?

  init() {
    // Set ABLLink Callbacks to update `tempo` and `isPlaying` when those properties change in Link
    ABLLinkSetSessionTempoCallback(
      audioEngine?.linkRef(),
      { tempo, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().tempo = tempo
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    ABLLinkSetStartStopCallback(
      audioEngine?.linkRef(),
      { isPlaying, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().isPlaying =
          isPlaying
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    isAudioEnabled = ABLLinkIsAudioEnabled(audioEngine?.linkRef())
    ABLLinkSetIsAudioEnabledCallback(
      audioEngine?.linkRef(),
      { enabled, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue()
          .isAudioEnabled = enabled
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    ABLLinkAudioSetChannelListChangedCallback(
      audioEngine?.linkRef(),
      { context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue()
          .refreshAvailableChannels()
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    // Regularly update the beat time to be displayed in the UI
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
      let sessionState = ABLLinkCaptureAppSessionState(self.audioEngine?.linkRef())
      self.beatTime = ABLLinkBeatAtTime(sessionState, mach_absolute_time(), self.quantum)
    }

    refreshAvailableChannels()
  }

  private func refreshAvailableChannels() {
    guard let link = audioEngine?.linkRef() else {
      availableChannels = []
      pingPongChannel = nil
      return
    }

    let list = ABLLinkAudioGetChannelList(link)
    defer { ABLLinkAudioFreeChannelList(list) }

    var channels: [LinkAudioChannel] = []
    channels.reserveCapacity(list.count)
    if let base = list.channels {
      for i in 0..<list.count {
        let c = base[i]
        channels.append(
          LinkAudioChannel(
            id: c.id,
            peerId: c.peerId,
            name: c.name.map { String(cString: $0) } ?? "",
            peerName: c.peerName.map { String(cString: $0) } ?? ""))
      }
    }
    availableChannels = channels

    if let selected = pingPongChannel,
      !channels.contains(where: { $0.id == selected.id })
    {
      pingPongChannel = nil
    }
  }
}
