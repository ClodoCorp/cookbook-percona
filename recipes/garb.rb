service "garbd" do
  supports :restart => true
  action :nothing
  ignore_failure true
end

template node['percona']['garb']['conf_file'] do
  source "garb.conf.erb"
  owner 'root'
  group 'root'
  mode '0640'
  notifies :restart, "service[garbd]", :delayed
end


