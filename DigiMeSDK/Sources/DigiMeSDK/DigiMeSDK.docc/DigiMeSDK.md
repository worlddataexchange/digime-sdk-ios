# ``DigiMeSDK``

Digi.me - The Private Sharing Platform 

## Introduction

The digi.me private sharing platform empowers developers to make use of user data from thousands of sources in a way that fully respects user privacy and conforms to GDPR. Our consent-driven solution allows precise definition of data terms, offering transparent choices to users for granting consent.

## digi.me SDK Structure

The digi.me SDK is split into three primary components to provide modular integration and flexibility:

- **DigiMeSDK**: The main SDK module providing core functionalities and interfaces for integration.
  
- **DigiMeCore**: Contains all class definitions and foundational elements used across the SDK.
  
- **DigiMeHealthKit**: An independent module that extends the SDK for applications consuming or using Apple Health data. It should be included only if your application intends to access Apple Health data.

## DigiMeSDK
This is the primary SDK module. It encapsulates the core functionalities required to interact with the digi.me platform. It is designed for straightforward integration into your project.

## DigiMeCore
DigiMeCore defines all the classes and fundamental definitions used across the SDK. It serves as the foundational layer upon which DigiMeSDK builds. As a critical dependency module, `DigiMeCore` is automatically included when you integrate `DigiMeSDK` into your project. 

While `DigiMeCore` is automatically included as part of the `DigiMeSDK`, you might find the need to directly access its object definitions and classes. In such cases, you can explicitly import `DigiMeCore` in your Swift classes to utilize its components. 

[Go to DigiMeCore Documentation](https://digime.github.io/digime-sdk-ios/DigiMeCore/documentation/digimecore/)

## DigiMeHealthKit
This module provides functionality specific to Apple HealthKit. It's an optional addition to the main SDK for apps that require access to Apple Health data.

[Go to DigiMeHealthKit Documentation](https://digime.github.io/digime-sdk-ios/DigiMeHealthKit/documentation/digimehealthkit/)


## Requirements

### Deployment
- iOS 13+


## Installation
### Swift Package Manager

#### Add dependencies

1. Add the `DigiMeSDK` package to the dependencies within your application's `Package.swift` or your Xcode project. Substitute `"x.x.x"` with the latest `DigiMeSDK` [release](https://github.com/digime/digime-sdk-ios/releases).

	```swift
	.package(name: "DigiMeSDK", url: "https://github.com/digime/digime-sdk-ios.git", from: "x.x.x")
	```

2. Add `DigiMeSDK` to your target's dependencies:

	```swift
	.target(name: "example", dependencies: ["DigiMeSDK"]),
	```

#### Import package

```swift
import DigiMeSDK
```

#### Utilizing Apple Health Functionality

If your application requires access to Apple Health data, you will also need to include the DigiMeHealthKit module.

1. Add DigiMeHealthKit to your Package.swift file:

```Swift
.package(name: "DigiMeHealthKit", url: "https://github.com/digime/digime-healthkit-ios.git", from: "x.x.x")
```
2. Include DigiMeHealthKit in your target's dependencies:

```Swift
.target(name: "YourTargetName", dependencies: ["DigiMeSDK", "DigiMeHealthKit"]),
```

#### Import HealthKit Package

When using Apple Health functionality, import **DigiMeHealthKit** in your Swift files to get access to **DigiMeHealthKit** related object definitions:

```Swift
import DigiMeHealthKit
```


### Cocoapods

1. Add `DigiMeSDK` to your `Podfile`:

	```ruby
	use_frameworks!
	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '13.0'

	target 'TargetName' do
		pod 'DigiMeSDK'
        pod 'DigiMeHealthKit' # If your application requires access to Apple Health data, you will also need to include the DigiMeHealthKit module.
	end
	```
> NOTE
> We do not currently support linking DigiMeSDK as a Static Library.
>
> **use_frameworks!** flag must be set in the Podfile

2. Navigate to the directory of your `Podfile` and run the following command:

	```bash
	$ pod install --repo-update
	```

## Getting Started - 5 Simple Steps!

We have taken the most common use case for the digi.me Private Sharing SDK and compiled a quick start guide, which you can find below. Nonetheless, we implore you to [explore the documentation further](https://digime.github.io/digime-sdk-ios/index.html).

This example will show you how to configure the SDK, and get you up and running with **retrieving user data**.

### 1. Obtaining your Contract ID, Application ID & Private Key:

To access the digi.me platform, you need to obtain an `AppID` for your application. You can get yours by filling out the registration form [here](https://go.digi.me/developers/register).

In a production environment, you will also be required to obtain your own `Contract ID` and `Private Key` from digi.me support. However, for sandbox purposes, you can use one of the contracts from the example projects (see `/Examples` directory).

### 2. Configuring Callback Forwarding:

Because the digi.me Private Sharing SDK hooks into your browser to receive callbacks, you are required to forward the `openURL` event through to the SDK so that it may process responses. In your application's delegate (typically `SceneDelegate`) override `scene:openURLContexts:` method as below:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
   	guard let context = URLContexts.first else {
		return
   	}
   
   	CallbackService.shared().handleCallback(url: context.url)
}
```

And register custom URL scheme so that your app can receive the callback from Digi.me app. Still in `Info.plist` add:

```xml
<key>CFBundleURLTypes</key>
<array>
<dict>
<key>CFBundleTypeRole</key>
<string>Editor</string>
<key>CFBundleURLName</key>
<string>Consent Access</string>
<key>CFBundleURLSchemes</key>
<array>
<string>digime-ca-YOUR_APP_ID</string>
</array>
</dict>
</array>
```
where `YOUR_APP_ID` should be replaced with your `AppID`.

### 3. Configuring the `DigiMe` object:
`DigiMe` is the object you will primarily interface with to use the SDK. It is instantiated with a `Configuration` object.

The `Configuration` object is instantiated with your `App ID`, `Contract ID` and `Private Key`. The below code snippet shows you how to combine all this to get a configured `DigiMe` object:

```swift
let privateKey = """
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA...
-----END RSA PRIVATE KEY-----
"""

do {
    let configuration = try Configuration(appId: "YOUR_APP_ID", contractId: "YOUR_CONTRACT_ID", privateKey: privateKey)
    let digiMe = DigiMe(configuration: configuration)
}
catch {
    ...
}
```

### 4. Requesting Consent:

Before you can access a user's data, you must obtain their consent. This is achieved by calling `authorize` on your client object. You need to provide a service identifier for which you want to request access to; this can be found by referring the the service definitions in the developer docs or my using the [Discovery API](#).:

```swift
digiMe.authorize(serviceId: service?.identifier, readOptions: nil) { result in
    switch result {
    case .success(let credentials):
        // store credentials and continue on to fetch data.
    
    case.failure(let error):
        // handle failure.
    }
}
```

If a user grants consent, a session will be created under the hood; this is used by subsequent calls to get data. If the user denies consent, an error stating this is returned. See [Handling Errors](https://digime.github.io/digime-sdk-ios/error-handling.html).

### 5. Fetching Data:

Once you have a session, you can request data. We strive to make this as simple as possible, so expose a single method to do so:

```swift
let credentials = my_stored_credentials
digiMe.readAllFiles(credentials: credentials, readOptions: nil) { result in
	switch result {
   	case .success(let file):
        // Access data or metadata of file.
        
   case .failure(let error):
       // Handle Error
   }
} completion: { result in
    switch result {
    case .success(let (fileList, refreshedCredentials)):
        // Handle success and update stored credentials as these may have been refreshed.
    case .failure(let error):
        // Handle failure.
    }
}
```

For each file, the first 'file handler' block will be called. If the download was successful, you will receive a `File` object. If the download fails, an error.

Once all files are downloaded, the second block will be invoked to inform you of this. In the case that the data stream is interrupted, or if the session obtained above isn't valid (it may have expired, for example), you will receive an error in the second block. See [Handling Errors](https://digime.github.io/digime-sdk-ios/error-handling.html).

`File` exposes the property `data` which contains the file's raw data along with the `mimeType` property. For files with JSON or image mime types, there are convenience methods to decode that raw data into the appropriate format, so that you can easily extract the values you need to power your app. In addition, `metadata` is available describing the file. In this example, as the data comes from external services, the metadata will be a `mapped` type describing the file's contents and details of associated service.

Note that we also expose other methods if you prefer to manage this process yourself.

## Contributions

digi.me prides itself in offering our SDKs completely open source, under the [Apache 2.0 Licence](LICENCE); we welcome contributions from all developers.

We ask that when contributing, you ensure your changes meet our [Contribution Guidelines](https://digime.github.io/digime-sdk-ios/contributing.html) before submitting a pull request.

## Further Reading

The topics discussed under [Quick Start](getting-started---5-simple-steps) are just a small part of the power digi.me Private Sharing gives to data consumers such as yourself. We highly encourage you to explore the [Documentation](https://digime.github.io/digime-sdk-ios/index.html) for more in-depth examples and guides, as well as troubleshooting advice and showcases of the plethora of capabilities on offer.

Additionally, there are a number of example apps built on digi.me in the examples folder. Feel free to have a look at those to get an insight into the power of Private Sharing.

## Support and Documentation

For more detailed information about the DigiMeSDK and its capabilities, please refer to the [official documentation](https://developers.digi.me).

If you encounter any issues or have questions, please reach out to us at [support@digi.me](mailto:support@digi.me).


