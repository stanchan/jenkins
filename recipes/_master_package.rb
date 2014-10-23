#
# Cookbook Name:: jenkins
# Recipe:: _master_package
#
# Author: Guilhem Lettron <guilhem.lettron@youscribe.com>
# Author: Seth Vargo <sethvargo@gmail.com>
#
# Copyright 2013, Youscribe
# Copyright 2014, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node['platform_family']
when 'debian'
  include_recipe 'apt::default'

  apt_repository 'jenkins' do
    uri          'http://pkg.jenkins-ci.org/debian'
    distribution 'binary/'
    key          'https://jenkins-ci.org/debian/jenkins-ci.org.key'
  end

  package 'jenkins' do
    version node['jenkins']['master']['version']
  end

  template '/etc/default/jenkins' do
    source   'jenkins-config-debian.erb'
    mode     00644
    notifies :restart, 'service[jenkins]', :immediately
  end
when 'rhel'
  include_recipe 'yum::default'

  yum_repository 'jenkins-ci' do
    baseurl 'http://pkg.jenkins-ci.org/redhat'
    gpgkey  'https://jenkins-ci.org/redhat/jenkins-ci.org.key'
    not_if { node['jenkins']['internal_repo']['enabled'] }
  end

  file "/etc/yum.repos.d/jenkins.repo" do
    action :delete
    only_if { node['jenkins']['internal_repo']['enabled'] }
  end

  package 'jenkins' do
    version node['jenkins']['master']['version']
  end

  file "/etc/yum.repos.d/jenkins.repo" do
    action :delete
    only_if { node['jenkins']['internal_repo']['enabled'] }
  end

  template '/etc/sysconfig/jenkins' do
    source   'jenkins-config-rhel.erb'
    mode     00644
    notifies :restart, 'service[jenkins]', :immediately
  end
end

template "#{node["jenkins"]["master"]["home"]}/hudson.model.UpdateCenter.xml" do
  source "hudson.model.UpdateCenter.xml.erb"
  owner node["jenkins"]["master"]["user"]
  group node["jenkins"]["master"]["group"]
  mode 00644
  variables(update_url: "#{node["jenkins"]["master"]["mirror"]}/updates/update-center.json")
end

directory "#{node["jenkins"]["master"]["home"]}/updates" do
  owner node["jenkins"]["master"]["user"]
  group node["jenkins"]["master"]["group"]
  mode 00755
end

execute "update jenkins update center" do
  command "wget #{node["jenkins"]["master"]["mirror"]}/updates/update-center.json -qO- | sed '1d;$d'  > #{node["jenkins"]["master"]["home"]}/updates/default.json"
  user node["jenkins"]["master"]["user"]
  group node["jenkins"]["master"]["group"]
  creates "#{node["jenkins"]["master"]["home"]}/updates/default.json"
end

service 'jenkins' do
  supports status: true, restart: true, reload: true
  action  [:enable, :start]
end
