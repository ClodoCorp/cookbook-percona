# set the server root password
# (it starts out blank after package installation)
execute %(mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('#{node['percona']['server']['root_password']}');") do
  returns [0, 1] # in case password is already set
end

# macro to execute mysql statements via CLI
mysql = %(mysql -p'#{node['percona']['server']['root_password']}' -e)

# delete non-local root users
execute %(#{mysql} "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');")

# execute grants
# debian-sys-maint user for administration
[['SELECT', 'mysql.user'], ['SHUTDOWN', '*.*']].each do |priv, loc|
  execute %(#{mysql} "GRANT #{priv} ON #{loc} TO '#{node['percona']['server']['debian_username']}'@localhost IDENTIFIED BY '#{node['percona']['server']['debian_password']}';") do
    only_if { node['platform_family'] == 'debian' }
  end
end

if node['percona']['backup']['configure']
  # Grant permissions for the XtraBackup user
  # Ensure the user exists, then revoke all grants, then re-grant specific permissions
  execute %(#{mysql} "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '#{node['percona']['backup']['username']}'@'localhost' IDENTIFIED BY '#{node['percona']['backup']['password']}';")
  execute %(#{mysql} "REVOKE ALL PRIVILEGES, GRANT OPTION FROM '#{node['percona']['backup']['username']}'@'localhost';")
  execute %(#{mysql} "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '#{node['percona']['backup']['username']}'@'localhost' IDENTIFIED BY '#{node['percona']['backup']['password']}';")
end

# create empty databases in preparation for data import and user grants
if node['percona']['server'].key? 'databases'
  node['percona']['server']['databases'].each do |database, h|
    sql =  "CREATE DATABASE IF NOT EXISTS \\\`#{database}\\\`"
    sql += "  DEFAULT CHARACTER SET = #{h['charset']}" if h['charset']
    sql += "  DEFAULT COLLATE = #{h['collate']};" if h['collate']
    execute %(#{mysql} "#{sql}")
  end
end

# create users and grant privileges
if node['percona']['server'].key? 'users'
  # fetch user passwords out of encrypted data bag
  # passwords = Chef::EncryptedDataBagItem.load('passwords', 'mysql')
  passwords = {}

  node['percona']['server']['users'].each do |user, h|
    user, host = user.split('@').map { |s| s.delete("'") } if user =~ /@/
    host = h['host'] || '%'
    password = h['password'] || passwords[user]
    next unless password
    # mysql GRANT will create the user if it doesn't exist
    # usage is actually a no-op
    execute %(#{mysql} "GRANT USAGE ON *.* TO '#{user}'@'#{host}';")
    execute %(#{mysql} "SET PASSWORD FOR '#{user}'@'#{host}' = PASSWORD('#{password}');")
    h['grants'].each do |grant|
      execute %(#{mysql} "GRANT #{grant} TO '#{user}'@'#{host}';")
    end
  end

  # flush privileges
  execute %(#{mysql} "FLUSH PRIVILEGES;")
end
