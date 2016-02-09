@test "check user root" {
    mysql -h localhost -u root -p'rootpassword' <<< "exit"
}
