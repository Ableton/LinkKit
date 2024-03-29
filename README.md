# LinkKit

iOS SDK for [Ableton Link](https://ableton.com/link). An overview of Link concepts can be found at https://ableton.github.io/link. All iOS specific documentation, integration guidelines, and test plans can be found at https://ableton.github.io/linkkit.

The LinkKit SDK is distributed as a zip file attached to a release in this repo. Please see the [releases tab](https://github.com/Ableton/LinkKit/releases) for the latest release. It is strongly recommended to build apps against an official release for final submission to the App Store. Official releases are those not marked "Pre-release".

##### By using LinkKit you agree to the terms and conditions of the [Ableton Link SDK license](LICENSE.md).

## iOS 14 Compatibility
Link uses UDP multicast messages on the local area network to find other peers. Apple added security measures to iOS 14, that require a special entitlement for the app to be able to send those messages. You can find more information in the [LinkKit documentation](https://ableton.github.io/linkkit/#ios-14-compatibility).

## iOS 17 Compatibility
Apple enforces entitlements more strictly since iOS 17. To be able to detect other Link peers on the LAN your application needs the `com.apple.developer.multicast` entitlement.

## Building
It is strongly recommended to use the pre-built version of LinkKit. For debugging and accommodation of exceptional requirements, it is possible to build LinkKit as described below.


**Custom builds of LinkKit depend on the [cross-platform version of Link](https://github.com/ableton/link) and are subject to [this license](https://github.com/Ableton/link/blob/master/LICENSE.md).**
Please note that the GPL is not compatible with the iOS App Store.

#### Creating a Xcode project

To generate and open a Xcode Project, use `make xcode link_dir=$PATH_TO_LINK_REPOSITORY`.
The Xcode Project will be located in the `build` directory.

#### Building a Release Bundle

Use `make link_dir=$PATH_TO_LINK_REPOSITORY` to generate a release bundle for all target platforms.
The bundle can be found at `build/output/LinkKit.zip`.
