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

####T3 – Background behaviour when audio is stopped
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App and set Link to **Enabled**.
- Stop App from playing audio and put it in the background
- Open LinkHut, press **Settings** **->** there should be “0 Links."
- Bring App to the foreground again **->** there should be a notification “1 Link” and the Link settings should reflect this.
- Disable and enable Link in App **->** there should be “1 Link” and the Link settings should reflect this.

####T4 – Tempo changes
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App, start Audio, and set Link to **Enabled**.
- Change Tempo in App and LinkHut -> App and LinkHut should remain in sync.

####T5 – Tempo changes while transport stopped
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App and set Link to **Enabled**.
- Change Tempo in App **->** LinkHut should change tempo accordingly.

####T6 – Tempo range
- Open LinkHut, press **Play**, and set Link to **Enabled**.
- Open App, start Audio, and set Link to **Enabled**.
- Change tempo in LinkHut to **20bpm** **->** App and LinkHut should stay in sync.
- Change Tempo in LinkHut to **999bpm** **->** App and LinkHut should stay in sync.
- If App does not support the full range of tempos supported by Link, it should stay in sync by switching to a multiple of the Link session tempo.
