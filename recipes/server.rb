include_recipe "percona::package_repo"

isReinstalled = false

# install packages
case node["platform_family"]
when "debian"
  package "percona-server-server" do
    action :install
    options "--force-yes"
    notifies :stop, "service[mysql]", :immediately
    notifies :run, "bash[cleanup_mysql]", :immediately
    notifies :create, "ruby_block[set_isReinstalled]", :immediately
  end
when "rhel"
  # Need to remove this to avoid conflicts
  package "mysql-libs" do
    action :remove
    not_if "rpm -qa | grep Percona-Server-shared-55"
  end

  # we need mysqladmin
  include_recipe "percona::client"

  package "Percona-Server-server-55" do
    action :install
  end
end

include_recipe "percona::configure_server"

if node["percona"]["server"]["configure"] 
  # access grants
  include_recipe "percona::access_grants"

  include_recipe "percona::replication"
end

ruby_block 'set_isReinstalled' do
  block do
    isReinstalled = true
  end
  action :nothing
end

r = ruby_block 'stop_mysql_after_configure' do
  block do
  end
  notifies :stop, "service[mysql]", :immediately
  action :nothing
end

r.run_action(:create) if isReinstalled
