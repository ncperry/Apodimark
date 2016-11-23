Pod::Spec.new do |spec|
    spec.name         = 'Apodimark'
    spec.version      = '0.4.1'
    spec.osx.deployment_target = "10.12"

    spec.summary      = 'Fast, flexible Markdown parser in Swift'
    spec.author       = 'Loïc Lecrenier'
    spec.homepage     = 'https://github.com/loiclec/Apodimark.git'
    spec.license      = { :type => 'MIT', :file => 'LICENSE.txt' }
    spec.source       = { :git => 'https://github.com/ncperry/Apodimark.git', :tag => '0.4.1' }
    spec.source_files = 'Sources/**/*.swift'

end
