Pod::Spec.new do |s|
  s.name     = 'QHPageViewController'
  s.version  = '0.1.0'
  s.license  = 'MIT'
  s.summary  = 'QHPageViewController'
  s.homepage = 'https://github.com/imqiuhang/QHPageViewController'
  s.author   = { 'imqiuhang' => 'imqiuhang@hotmail.com' }
  s.source = { git: "https://github.com/imqiuhang/QHPageViewController.git", tag: s.version.to_s }
  s.source_files = 'QHPageViewController/**/*.{h,m}'
  # s.resource_bundles = {
  #   'QHPageViewControllerResources' => ['QHPageViewController/Resource/**/*.{xcassets,xib}']
  # }

  s.requires_arc = true
  s.xcconfig = { 'CLANG_MODULES_AUTOLINK' => 'YES' }
  s.ios.deployment_target = '8.0'

  
end
