include_recipe "percona::package_repo"

isReinstalled = false


# install packages
case node["platform_family"]
when "debian"
  ruby_block "remove old logfile before install" do
    block do
      notifies :run, resources(:bash => "cleanup_mysql"), :immediately
    end
    not_if "dpkg --get-selections | grep percona-server-server-#{node['percona']['server']['version']}"
    action :run
  end
  package "percona-server-server-#{node["percona"]["server"]["version"]}" do
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
    not_if "rpm -qa | grep Percona-Server-shared-#{node["percona"]["server"]["version"].tr('.','')}"
  end

  # we need mysqladmin
  include_recipe "percona::client"

  package "Percona-Server-server-#{node["percona"]["server"]["version"].tr('.','')}" do
    action :install
  end
end

include_recipe "percona::configure_server"

if node["percona"]["server"]["configure"] 
  # access grants
  ruby_block "start mysql service for configure" do
    block do
      notifies :start, resources(:service => "mysql"), :immediately if isReinstalled
    end
    action :run
  end
  include_recipe "percona::access_grants"

  include_recipe "percona::replication"
end

ruby_block 'set_isReinstalled' do
  block do
    isReinstalled = true
  end
  action :nothing
end

ruby_block "stop mysql by ending install" do
  block do
    notifies :stop, resources(:service => "mysql"), :immediately if isReinstalled
  end
  action :run
end

ruby_block "remove old logfile after install" do
  block do
    notifies :run, resources(:bash => "cleanup_mysql"), :immediately if isReinstalled
  end
  action :run
end
