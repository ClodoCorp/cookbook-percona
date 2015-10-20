
# install packages
case node["platform_family"]
when "debian"
  package "percona-xtradb-cluster-#{node['percona']['cluster']['version']}" do
    options "--force-yes -y"
  end
end
include_recipe "percona::access_grants"
include_recipe "percona::configure_server"
