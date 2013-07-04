# macro to execute mysql statements via CLI
mysql = %Q(mysql -p"#{node['percona']['server']['root_password']}" -e)

if node["percona"]["server"]["replication"]["host"] != "" || node["percona"]["server"]["role"] == "master"
  if node["percona"]["server"]["role"] == "master"
    # Grant replication for a slave user.
    execute <<-SQL
    #{mysql} "
    GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.*
      TO '#{node["percona"]["server"]["replication"]["username"]}'@'%'
      IDENTIFIED BY '#{node["percona"]["server"]["replication_password"]}';"
    SQL

    execute <<-SQL
    #{mysql} "
    GRANT REPLICATION CLIENT, REPLICATION SLAVE, SUPER, PROCESS, RELOAD ON *.*
      TO '#{node["percona"]["server"]["replication"]["username"]}'@'%'
      IDENTIFIED BY '#{node["percona"]["server"]["replication_password"]}';"
    SQL

    execute <<-SQL
    #{mysql} "
    GRANT SELECT ON mysql.user
      TO '#{node["percona"]["server"]["replication"]["testuser"]}'@'localhost'
      IDENTIFIED BY '#{node["percona"]["server"]["test_password"]}';"
    SQL
    
    execute %Q(#{mysql} "FLUSH PRIVILEGES;")

    # Ensure this is not running as a slave, useful for master promotion
    execute %Q(#{mysql} "STOP SLAVE;")
    execute %Q(#{mysql} "RESET SLAVE;")
  end

  if node["percona"]["server"]["role"] == "slave"

    # Set replication parameters
    execute "Update Master settings" do
      command <<-SQL
        #{mysql} "
        CHANGE MASTER TO
        MASTER_HOST='#{node["percona"]["server"]["replication"]["host"]}',
        MASTER_PORT=#{node["percona"]["server"]["replication"]["port"]},
        MASTER_USER='#{node["percona"]["server"]["replication"]["username"]}';"
      SQL
      returns [0, 1] # FIXME: Must check and stop slave before changing!
    end

    execute "Update Master password" do
      command <<-SQL
      #{mysql} "
      CHANGE MASTER TO
        MASTER_PASSWORD='#{node["percona"]["server"]["replication_password"]}';"
      SQL
      returns [0, 1] # in case password is already set
    end

    # Start slave automatically
    execute %Q(#{mysql} "START SLAVE;")
  end
end
