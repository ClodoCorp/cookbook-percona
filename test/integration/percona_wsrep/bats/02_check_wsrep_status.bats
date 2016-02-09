@test "check wsrep status" {
    mysql -h localhost -u root -p'rootpassword' <<< "select @@wsrep_on" | tail -1 | grep 0
    mysql -h localhost -u root -p'rootpassword' <<< "select @@wsrep_sst_method" | tail -1 | grep 'xtrabackup-v2'
}
