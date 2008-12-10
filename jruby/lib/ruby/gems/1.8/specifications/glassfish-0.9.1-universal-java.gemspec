# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{glassfish}
  s.version = "0.9.1"
  s.platform = %q{universal-java}

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Vivek Pandey, Jerome Dochez"]
  s.date = %q{2008-12-04}
  s.default_executable = %q{glassfish}
  s.description = %q{GlassFish gem is an embedded GlassFish V3 application server which would help run your Ruby on Rails application}
  s.email = %q{vivek.pandey@sun.com, jerome.dochez@sun.com}
  s.executables = ["glassfish", "glassfish_rails", "gfadmin"]
  s.extra_rdoc_files = ["LICENSE.txt", "COPYRIGHT"]
  s.files = ["bin/gfadmin", "bin/glassfish", "bin/glassfish_rails", "lib/appclient", "lib/jndi-properties.jar", "lib/package-appclient.xml", "lib/processLauncher.properties", "lib/processLauncher.xml", "lib/registration", "lib/templates", "lib/appclient/appclientlogin.conf", "lib/appclient/client.policy", "lib/appclient/wss-client-config-1.0.xml", "lib/appclient/wss-client-config-2.0.xml", "lib/registration/servicetag-registry.xml", "lib/templates/cacerts.jks", "lib/templates/default-web.xml", "lib/templates/domain.xml", "lib/templates/domain.xml.xsl", "lib/templates/keyfile", "lib/templates/keystore.jks", "lib/templates/logging.properties", "lib/templates/login.conf", "lib/templates/profile.properties", "lib/templates/server.policy", "felix/bin", "felix/bundle", "felix/conf", "felix/bin/felix.jar", "felix/bundle/org.apache.felix.shell.jar", "felix/bundle/org.apache.felix.shell.remote.jar", "felix/bundle/org.apache.felix.shell.tui.jar", "felix/conf/config.properties", "felix/conf/system.properties", "modules/admin-cli.jar", "modules/api-exporter.jar", "modules/asadmin.rb", "modules/asm-all-repackaged.jar", "modules/auto-depends.jar", "modules/branding.jar", "modules/cli-framework.jar", "modules/command_line_parser.rb", "modules/common-util.jar", "modules/config-api.jar", "modules/config.jar", "modules/deployment-admin.jar", "modules/deployment-autodeploy.jar", "modules/deployment-common.jar", "modules/flashlight-agent.jar", "modules/flashlight-framework.jar", "modules/gf-jruby-connector.jar", "modules/glassfish-api.jar", "modules/glassfish.jar", "modules/glassfish.rb", "modules/grizzly-jruby-module.jar", "modules/grizzly-jruby.jar", "modules/grizzly-module.jar", "modules/hk2-core.jar", "modules/hk2.jar", "modules/internal-api.jar", "modules/javax.xml.stream.jar", "modules/kernel.jar", "modules/launcher.jar", "modules/monitoring-core.jar", "modules/osgi-adapter.jar", "modules/pkg-client.jar", "modules/rdoc_usage.rb", "modules/stats77.jar", "modules/stax-api.jar", "modules/tiger-types-osgi.jar", "modules/version.rb", "modules/wstx-asl.jar", "config/asadminenv.conf", "config/asenv.bat", "config/asenv.conf", "config/glassfish.container", "domains/domain1", "domains/domain1/applications", "domains/domain1/config", "domains/domain1/docroot", "domains/domain1/generated", "domains/domain1/logs", "domains/domain1/master-password", "domains/domain1/session-store", "domains/domain1/applications/j2ee-apps", "domains/domain1/applications/j2ee-modules", "domains/domain1/applications/lifecycle-modules", "domains/domain1/applications/mbeans", "domains/domain1/config/admin-keyfile", "domains/domain1/config/cacerts.jks", "domains/domain1/config/default-config", "domains/domain1/config/default-web.xml", "domains/domain1/config/domain-passwords", "domains/domain1/config/domain.xml", "domains/domain1/config/domain.xml_ORIG", "domains/domain1/config/keyfile", "domains/domain1/config/keystore.jks", "domains/domain1/config/logging.properties", "domains/domain1/config/login.conf", "domains/domain1/config/server.policy", "domains/domain1/config/sun-acc.xml", "domains/domain1/config/wss-server-config-1.0.xml", "domains/domain1/config/wss-server-config-2.0.xml", "domains/domain1/config/default-config/docroot", "domains/domain1/config/default-config/lib", "domains/domain1/config/default-config/lib/ext", "domains/domain1/docroot/favicon.gif", "domains/domain1/docroot/index.html", "domains/domain1/generated/ejb", "domains/domain1/generated/jsp", "domains/domain1/generated/xml", "LICENSE.txt", "COPYRIGHT"]
  s.has_rdoc = true
  s.homepage = %q{http://wiki.glassfish.java.net/Wiki.jsp?page=JRuby}
  s.require_paths = ["modules"]
  s.rubyforge_project = %q{glassfishgem}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{GlassFish V3 Application Server for JRuby}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 0.4.0"])
    else
      s.add_dependency(%q<rack>, [">= 0.4.0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 0.4.0"])
  end
end
