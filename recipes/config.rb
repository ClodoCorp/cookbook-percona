datadir = node['percona']['config']['mysqld']['datadir']

service 'mysql' do
  action :enable
  supports reload: true
end

directory datadir do
  owner  node['percona']['config']['mysqld']['user']
  group  node['percona']['config']['mysqld']['user']
  mode '0755'
  action :create
  recursive true
end

directory "#{datadir}/log_backup" do
  owner  node['percona']['config']['mysqld']['user']
  group  node['percona']['config']['mysqld']['user']
  mode '0755'
  action :create
end

execute 'Database Initial' do
  command "mysql_install_db --keep-my-cnf --defaults-file=\"#{node['percona']['main_config_file']}\""
  action :run
  notifies :start, 'service[mysql]', :immediately
  notifies :run, 'execute[Set root password]', :immediately
  not_if { ::File.exist?("#{datadir}/mysql/user.frm") }
end

execute 'Set root password' do
  command "/usr/bin/mysqladmin -u root -h localhost password \'#{node['percona']['server']['root_password']}\' --password=\'\'"
  action :nothing
end

ruby_block 'Rename logfile' do
  block do
    ::File.rename("#{datadir}/ib_logfile0", "#{datadir}/log_backup/ib_logfile0")
    ::File.rename("#{datadir}/ib_logfile1", "#{datadir}/log_backup/ib_logfile1")
  end
  action :nothing
  only_if { ::File.exist?('/var/lib/mysql/ib_logfile0') }
  not_if do
    node['percona']['config']['mysqld']['innodb_log_block_size'] == ::File.open('/var/lib/mysql/ib_logfile0', 'rb') do |f|
                                                                      f.read[66..67]
                                                                    end.unpack('n')[0]
  end
end

template node['percona']['main_config_file'] do
  source 'my.cnf.erb'
  owner 'root'
  group node['percona']['config']['mysqld']['user']
  mode '0640'
  variables(
    config: node['percona']['config']
  )
  notifies :run, 'ruby_block[Rename logfile]', :immediately
  notifies :start, 'service[mysql]', :immediately
  notifies :reload, 'service[mysql]', :immediately
end

template '/etc/mysql/debian.cnf' do
  source 'debian.cnf.erb'
  variables(
    debian_password: node['percona']['server']['debian_password']
  )
  owner 'root'
  group 'root'
  mode 0640
  only_if { node['platform_family'] == 'debian' }
end

template '/root/.my.cnf' do
  source 'my.cnf.erb'
  owner 'root'
  group 'root'
  mode 0640
  variables(
    config: { 'client' => { 'user' => 'root', 'password' => node['percona']['server']['root_password'] } }
  )
  only_if { node['percona']['server']['access_grants'] }
end

include_recipe 'percona::access_grants' if node['percona']['server']['access_grants']
