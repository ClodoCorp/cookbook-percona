datadir = node["percona"]["config"]["mysqld"]["datadir"]

service "mysql" do
    supports :restart => true
    action :disable
end

directory "#{datadir}/log_backup" do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  recursive :true
end

ruby_block "Rename logfile" do
  block do
    ::File.rename("#{datadir}/ib_logfile0","#{datadir}/log_backup/ib_logfile0")
    ::File.rename("#{datadir}/ib_logfile1","#{datadir}/log_backup/ib_logfile1")
  end
  action :nothing
  not_if { node["percona"]["config"]["mysqld"]["innodb_log_block_size"] == ::File.open("/var/lib/mysql/ib_logfile0", "rb") { |f| f.read[66..67] }.unpack('n')[0] }
end

template node["percona"]["main_config_file"] do
  source "my.cnf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :config => node["percona"]["config"]
  )
  notifies :stop, "service[mysql]", :immediately
  notifies :run, "ruby_block[Rename logfile]", :immediately
  notifies :start, "service[mysql]", :immediately
end

template "/etc/mysql/debian.cnf" do
  source "debian.cnf.erb"
  variables(
    :debian_password => node["percona"]["server"]["debian_password"]
  )
  owner "root"
  group "root"
  mode 0640
  only_if { node["platform_family"] == "debian" }
end

include_recipe "percona::access_grants"
