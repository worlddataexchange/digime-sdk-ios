# DigiMe SDK 5.1.2 Release Notes

## Overview
This release includes user recovery method implementation and migrates CocoaPods repository credentials to World Data Exchange.

## New Features

### SDK-169: User Recovery Method Implementation
- Implemented user recovery method to handle expired refresh tokens
- Added reauthorize method to obtain new authentication tokens without losing library access
- Introduced SourceFetchFilter to selectively trigger data syncs for specific accounts

### SDK-192: CocoaPods Repository Migration
- Migrated CocoaPods repository from DigiMe to World Data Exchange credentials
- Updated ownership information for DigiMeCore, DigiMeHealthKit, and DigiMeSDK pods
- All pods now exclusively owned by World Data Exchange

## Bug Fixes
- Fixed error handling for expired tokens
- Improved error messages for authentication failures
- Refined SDK version compatibility checks

## Compatibility
- iOS 13.0+
- Swift 5.0+

## CocoaPods Details
All three components are now available on CocoaPods trunk:
- DigiMeCore 5.1.2
- DigiMeHealthKit 5.1.2
- DigiMeSDK 5.1.2