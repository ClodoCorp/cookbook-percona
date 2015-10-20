
service "mysql" do
    supports :restart => true
    action :disable
end

template percona["main_config_file"] do
  source "my.cnf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :config => node["percona"]["config"]
  )
  notify :restart, "service[mysql]", :delayed
end

template "/etc/mysql/debian.cnf" do
  source "debian.cnf.erb"
  variables(
    :debian_password => node["percona"]["server"]["debian_password"]
  )
  owner "root"
  group "root"
  mode 0640
  notifies :restart, "service[mysql]", :delayed
  only_if { node["platform_family"] == "debian" }
end

include_recipe "percona::access_grants"
