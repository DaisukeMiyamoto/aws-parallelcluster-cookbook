#
# Cookbook Name:: cfncluster
# Recipe:: base_install
#
# Copyright (c) 2015 Amazon Web Services, All Rights Reserved.
case node['platform_family']
when 'rhel'
  include_recipe 'yum'
when 'debian'
  include_recipe 'apt'
end

# Manage SSH via Chef
include_recipe "openssh"

# Disable selinux
selinux_state "SELinux Disabled" do
  action :disabled
  only_if 'which getenforce'
end

# Setup directories
directory '/etc/cfncluster'
directory node['cfncluster']['base_dir']
directory node['cfncluster']['sources_dir']
directory node['cfncluster']['scripts_dir']

## Being explicit about the included recipes and when they should be run
if platform_family?("rhel")
  include_recipe "yum-epel"
end
include_recipe "build-essential"

# Setup Python (require extra work due to setuptools bug)
include_recipe "python"
python_pip 'setuptools' do
  action :upgrade
  version node.default['python']['setuptools_version']
end

# Install AWSCLI
include_recipe "awscli"

# TODO: update nfs receipes to stop, disable nfs services
include_recipe "nfs"
if node['platform_family'] == 'rhel' && node['platform_version'].to_f >= 7.0 && node['platform'] != 'amazon'
  service "rpcbind" do
    action [:start, :enable]
    supports status: true
  end
end
include_recipe "nfs::server"
include_recipe "nfs::server4"

# Put configure-pat.sh onto the host
cookbook_file 'configure-pat.sh' do
  path '/usr/local/sbin/configure-pat.sh'
  user 'root'
  group 'root'
  mode '0744'
end

# Put setup-ephemeral-drives.sh onto the host
cookbook_file 'setup-ephemeral-drives.sh' do
  path '/usr/local/sbin/setup-ephemeral-drives.sh'
  user 'root'
  group 'root'
  mode '0744'
end

include_recipe 'cfncluster::_ec2_udev_rules'

# Install ec2-metadata script
remote_file '/usr/bin/ec2-metadata' do
  source 'http://s3.amazonaws.com/ec2metadata/ec2-metadata'
  user 'root'
  group 'root'
  mode '0755'
end

# Install cfncluster-nodes packages
python_pip "cfncluster-node" do
  version "0.0.6"
end

# Supervisord
python_pip "supervisor" do
  version "3.1.3"
end

# Put supervisord config in place
cookbook_file "supervisord.conf" do
  path "/etc/supervisord.conf"
  owner "root"
  group "root"
  mode "0644"
end

# Put init script in place
cookbook_file "supervisord-init" do
  path "/etc/init.d/supervisord"
  owner "root"
  group "root"
  mode "0755"
end

# Install jq for manipulating json files
cookbook_file "jq-1.4" do
  path "/usr/local/bin/jq"
  owner "root"
  group "root"
  mode "0755"
end

# Install lots of packages
node['cfncluster']['base_packages'].each do |p|
  package p
end

# Install Ganglia
include_recipe "cfncluster::_ganglia_install"
