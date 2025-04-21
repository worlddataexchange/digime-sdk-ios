Pod::Spec.new do |s|

    s.name          = "DigiMeSDK"
    s.version       = "5.1.1"
    s.summary       = "digi.me iOS Consent Access SDK"
    s.homepage      = "https://github.com/digime/digime-sdk-ios"
    s.license       = { :type => "MIT", :file => "LICENSE" }
    s.author        = { "digi.me Ltd." => "ios@digi.me" }
    s.platform      = :ios, "13.0"
    s.swift_version = "5.0"
    s.source        = {
        :git => "https://github.com/digime/digime-sdk-ios.git",
        :tag => s.version
    }

    # Core functionality
    s.subspec 'Core' do |core|
        core.dependency 'DigiMeCore'
        core.frameworks = "Foundation", "Security"
        core.source_files = "DigiMeSDK/Sources/DigiMeSDK/**/*.swift"
    end

    # Core an HealthKit functionality
    s.subspec 'HealthKit' do |healthkit|
        healthkit.dependency 'DigiMeHealthKit'
        healthkit.frameworks = "Foundation", "CoreLocation", "HealthKit", "Security"
        healthkit.source_files = "DigiMeSDK/Sources/DigiMeSDK/**/*.swift"
    end
end
