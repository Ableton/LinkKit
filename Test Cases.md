##Test cases
Below are a set of user interactions to test with apps integrating Link. In order to provide the best user experience across Link-enabled apps, it's important that apps behave consistently with respect to these cases:

####T1 - When connected, loading a new document should not change the Link session tempo
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App and set Link to **Enabled** **->** LinkHut’s tempo should not change.
- Load new Song/Set/Session **->** LinkHut’s tempo should not change.

####T2 – Opening an App with Link enabled should not change the tempo of an existing Link session
- Open App and set Link to **Enabled**.
- Terminate App.
- Open LinkHut, press **Play** and set Link to **Enabled**.
- Open App **->** Link should be connected (“1 Link”) and LinkHut’s tempo should not change.

####T3 – Tempo changes
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App, start Audio, and set Link to **Enabled**.
- Change Tempo in App and LinkHut -> App and LinkHut should remain in sync.

####T4 – Tempo changes while transport stopped
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App and set Link to **Enabled**.
- Change Tempo in App **->** LinkHut should change tempo accordingly.

####T5 – Tempo range
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App, start Audio, and set Link to **Enabled**.
- Change tempo in LinkHut to **20bpm** **->** App and LinkHut should stay in sync.
- Change Tempo in LinkHut to **999bpm** **->** App and LinkHut should stay in sync.
- If App does not support the full range of tempos supported by Link, it should stay in sync by switching to a multiple of the Link session tempo.

####T6 – Link is deactivated when going to background and audio will not be played while in background
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App and set Link to **Enabled**.
- Stop App from playing audio and put it in the background
- Open LinkHut, press **Settings** **->** there should be “0 Links."
- Bring App to the foreground again **->** there should be a notification “1 Link” and the Link settings should reflect this.
- Disable and enable Link in App **->** there should be “1 Link” and the Link settings should reflect this.
- **Note**: This is the expected behavior even if the App's background audio mode is enabled. Whenever the App goes to the background and it's known that the App will not be playing audio while in the background (not receiving MIDI, not connected to IAA or Audiobus), Link should be deactivated. This is important because otherwise Link may remain enabled and connecting to peers and networks after the user has put the device away. Please see the `ABLLinkSetActive` function to activate/deactivate Link.

####T7 - Link remains active when going to background while part of an IAA or Audiobus session (if supported)
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open Audiobus and add the App as **Input**.
- Switch to the App and set Link to **Enabled** **->** there should be a notification "1 Link" and the Link settings should reflect this.
- Make sure that App transport is stopped and switch to LinkHut **->** No notification is presented. The Link settings should still indicate 1 connected App.
- **Note**: While connected to Audiobus Link must remain active even while not playing in the background because the App must be prepared to start playing at anytime.

####T8 - Link is activated when App added to an Audiobus or IAA session while not playing in the background.
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App to test and set Link to **Enabled**.**->** The Link settings should indicate 1 connected App.
- Make sure transport is stopped and switch to Audiobus
- Add the App as **Input** in Audiobus. Do this without tapping to wake it up. If the App is sleeping, switch back to it and then back to Audiobus and try again.
- Switch back to LinkHut **->** The Link settings should indicate 1 connected App.
- Switch back to Audibus and eject the App from the Audiobus session
- Switch back to LinkHut **->** The Link settings should indicate 0 connected Apps.
- **Note**: When an App in the background has deactivated Link, it must re-activate it if it becomes part of an Audiobus or IAA session, even if does not come to the foreground. Conversely, an App that is part of an Audiobus or IAA session session and is then disconnected from the session while in the background and not playing should deactivate Link. This can be achieved by listening to the Audiobus `ABConnectionsChangedNotification`.
