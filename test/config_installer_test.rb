require File.expand_path('../test_helper', __FILE__)
require 'config_installer'
require 'yaml'

describe "ConfigInstaller" do
  before do
    @tmp = File.expand_path('../tmp').bypass_safe_level_1
    FileUtils.mkdir_p @tmp
    @vhost_file = File.join(@tmp, 'test.vhost.conf')
    
    @data = {
      'new_app' => true,
      'config_path' => @vhost_file,
      'host' => 'het-manfreds-blog.local',
      'path' => '/User/het-manfred/rails code/blog',
      'environment' => 'production',
      'allow_mod_rewrite' => true,
      'base_uri' => '',
      'vhostname' => 'het-manfreds-wiki.local:443',
      'user_defined_data' => "  <something_else \"/some/path\">\n    foo bar\n  </something_else>"
    }
    
    @installer = ConfigInstaller.new([@data].to_yaml)
  end
  
  after do
    FileUtils.rm_rf @tmp
  end
  
  it "should initialize" do
    @installer.data.should == [{
      'new_app' => true,
      'config_path' => @vhost_file,
      'host' => 'het-manfreds-blog.local',
      'path' => '/User/het-manfred/rails code/blog',
      'environment' => 'production',
      'allow_mod_rewrite' => true,
      'base_uri' => '',
      'vhostname' => 'het-manfreds-wiki.local:443',
      'user_defined_data' => "  <something_else \"/some/path\">\n    foo bar\n  </something_else>"
    }]
  end
  
  it "should be able to add a new entry to the hosts" do
    @installer.expects(:system).with("/usr/bin/dscl localhost -create /Local/Default/Hosts/het-manfreds-blog.local IPAddress 127.0.0.1")
    @installer.add_to_hosts(0)
  end
  
  it "should check if the vhost directory exists, if not add it and also the create the passenger-vhosts.conf" do
    dir = "/private/etc/apache2/passenger_pane_vhosts"
    File.expects(:exist?).with(dir).returns(false)
    FileUtils.expects(:mkdir_p).with(dir)
    
    conf = "/private/etc/apache2/other/passenger_pane.conf"
    File.expects(:exist?).with(conf).returns(false)
    File.expects(:open).with(conf, 'w')
    
    @installer.verify_vhost_conf
  end
  
  it "should create a new vhost conf file and include permissions data if it's a new app" do
    @installer.create_vhost_conf(0)
    
    File.read(@vhost_file.bypass_safe_level_1).should == %{
<VirtualHost het-manfreds-wiki.local:443>
  ServerName het-manfreds-blog.local
  DocumentRoot "/User/het-manfred/rails code/blog/public"
  RailsEnv production
  RailsAllowModRewrite on
  <directory "/User/het-manfred/rails code/blog/public">
    Order allow,deny
    Allow from all
  </directory>
  <something_else "/some/path">
    foo bar
  </something_else>
</VirtualHost>
}.sub(/^\n/, '')
  end
  
  it "should not add the permissions part if it's not a new app because we treat the directory directive as user defined data" do
    @installer.instance_variable_get(:@data)[0]['new_app'] = false
    @installer.create_vhost_conf(0)
    
    File.read(@vhost_file.bypass_safe_level_1).should == %{
<VirtualHost het-manfreds-wiki.local:443>
  ServerName het-manfreds-blog.local
  DocumentRoot "/User/het-manfred/rails code/blog/public"
  RailsEnv production
  RailsAllowModRewrite on
  <something_else "/some/path">
    foo bar
  </something_else>
</VirtualHost>
}.sub(/^\n/, '')
  end
  
  it "should set the RailsBaseURI if there is one" do
    app_data = @installer.instance_variable_get(:@data)[0]
    app_data['new_app'] = false
    app_data['base_uri'] = '/rails/blog'
    app_data['vhostname'] = '*:80'
    app_data['user_defined_data'] = ''
    @installer.create_vhost_conf(0)
    
    File.read(@vhost_file.bypass_safe_level_1).should == %{
<VirtualHost *:80>
  ServerName het-manfreds-blog.local
  DocumentRoot "/User/het-manfred/rails code/blog/public"
  RailsEnv production
  RailsAllowModRewrite on
  RailsBaseURI /rails/blog
</VirtualHost>
}.sub(/^\n/, '')
  end
  
  it "should restart Apache" do
    @installer.expects(:system).with("/bin/launchctl stop org.apache.httpd")
    @installer.restart_apache!
  end
  
  it "should be able to take a serialized array of hashes and do all the work necessary in one go" do
    installer = ConfigInstaller.any_instance
    
    installer.expects(:verify_vhost_conf)
    
    installer.expects(:add_to_hosts).with(0)
    installer.expects(:add_to_hosts).with(1)
    
    installer.expects(:create_vhost_conf).with(0)
    installer.expects(:create_vhost_conf).with(1)
    
    installer.expects(:restart_apache!)
    
    ConfigInstaller.new([{}, {}].to_yaml, 'extra command').install!
  end
end