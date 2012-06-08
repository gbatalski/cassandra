#
# Cookbook Name::       cassandra
# Description::         Install From Package
# Recipe::              install_from_package
# Author::              Benjamin Black
#
# Copyright 2011, Benjamin Black
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

include_recipe "apt" 

apt_repository "apache-cassandra" do
  uri "http://www.apache.org/dist/cassandra/debian"
  distribution "10x"
  components ["main"]
  action :add
  keyserver "pgp.mit.edu"
  key "F758CE318D77295D"  
end

# According to http://wiki.apache.org/cassandra/DebianPackaging
# 2 keys need to be added.  This extra repo, which is a duplicate of the above,
# is to add the second key
apt_repository "apache-cassandra-extrakey" do
  uri "http://www.apache.org/dist/cassandra/debian"
  distribution "10x"
  components ["main"]
  action :add
  keyserver "pgp.mit.edu"
  key "2B5C1B00"  
end

execute "apt-get update" do
  user "root"
end

package "cassandra" do
  action :install
end

# copied from server.rb

template "#{node[:cassandra][:conf_dir]}/log4j-server.properties" do
  source        "log4j-server.properties.erb"
  owner         "root"
  group         "root"
  mode          "0644"
  variables     :cassandra => node[:cassandra]
  notifies      :restart, "service[cassandra]", :delayed if startable?(node[:cassandra])
end

# have some fraction of the nodes announce as a seed
if ( node[:cassandra][:seed_node] || (node[:facet_index].to_i % 3 == 0) )
  announce(:cassandra, :seed)
end

# Discover the other seeds, assuming they've a) announced and b) converged.
# Might be better to instead do
#    seed_ips = discover_all(:cassandra, :seed).sort_by{|s| s.node.name }.map{|s| s.node.ipaddress }
seed_ips = []
discover_all(:cassandra, :seed).each do |s|
  seed_ips << s.node.ipaddress
end
# stabilize their order.
seed_ips.sort!

# This is racy like a dirty joke at the indy 500, but any proper fix would
# require orchestration. Since a node with facet_index 0 is always a seed,
# spinning that one up first leads to reasonable results in practice.
#
template "#{node[:cassandra][:conf_dir]}/cassandra.yaml" do
  source        "cassandra.yaml.erb"
  owner         "root"
  group         "root"
  mode          "0644"
  variables({
                :cassandra => node[:cassandra],
                :seeds     => seed_ips
    })
  notifies      :restart, "service[cassandra]", :delayed if startable?(node[:cassandra])
end

announce(:cassandra)