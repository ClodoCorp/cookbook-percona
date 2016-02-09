require 'spec_helper'
set :backend, :exec

%w(percona-xtradb-cluster-common-5.6 percona-xtradb-cluster-56 percona-xtradb-cluster-galera-3).each do |pkg|
  describe package(pkg), if: os[:family] == 'debian' do
    it { should be_installed }
  end
end

describe service('mysql'), if: os[:family] == 'debian' do
  it { should be_enabled }
  it { should be_running }
end

describe process('mysqld') do
  it { should be_running }
end

describe port(3306) do
  it { should be_listening.with('tcp') }
end
