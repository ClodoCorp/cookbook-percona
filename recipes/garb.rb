case node["platform_family"]
when "debian"
  package "percona-xtradb-cluster-garbd-#{node['percona']['garb']['version']}" do
    options "--force-yes -y"
  end
end

service "garbd" do
  supports :restart => true
  action :enable
end

template node['percona']['garb']['conf_file'] do
  source "garb.conf.erb"
  owner 'root'
  group 'root'
  mode '0640'
  notifies :restart, "service[garbd]", :delayed
end


