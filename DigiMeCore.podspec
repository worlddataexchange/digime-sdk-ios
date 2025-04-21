Pod::Spec.new do |s|

    s.name         	= "DigiMeCore"
    s.version      	= "5.1.1"
    s.summary      	= "digi.me iOS Consent Access SDK Core Component"
    s.homepage     	= "https://github.com/digime/digime-sdk-ios"
    s.license      	= { :type => "MIT", :file => "LICENSE" }
    s.author       	= { "digi.me Ltd." => "ios@digi.me" }
    s.platform     	= :ios, "13.0"
    s.swift_version = "5.0"
    s.source       	= {
        :git => "https://github.com/digime/digime-sdk-ios.git",
        :tag => s.version
    }
    
    s.source_files 	= "DigiMeCore/Sources/DigiMeCore/**/*.swift"
    s.frameworks    = "Foundation", "Security"

end
