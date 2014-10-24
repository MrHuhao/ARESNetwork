Pod::Spec.new do |s|
  s.name     = 'ARESNetwork'
  s.version  = ‘1.0.0’
  s.license  = 'MIT'
  s.summary  = 'A delightful iOS and OS X networking framework.'
  s.homepage = 'https://github.com/MrHuhao/ARESNetwork'
  s.social_media_url = ‘https://github.com/MrHuhao/ARESNetwork’
  s.authors  = { ‘胡皓’ => ‘334177726@qq.com’ }
  s.source   = { :git => 'https://github.com/MrHuhao/ARESNetwork.git', :tag => "1.0.0", :submodules => true }
  s.requires_arc = true

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.public_header_files = 'src/*/*.h’
  s.source_files = 'src/ARESNetworking/ARESNetwork.h’
  
end
