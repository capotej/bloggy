require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rake/clean'

class String
  def /(other)
    File.join(self, other)
  end
end

require 'lib/ebb/version'

libev_dist = "http://dist.schmorp.de/libev/Attic"
libev_release = "libev-3.43.tar.gz"
libev_url = File.join(libev_dist, libev_release)

LIBEBBFILES = ['ebb.c', 'ebb.h',
               'ebb_request_parser.rl', 'ebb_request_parser.c', 'ebb_request_parser.h', 
               'rbtree.c', 'rbtree.h']
SRCEBBFILES = LIBEBBFILES.map { |f| "ext" / f }

DISTFILES = FileList.new('libev/*.{c,h}', 'lib/**/*.rb', 'ext/*.{rb,rl,c,h}', 'README', 'Rakefile') + SRCEBBFILES
CLEAN.add ["**/*.{o,bundle,so,obj,pdb,lib,def,exp}", "benchmark/*.dump", 'site/index.html']
CLOBBER.add ['ext/Makefile', 'ext/mkmf.log'] + SRCEBBFILES

Rake::TestTask.new do |t|
  t.test_files = FileList.new("test/*.rb")
  t.verbose = true
end

LIBEBBFILES.each do |f|
  file(".libebb"/f => ".libebb") 
  file("ext"/f => ".libebb"/f) do |t|
    sh "cp .libebb/#{f} ext/#{f}"
  end
end

task(:default => [:compile])

task(:compile => ['ext/Makefile','libev'] + SRCEBBFILES) do
  sh "cd ext && make"
end

file "libev" do
  puts "downloading libev"
  sh "wget #{libev_url}" do |ok, res|
    if ! ok
      puts "Couldn't download libev. Please put #{libev_url} in here and try again"
      exit 1
    end
  end
  sh "tar -zxf #{libev_release}"
  sh "mv #{libev_release.sub('.tar.gz', '')} libev"
end

file ".libebb" do
  sh "git clone git://github.com/ry/libebb.git .libebb"
end

file('ext/Makefile' => 'ext/extconf.rb') do
  sh "cd ext && ruby extconf.rb"
end

file(".libebb/ebb_request_parser.c" => '.libebb/ebb_request_parser.rl') do
  sh 'ragel -s -G2 .libebb/ebb_request_parser.rl'
end

task(:test => DISTFILES)
Rake::TestTask.new do |t|
  t.test_files = 'test/basic_test.rb'
  t.verbose = true
end

task(:site_upload => :site) do
  sh 'scp -r site/* rydahl@rubyforge.org:/var/www/gforge-projects/ebb/'
end
task(:site => 'site/index.html')
file('site/index.html' => %w{README site/style.css}) do
  require 'rubygems'
  require 'bluecloth'
  doc = BlueCloth.new(File.read('README'))
  template = <<-HEREDOC
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Ebb</title>
    <link rel="alternate" href="http://max.kanat.us/tag-syndicate/?user=four&tag=ebb" title="RSS Feed" type="application/rss+xml" />
    <link type="text/css" rel="stylesheet" href="style.css" media="screen"/>
  </head>
  <body>  
    <div id="content">CONTENT</div>
  </body>
</html>
HEREDOC
  
  File.open('site/index.html', "w+") do |f|
    f.write template.sub('CONTENT', doc.to_html)
  end
end

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "A Web Server"
  s.description = ''
  s.name = 'ebb'
  s.author = 'ry dahl'
  s.email = 'ry at tiny clouds dot org'
  s.homepage = 'http://ebb.rubyforge.org'
  s.version = Ebb::VERSION
  s.rubyforge_project = 'ebb'
  
  s.required_ruby_version = '>= 1.8.4'
  
  s.require_path = 'lib'
  s.extensions = 'ext/extconf.rb'
  
  s.files = DISTFILES
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
end
