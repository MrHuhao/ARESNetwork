Pod::Spec.new do |s|

  s.name         = "ARESNetwork"
  s.version      = "0.0.1"
  s.summary      = "ARESNetwork"

  s.homepage     = "https://github.com/MrHuhao/ARESNetwork"

  s.license      = "MIT ()"


  s.author             = { "MrHuhao" => "email@address.com" }
  # Or just: s.author    = "MrHuhao"
  # s.authors            = { "MrHuhao" => "email@address.com" }
  # s.social_media_url   = "http://twitter.com/MrHuhao"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

  # s.platform     = :ios
  # s.platform     = :ios, "5.0"

  #  When using multiple platforms
  # s.ios.deployment_target = "5.0"
  # s.osx.deployment_target = "10.7"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  s.source       = { :git => "https://github.com/MrHuhao/ARESNetwork.git", :commit => "fedbd9db646567f3b83ed7542e7aba6af806e15e" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any h, m, mm, c & cpp files. For header
  #  files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  s.requires_arc = true

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.public_header_files = 'src/ARESNetworking/*.h'
  s.source_files = 'src/ARESNetworking/ARESNetworking.h'

  # s.public_header_files = "Classes/**/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"

  # s.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # s.framework  = "SomeFramework"
  # s.frameworks = "SomeFramework", "AnotherFramework"

  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # s.dependency "JSONKit", "~> 1.4"
s.subspec 'Serialization' do |ss|
    ss.source_files = 'src/ARESNetworking/ARESURL{Request,Response}Serialization.{h,m}'
    ss.ios.frameworks = 'MobileCoreServices', 'CoreGraphics'
    ss.osx.frameworks = 'CoreServices'
  end

  s.subspec 'Security' do |ss|
    ss.source_files = 'src/ARESNetworking/ARESSecurityPolicy.{h,m}'
    ss.frameworks = 'Security'
  end

  s.subspec 'Reachability' do |ss|
    ss.source_files = 'src/ARESNetworking/ARESNetworkReachabilityManager.{h,m}'
    ss.frameworks = 'SystemConfiguration'
  end

  s.subspec 'NSURLConnection' do |ss|
    ss.dependency 'src/ARESNetworking/Serialization'
    ss.dependency 'src/ARESNetworking/Reachability'
    ss.dependency 'src/ARESNetworking/Security'

    ss.source_files = 'src/ARESNetworking/ARESURLConnectionOperation.{h,m}', 'src/ARESNetworking/ARESHTTPRequestOperation.{h,m}', 'src/ARESNetworking/ARESHTTPRequestOperationManager.{h,m}'
  end

  s.subspec 'NSURLSession' do |ss|
    ss.dependency 'ARESNetworking/Serialization'
    ss.dependency 'ARESNetworking/Reachability'
    ss.dependency 'ARESNetworking/Security'

    ss.source_files = 'src/ARESNetworking/ARESURLSessionManager.{h,m}', 'src/ARESNetworking/ARESHTTPSessionManager.{h,m}'
  end

  s.subspec 'UIKit' do |ss|
    ss.ios.deployment_target = '6.0'

    ss.dependency 'ARESNetworking/NSURLConnection'
    ss.dependency 'ARESNetworking/NSURLSession'

    ss.ios.public_header_files = 'UIKit+ARESNetworking/*.h'
    ss.ios.source_files = 'UIKit+ARESNetworking'
    ss.osx.source_files = ''
  end
end
