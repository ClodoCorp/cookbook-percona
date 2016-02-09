percona = node['percona']
server  = percona['server']
conf    = percona['conf']
mysqld  = (conf && conf['mysqld']) || {}

if server['bind_to']
  ipaddr = Percona::ConfigHelper.bind_to(node, server['bind_to'])
  if ipaddr && server['bind_address'] != ipaddr
    node.override['percona']['server']['bind_address'] = ipaddr
    node.save
  end

  log "Can't find ip address for #{server['bind_to']}" do
    level :warn
    only_if { ipaddr.nil? }
  end
end

datadir = mysqld['datadir'] || server['datadir']
tmpdir  = mysqld['tmpdir'] || server['tmpdir']
user    = mysqld['username'] || server['username']

# define the service
service 'mysql' do
  supports restart: true
  action server['enable'] ? :enable : :disable
end

# clean up mysql after initial run
bash 'cleanup_mysql' do
  code <<-EOC
     mkdir -p #{datadir}/backup
     mv -bf #{datadir}/ib_logfile* #{datadir}/backup/
     exit 0
  EOC
  action :nothing
end

# this is where we dump sql templates for replication, etc.
directory '/etc/mysql' do
  owner 'root'
  group 'root'
  mode 0755
end

# This dir should exist
directory '/etc/mysql/conf.d' do
  owner 'root'
  group 'root'
  mode 0755
end

# setup the data directory
directory datadir do
  owner user
  group user
  recursive true
  action :create
end

# setup the tmp directory
directory tmpdir do
  mode 0777
  recursive true
  action :create
end

# setup the main server config file
template percona['main_config_file'] do
  source "my.cnf.#{conf ? 'custom' : server['role']}.erb"
  owner 'root'
  group 'root'
  mode 0744
  notifies :restart, 'service[mysql]', :immediately if node['percona']['auto_restart']
end

# setup the debian system user config
template '/etc/mysql/debian.cnf' do
  source 'debian.cnf.erb'
  variables(debian_password: node['percona']['server']['debian_password'])
  owner 'root'
  group 'root'
  mode 0640
  notifies :restart, 'service[mysql]', :immediately if node['percona']['auto_restart']

  only_if { node['platform_family'] == 'debian' }
end

# install db to the data directory
execute 'setup mysql datadir' do
  command "mysql_install_db --user=#{user} --datadir=#{datadir}"
  notifies :start, 'service[mysql]', :immediately
  notifies :create, 'ruby_block[set_is_reinstalled]', :immediately
  not_if "test -f #{datadir}/mysql/user.frm"
end
