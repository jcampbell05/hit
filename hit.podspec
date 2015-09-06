Pod::Spec.new do |s|

  s.name         = "hit"
  s.version      = "0.2"
  s.summary      = "Lightweight full-text search written in Swift"

  s.description  = <<-DESC
                   `hit` helps you quickly search your data for either a prefix or an exact match.
                   DESC

  s.homepage     = "https://github.com/czechboy0/hit"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Honza Dvorsky" => "http://honzadvorsky.com" }
  s.social_media_url   = "https://twitter.com/czechboy0"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.source       = { :git => "https://github.com/czechboy0/hit.git", :tag => "v#{s.version}" }
  s.source_files  = "hit/*.{swift}"
  s.requires_arc = true

end
