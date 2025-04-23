Pod::Spec.new do |s|

    s.name         	= "DigiMeCore"
    s.version      	= "5.1.2"
    s.summary      	= "WDX iOS Consent Access SDK Core Component"
    s.homepage     	= "https://github.com/worlddataexchange/digime-sdk-ios"
    s.license      	= { :type => "MIT", :file => "LICENSE" }
    s.author       	= { "World Data Exchange Ltd." => "ios@worlddataexchange.com" }
    s.platform     	= :ios, "13.0"
    s.swift_version = "5.0"
    s.source       	= {
        :git => "https://github.com/worlddataexchange/digime-sdk-ios.git",
        :tag => s.version
    }
    
    s.source_files 	= "DigiMeCore/Sources/DigiMeCore/**/*.swift"
    s.frameworks    = "Foundation", "Security"

end
