LinkKit
=========

iOS SDK for [Ableton Link](https://ableton.com/link), a **new technology** that **synchronizes musical beat, tempo,** and **phase** across multiple applications running on one or more devices. Applications on devices connected to a **local network** discover each other automatically and **form a musical session** in which each participant can **perform independently**: anyone can start or stop while still staying in time. Anyone can change the tempo, the **others will follow**. Anyone can **join** or **leave** without disrupting the session.

We strongly recommend reading all of the content below, but please pay special attention to the [user interface guidelines](#user-interface-guidelines) and the [test plan](#test-plan) in order to make sure that your app is consistent with others in the Link ecosystem.

##License
Usage of LinkKit is governed by the [Ableton Link SDK license](Ableton_Link_SDK_License_v1.0.pdf).

##Table of Contents
- [Conceptual Overview](#conceptual-overview)
  - [Tempo Synchronization](#tempo-synchronization)
  - [Beat Alignment](#beat-alignment)
  - [Phase Synchronization](#phase-synchronization)
- [Integration Guide](#integration-guide)
  - [Getting Started](#getting-started)
  - [User Interface Guidelines](#user-interface-guidelines)
  - [Link API Concepts](#link-api-concepts)
    - [Host and Beat Times](#host-and-beat-times)
    - [Host Time at Output](#host-time-at-output)
  - [Link API Usage](#link-api-usage)
    - [Initialization and Destruction](#initialization-and-destruction)
    - [Active, Enabled, and Connected](#active-enabled-and-connected)
    - [Controlling Tempo](#controlling-tempo)
    - [Quantized Launch and `ABLLinkResetBeatTime`](#quantized-launch-and-abllinkresetbeattime)
    - [Observing Phase](#observing-phase)
  - [App Life Cycle](#app-life-cycle)
  - [Audiobus](#audiobus)
- [Test Plan](#test-plan)
  - [Tempo Changes](#tempo-changes)
  - [Background Behavior](#background-behavior)
- [Promoting Link Integration](#promoting-link-integration)

##Conceptual Overview
Link is different from other approaches to synchronizing electronic instruments that you may be familiar with. It is not designed to orchestrate multiple instruments so that they play together in lock-step along a shared timeline. In fact, Link-enabled apps each have their own independent timelines. The Link library maintains a temporal relationship between these independent timelines that provides the experience of playing in time without the timelines being identical.

Playing "in time" is an intentionally vague term that might have different meanings for different musical contexts and different apps. As an app maker, you must decide the most natural way to map your app's musical concepts onto Link's synchronization model. For this reason, it's important to gain an intuitive understanding of how Link synchronizes **tempo**, **beat**, and **phase**.

####Tempo Synchronization
Tempo is a well understood parameter that represents the velocity of a beat timeline with respect to real time, giving it a unit of beats/time. Tempo synchronization is achieved when the beat timelines of all participants in a session are advancing at the same rate.

With Link, any participant can propose a change to the session tempo at any time. No single participant is responsible for maintaining the shared session tempo. Rather, each participant chooses to adopt the last tempo value that they've seen proposed on the network. This means that it is possible for participants' tempi to diverge during periods of tempo modification (especially during simultaneous modification by multiple participants), but this state is only temporary. The session will converge quickly to a common tempo after any modification. The Link approach to tempo relies on group adaptation to changes made by independent, autonomous actors - much like a group of traditional instrumentalists playing together.

####Beat Alignment
It's conceivable that for certain musical situations, participants would wish to only synchronize tempo and not other musical parameters. But for the vast majority of cases, playing with synchronized tempo in the absence of beat alignment would not be perceived as playing "in time." In this scenario, participants' beat timelines would advance at the same rate, but the relationship between values on those beat timelines would be undefined (i.e. Beat 1 on one participant's timeline might correspond to beat 3.23 on another's).

In most cases, we want to provide a stronger timing property for a session than just tempo synchronization - we also want beat alignment. When a session is in a state of beat alignment, an integral value on any participant's beat timeline corresponds to an integral value on all other participants' beat timelines. This property says nothing about the magnitude of beat values on each timeline, which can be different, just that any two timelines must only differ by an integral offset. For example, beat 1 on one participant's timeline might correspond to beat 3 or beat 4 on another's, but it cannot correspond to beat 3.5.

Note that in order for a session to be in a state of beat alignment, it must have synchronized tempo. Tempo determines beat length and beat length equivalence among all timelines is a pre-requisite for beat alignment.

####Phase Synchronization
Beat alignment is a necessary condition for playing "in time" in most circumstances, but it's often not enough. When only beat alignment is provided, the user may still not have their timing expectations met if they are working with larger musical constructs, such as bars and loops, that span multiple beats. In this case, they may expect that the beat position within such a construct (the phase) be synchronized, resulting in alignment of bar and loop boundaries across participants.

In order to enable the desired bar and loop alignment, app makers provide a quantum value to Link that specifies, in beats, the desired unit of phase synchronization. Link guarantees that session participants with the same quantum value will be phase aligned, meaning that if two participants have a 4 beat quantum, beat 3 on one participant's timeline could correspond to beat 11 on another's, but not beat 12. It also guarantees the expected relationship between sessions in which one participant has a multiple of another's quantum. So if one app has an 8-beat loop with a quantum of 8 and another has a 4-beat loop with a quantum of 4, then the beginning of an 8-beat loop will always correspond to the beginning of a 4-beat loop, whereas a 4-beat loop may align with the beginning or the middle of an 8-beat loop.

Specifying the quantum value and the handling of phase synchronization is the aspect of Link integration that leads to the greatest diversity of approaches among app makers. There's no one-size-fits-all recommendation about how to do this, it is very app-specific. Some apps have a constant quantum that never changes. Others allow it to change to match a changing value in their app, such as loop length or time signature. In Ableton Live, it is directly tied to the "Global Quantization" control, so it may be useful to explore how different values affect the behavior of Live in order to gain intuition about the quantum.

A decision that nearly all apps have to make is how phase synchronization affects the user action of starting to play. Live and the vast majority of apps perform a quantized launch, meaning that the user sees some sort of count-in animation or flashing play button until starting at the next quantum boundary. This is a very satisfying interaction because it allows multiple users on different devices to start exactly together just by pressing play at roughly the same time. However, there are other approaches imagineable, such as starting immediately while teleporting the playhead to the correct phase within the current loop or bar. The strategy that sticks as close to the spirit of the app is probably the right one.

A final note on phase synchronization: notice that it is more fundamental than beat alignment. There is in fact no special handling of beat alignment in Link. It is a property that emerges from synchronizing phase with a non-zero integral quantum value. This is worth noting because it is also possible to abandon beat alignment (perhaps to achieve polyrhythms) by specifying non-integral quantum values. A quantum value of 0 results in no phase synchronization at all and therefore no beat alignment. So it's easy to create the tempo-only synchronization scenario described previously in the [Beat Alignment](#beat-alignment) section if you can find a use for it.

##Integration Guide

The LinkKit SDK is distributed as a zip file attached to a release in this repo. Please see the [releases tab](https://github.com/AbletonAppDev/LinkKit/releases) for the latest release. Apps **must** be built against an official release for final submission to the App Store. Official releases are those not marked "Pre-release."

###Getting Started
Download the `LinkKit.zip` file attached to the latest release. A `LinkKit.zip` file has the following contents:
- `libABLLink.a`: A static library containing the implementation of Link. This file is **not** in the repo - you must download a release to get it.
- [`ABLLink.h`](include/ABLLink.h): Pure C header containing the Link API.
- [`ABLLinkSettingsViewController.h`](include/ABLLinkSettingsViewController.h): Objective-C header containing `UIViewController` subclass that is used to display the Link preference pane.
- [User interface assets](assets)
- [LinkHut](examples/LinkHut): Very simple app to be used as example code and for testing integrations. It should build and run in-place without modification.

In order to build and link against `libABLLink.a`, make sure that the location of the header files is added to the include path of your project and location of the library added to the linker path. `libABLLink.a` is implemented in C++, so you may also need to add `-lc++` to your link line if you're not already using C++ in your project. This is needed to pull in the C++ standard library.

###User Interface Guidelines
LinkKit includes a Link preference pane that must be added to an app's user interface. The appearance and behavior of the preference pane itself is not configurable, but you must make the choice of where and how to expose access to the preference pane within the app. In order to provide a consistent user experience across all Link-enabled apps, we have developed [UI integration guidelines](docs/Ableton Link UI Guidelines.pdf) that provide guidance on this matter. Please follow them carefully.

Also included in this repo are [assets](assets) to be used if you choose to put a Link button in your app. All assets relating to the Ableton Link identity will be provided by Ableton and all buttons, copy, and labels should follow the [UI integration guidelines](docs/Ableton Link UI Guidelines.pdf).

###Link API Concepts
The Link API is a low-level C API that is designed to integrate with an app's audio engine. It exposes a beat timeline whose magnitude and rate of progress is managed by the Link library to maintain the desired relationship to other participants on the network. In order to stay "in time" with other participants, and to provide low-latency adjustment to changes that come from the network, the app must query the progress of this timeline at each audio callback and adjust its playback within the corresponding buffer accordingly.

For each audio buffer, the app asks the Link library where it should be on the beat timeline by the end of that buffer. The app then figures out how it can render its buffer so as to get to that beat time. This could mean speeding up or slowing down or doing a beat time jump to get to the right position. The library does not specify *how* the app should get there, it just reports where it should be at a given time.

####Host and Beat Times
The Link API deals with two time coordinate systems: host time and beat time. It maintains a bidirectional mapping between these coordinate systems that can be queried by clients for any time values.

Host time as used in the API always refers to the system host time and is the same coordinate system as values returned by [`mach_absolute_time`](https://developer.apple.com/library/mac/qa/qa1398/_index.html) and the `mHostTime` field of the `AudioTimeStamp` structure.

Beat time as used in the API refers to a coordinate system in which integral values represent beats. The library maintains a beat timeline, which starts at zero when the library is initialized and runs continuously at a rate defined by the shared session tempo. Clients may sample this beat timeline at a given host time via the `ABLLinkBeatTimeAtHostTime` function. Clients may reset this beat time to a chosen value via the `ABLLinkResetBeatTime` function, which is useful for aligning the values on the library's beat timeline to an app's transport timeline.

####Host Time at Output
All host time values used in the Link API refer to host times at output. This is the important value for the library to know, since it must coordinate the timelines of multiple devices such that audio for the same beat time is hitting the output of those devices at the same moment. This is made more complicated by the fact that different devices (and even the same device in different configurations) can have different output latencies.

In the audio callback, the system provides an `AudioTimeStamp` value for the audio buffer. The `mHostTime` field of this structure represents the host time at which the audio buffer will be passed to the hardware for output. Adding the output latency (see `AVAudioSession.outputLatency`) to this value will result in the correct host time at output for the *beginning* of that buffer. To get the host time at output for the end of the buffer, you would just add the buffer duration. For an example of this calculation, see the [LinkHut example project](examples/LinkHut/LinkHut/AudioEngine.m).

Note that if your app adds additional software latency, you will need to add this as well in the calculation of the host time at output. Also note that the `AVAudioSession.outputLatency` property can change, so you should update your output latency in response to the [`AVAudioSessionRouteChangedNotification`](https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVAudioSession_ClassReference/#//apple_ref/c/data/AVAudioSessionRouteChangeNotification) in order to maintain the correct values in your latency calculations.

###Link API Usage
This section contains extended discussion on the contents of the C header [ABLLink.h](include/ABLLink.h) and the Objective-C header [ABLLinkSettingsViewController.h](include/ABLLinkSettingsViewController.h), which togther make up the Link API.

####Initialization and Destruction
An ABLLink library instance is created with the `ABLLinkNew` function. All other API functions take a library instance as an argument, so calling this is a pre-requisite to using the rest of the API. It is recommended that the library instance be created on the main thread during app initialization and that it be preserved for the lifetime of the app. There should not be a reason to create and destroy multiple instances of the library during an app's lifetime. To cleanup the instance on app shutdown, call `ABLLinkDelete`.

An app must provide an initial tempo and quantum value when creating an instance of the library. The tempo is required because, as mentioned in the [*Host and Beat Times*](#host-and-beat-times) section, a library instance starts running a beat timeline from the moment it is initialized. The initial tempo provided to `ABLLinkNew` determines the rate of progression of this beat timeline until the app sets a new tempo or a new tempo comes in from the network. It is important that a valid tempo be provided to the library at initialization time, even if it's just a default value like 120bpm.

The quantum parameter provides the initial value of the library instance's quantum property. It's necessary for the library to have an appropriate quantum at initialization time because this value is used to compute the timeline offset when joining a Link session (see the [Phase Synchronization](#phase-synchronization) section for more on this). For apps that use a constant quantum value, this is the only time the quantum must be specified. Apps that allow the quantum to vary would update it with the `ABLLinkSetQuantum` function.

####Active, Enabled, and Connected
Once an ABLLink instance is created, in order for it to start attempting to connect to other participants on the network, it must be both *active* and *enabled*. The active and enabled properties are two independent boolean conditions, the first of which is controlled by the app, and the second by the end user. So Link needs permission from both the app and the end user before it starts communicating on the network.

The enabled state is controlled directly by the user via the [`ABLLinkSettingsViewController`](include/ABLLinkSettingsViewController.h). It is persisted across app runs, so if the user enables Link they don't have to re-enable it every time they re-launch the app. Since it is a persistent value that is visible and meaningful to the user, the API does not allow it to be modified programmatically by the app. However, the app can observe the enabled state via the `ABLLinkIsEnabled` function and the `ABLLinkSetIsEnabledCallback` callback registration function. These should only be needed to update UI elements that reflect the Link-enabled state. If you are dependening on the enabled state in audio code, you're doing something wrong (you should probably be using `ABLLinkIsConnected` instead. More on that soon...)

The active state is controlled by the app via the `ABLLinkSetActive` function. This is primarily used to implement [background behavior](#background-behavior) - by calling `ABLLinkSetActive(false)` when going to the background, an app can make sure that the ABLLink instance is not communicating on the network when it's not needed or expected.

When an ABLLink instance is both active and enabled, it will attempt to find other participants on the network in order to form a Link session. When at least one other participant has been found and a session has been formed, then the instance is considered connected. This state can be queried with the `ABLLinkIsConnected` function.

####Controlling Tempo
Since Link synchronizes tempo between participants in a session, apps must pass any tempo modifications made by the user to the ABLLink library via the `ABLLinkProposeTempo` function. Tempo proposals may not always be adopted by other participants in the session (for example if network communication fails temporarily or if a competing proposal is made by another participant), but they will always be adopted locally by the library.

The `ABLLinkProposeTempo` function takes a `hostTimeAtOutput` parameter, which provides an exact timestamp for the tempo proposal (see the [Host Time at Output](#host-time-at-output) section for a discussion of this unit). This is needed for accuracy of timing so that all participants can consider the tempo change to have occured at the exact same moment. Tempo proposal timestamps also serve to order proposals with respect to a common time reference so that all participants have a consistent understanding of which tempo proposal is most recent (and therefore the one to be used). It's important to understand that this function cannot accept arbitrary timestamp values - for example, it does not make sense to specify a tempo change that happened in the past. It is also not supported to specify tempo changes to happen arbitrarily far in the future. The timestamp must be roughly around now + latency or the tempo proposal will be ignored.

`ABLLinkProposeTempo` is safe and recommended to call from the audio thread, as this will provide the most accurate timing. In common usage, this function would be called with a new tempo value at the beginning of the audio callback with the `hostTimeAtOutput` corresponding to the *beginning* of the current buffer. Subsequent calls to `ABLLinkBeatTimeAtHostTime` and `ABLLinkHostTimeAtBeatTime` in the callback will give results based on this new tempo. You can see an example of this usage in the LinkHut [AudioEngine.m](examples/LinkHut/LinkHut/AudioEngine.m) file.

Since any participant can propose a new tempo to the session, your app must be prepared to observe and adopt changes made to the session tempo by other participants. At the audio level, there is no work to do - the new session tempo will automatically be incorporated into the results of the `ABLLinkBeatTimeAtHostTime` and `ABLLinkHostTimeAtBeatTime` functions. However, for the purpose of updating your app's tempo display, you can query the current session tempo with `ABLLinkGetSessionTempo` and register for tempo change callbacks with `ABLLinkSetSessionTempoCallback`. The session tempo values exposed by these functions are stable values that are appropriate for display to the user. It's important to understand that you should not try to derive the current tempo for each buffer and display that to the user. Individual buffer tempos will be much noisier than the reported session tempo as the ABLLink library is frequently making slight adjustments to keep everyone in sync.

####Quantized Launch and `ABLLinkResetBeatTime`
TODO

####Observing Phase
TODO

###App Life Cycle
In order to provide the best user experience across the ecosystem of Link-enabled apps, it's important that apps take a consistent approach towards Link with regards to life cycle management. Furthermore, since the Link library does not have access to all of the necessary information to correctly respond to life cycle events, app developers must follow the life cycle guidelines below in order to meet user expectations. Please consider these carefully.

- When an app moves to the background and it is known that no audio will be generated by the app while in the background, Link should be deactivated by calling `ABLLinkSetActive(false)` - *even if background audio has been enabled for the app*. This helps prevent the confusing situation where a silent background app discovers and connects to other Link enabled apps and devices.
- When an app is active, Link should be active. If an app deactivates Link using the `ABLLinkSetActive` function when going to the background, it must re-activate Link when becoming active again. For this reason, it is recommended that a call to `ABLLinkSetActive(true)` be included in the `applicationDidBecomeActive` method of the application delegate. Calling this function when Link is already active causes no harm, so this can be included unconditionally.
- There are situations where an app may generate audio while in the background, such as when it's part of an Audiobus or IAA session or if it's listening to MIDI input. In these cases, Link should remain active when the app moves to the background.
- It is possible for an app to be added to an Audiobus or IAA session while it is in the background. If Link was deactivated when moving to the background and the app is then added to an Audiobus or IAA session, Link should be re-activated in anticipation of playing audio as part of the session. Conversely, if an app in the background is ejected from an Audiobus or IAA session and will therefore no longer be playing audio, it should deactivate Link. Handling these cases correctly will generally require listening to the [ABConnectionsChangedNotification](https://developer.audiob.us/doc/_a_b_audiobus_controller_8h.html#a336d7bc67873e51abf5b09f7fe15b9f4).

Please see the LinkHut [AppDelegate.m](examples/LinkHut/LinkHut/AppDelegate.m) file for a basic example of implementing the app life cycle guidelines, although it does not support Audiobus or IAA.

###Audiobus
We have worked closely with the developers of Audiobus to provide some additional features when using Link-enabled apps within Audiobus. In order to take advantage of these additional features, please be sure to build against the latest available version of the Audiobus SDK when adding Link to your app. No code changes are required on your part to enable the Audiobus-Link integration.

##Test Plan
Below are a set of user interactions that are expected to work consistently across all Link-enabled apps. In order to provide the best user experience, it's important that apps behave consistently with respect to these test cases. *Please verify that your app passes __all__ of the test cases before submitting to the App Store.* Apps that do not pass this test suite will not be considered conforming Link integrations.

###Tempo Changes
- **TEMPO-1**: *Tempo changes should be transmitted between connected apps*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open App and set Link to **Enabled**
  - Without starting to play, change tempo in App **->** LinkHut clicks should speed up or slow down to match the tempo specified in the App.
  - Start playing in the App **->** App and LinkHut should be in sync
  - Change tempo in App and in LinkHut **->** App and LinkHut should remain in sync
- **TEMPO-2**: *Opening an app with Link enabled should not change the tempo of an existing Link session*
  - Open App and set Link to **Enabled**.
  - Set App tempo to 100bpm.
  - Terminate App.
  - Open LinkHut, press **Play** and set Link to **Enabled**.
  - Set LinkHut tempo to 130bpm.
  - Open App **->** Link should be connected (“1 Link”) and the App and LinkHut’s tempo should both be 130bpm.
- **TEMPO-3**: *When connected, loading a new document should not change the Link session tempo*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Set LinkHut tempo to 130bpm.
  - Open App and set Link to **Enabled** **->** LinkHut’s tempo should not change.
  - Load new Song/Set/Session with a tempo other than 130bpm **->** App and LinkHut tempo should both be 130bpm.
- **TEMPO-4**: *Tempo range handling*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open App, start Audio, and set Link to **Enabled**.
  - Change tempo in LinkHut to **20bpm** **->** App and LinkHut should stay in sync.
  - Change Tempo in LinkHut to **999bpm** **->** App and LinkHut should stay in sync.
  - If App does not support the full range of tempos supported by Link, it should stay in sync by switching to a multiple of the Link session tempo.

###Background Behavior
These cases test the correct implementation of the [app life cycle guidelines](#app-life-cycle).
- **BACKGROUND-1**: *Link remains active when going to the background while playing audio*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open App and set Link to **Enabled**.
  - Start playing audio.
  - Open LinkHut, press **Settings** **->** there should be 1 connected app
- **BACKGROUND-2**: *Link is deactivated when going to the background and audio will not be played while in background*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open App and set Link to **Enabled**.
  - Stop App from playing audio and put it in the background
  - Open LinkHut, press **Settings** **->** there should be 0 connected apps.
  - Bring App to the foreground again **->** there should be a notification “1 Link” and the Link settings should reflect this.
  - Disable and enable Link in App **->** there should be a notification “1 Link” and the Link settings should reflect this.
  - **Note**: This is the expected behavior even if the App's background audio mode is enabled. Whenever the App goes to the background and it's known that the App will not be playing audio while in the background (not receiving MIDI, not connected to IAA or Audiobus), Link should be deactivated.
- **BACKGROUND-3** - *Link remains active when going to background while part of an IAA or Audiobus session (if supported).*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open Audiobus and add the App as **Input**.
  - Switch to the App and set Link to **Enabled** **->** there should be a notification "1 Link" and the Link settings should reflect this.
  - Make sure the App is not playing and switch to LinkHut **->** No notification is presented. The Link settings should still indicate 1 connected App.
  - **Note**: While connected to Audiobus/IAA Link must remain active even while not playing in the background because the App must be prepared to start playing at anytime.
- **BACKGROUND-4** - *Link is activated when App added to an Audiobus or IAA session while not playing in the background (if supported).*
  - Open LinkHut, press **Play**, and set Link to **Enabled**.
  - Open App and set Link to **Enabled**.**->** The Link settings should indicate 1 connected App.
  - Make sure the app is not playing and switch to Audiobus
  - Add the App as **Input** in Audiobus. Do this without tapping to wake it up. If the App is sleeping, switch back to it and then back to Audiobus and try again.
  - Switch back to LinkHut **->** The Link settings should indicate 1 connected App.
  - Switch back to Audibus and eject the App from the Audiobus session
  - Switch back to LinkHut **->** The Link settings should indicate 0 connected Apps.
  - **Note**: When an App in the background has deactivated Link, it must re-activate it if it becomes part of an Audiobus or IAA session, even if does not come to the foreground. Conversely, an App that is part of an Audiobus or IAA session session and is then disconnected from the session while in the background and not playing should deactivate Link.

##Promoting Link Integration
After investing the time and effort to add Link to your app, you will probably want to tell the world about it. When you do so, please be sure to follow our [Ableton Link promotion guidelines](docs/Ableton Link Promotion.pdf). The Link badge referred to in the guidelines can be found in the [assets](assets) folder. You can also find additional info and images in our [press kits](https://ableton.com/press) and use them as you please.
