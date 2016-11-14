#
# Cookbook Name:: nginx
# Recipe:: default
#
# Copyright 2008, Engine Yard, Inc.
#
# All rights reserved - Do Not Redistribute
#
recipe = self
stack = node['engineyard']['environment']['stack_name']
should_not_run = /(thin|nginx_passenger|nginx_passenger3|nginx_passenger4|nginx_trinidad)/
mongrel_unicorn = /(nginx_unicorn|nginx_mongrel)/
php_fpm = /nginx_fpm/

Chef::Log.info "NGINX ACTION: #{node[:nginx][:action]}"
nginx_version = node.metadata("nginx_ebuild_version", node[:nginx][:version])
Chef::Log.info "NGINX Version: #{nginx_version}"

# CC-362: msec is available after version 1.2.7
use_msec = (nginx_version.split('.').map(&:to_i) <=> [1,2,7]) >= 0


tlsv12_available  = node.openssl.version =~ /1\.0\.1/

service "nginx" do
  action :nothing
  supports :restart => true, :status => true, :reload => true
end

execute "upgrade_nginx" do
  action :nothing
  user 'root'
  command '/etc/init.d/nginx upgrade'
  only_if %Q{
    [[ -f /var/run/nginx.pid && "$(readlink -m /proc/$(cat /var/run/nginx.pid)/exe)" =~ '/usr/sbin/nginx' ]]
  }
end

ey_cloud_report "nginx" do
  message "processing nginx"
end

enable_package 'www-servers/nginx' do
  version nginx_version
  unmaskfile 'nginx'
end

package "nginx" do
  version nginx_version
end

directory "/var/log/engineyard/nginx" do
  owner 'root'
  group 'root'
  mode 0755
end

# Precreate Nginx Work Directories with Deploy permissions for Passenger
directory "/var/tmp/nginx" do
  owner 'root'
  group 'root'
  mode 0755
end

directory "/var/tmp/nginx/client" do
  owner node.ssh_username
  group node.ssh_username
  mode 0755
  recursive true
end

directory "/var/tmp/nginx/fastcgi" do
  owner node.ssh_username
  group 'root'
  mode 0700
end

directory "/var/tmp/nginx/proxy" do
  owner node.ssh_username
  group 'root'
  mode 0700
  recursive true
end

directory "/var/tmp/nginx/scgi" do
  owner node.ssh_username
  group 'root'
  mode 0700
end

directory "/var/tmp/nginx/uwscgi" do
  owner node.ssh_username
  group 'root'
  mode 0700
end


%w{/data/nginx/servers /data/nginx/common}.each do |dir|
  directory dir do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
    recursive true
  end
end

unless File.symlink?("/var/log/nginx")
  directory "/var/log/nginx" do
    action :delete
    recursive true
  end
end

execute "remove /etc/nginx" do
  command "rm -rf /etc/nginx"
  action :run

  not_if %Q{[[ -L /etc/nginx ]] && [[ "$(readlink /etc/nginx)" = "/data/nginx" ]]}
end

link "/etc/nginx" do
  to "/data/nginx"

  not_if %Q{[[ -L /etc/nginx ]] && [[ "$(readlink /etc/nginx)" = "/data/nginx" ]]}
end

directory "/var/tmp/nginx/client" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0775
  recursive true
end

link "/var/log/nginx" do
  to "/var/log/engineyard/nginx"
end

remote_file "/etc/init.d/nginx" do
  owner "root"
  group "root"
  mode 0755
  source "nginx"
end

remote_file "/data/nginx/mime.types" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0755
  source "mime.types"
end

remote_file "/data/nginx/koi-utf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0755
  source "koi-utf"
end

remote_file "/data/nginx/koi-win" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0755
  source "koi-win"
end

# This should become a service resource, once we have it for gentoo
runlevel 'nginx' do
  action :add
end

logrotate "nginx" do
  files "/var/log/engineyard/nginx/*log"
  copy_then_truncate true
  restart_command <<-SH
[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`
  SH
end

managed_template "/etc/conf.d/nginx" do
  source "conf.d/nginx.erb"
  variables({
    :nofile => 16384
  })
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

behind_proxy = !(node.solo?)

file "/data/nginx/stack.conf" do
  action :create_if_missing
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
end

managed_template "/data/nginx/nginx.conf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
  source "nginx-plusplus.conf.erb"
  variables(
    lazy {
      {
        :user => node[:owner_name],
        :pool_size => recipe.get_pool_size,
        :behind_proxy => behind_proxy
      }
    }
  )
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

managed_template "/data/nginx/nginx_version.conf" do
  owner node.ssh_username
  group node.ssh_username
  mode 0644
  source "nginx_version.conf.erb"
  variables(
    :version => nginx_version
  )
  notifies :run, resources(:execute => "upgrade_nginx"), :delayed
end

file "/data/nginx/http-custom.conf" do
  action :create_if_missing
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
end

directory "/data/nginx/ssl" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0775
end

managed_template "/data/nginx/common/proxy.conf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
  source "common.proxy.conf.erb"
  variables({
    :use_msec => use_msec
  })
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

managed_template "/data/nginx/common/servers.conf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
  source "common.servers.conf.erb"
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

managed_template "/data/nginx/common/fcgi.conf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
  source "common.fcgi.conf.erb"
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

file "/data/nginx/servers/default.conf" do
  owner node[:owner_name]
  group node[:owner_name]
  mode 0644
  notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
end

(node[:removed_applications]||[]).each do |app|
  execute "remove-old-vhosts-for-#{app}" do
    command "rm -rf /data/nginx/servers/#{app}*"
    notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
  end
end

node.apps.each_with_index do |app, index|

  dhparam_available = app.metadata('dh_key',nil)

  if dhparam_available
    managed_template "/data/nginx/ssl/dhparam.#{app.name}.pem" do
       owner node[:owner_name]
       group node[:owner_name]
       mode 0600
       source "dhparam.erb"
       variables ({
         :dhparam => app.metadata('dh_key')
       })
       notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
    end
  end

  directory "/data/nginx/servers/#{app.name}" do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0775
  end

  directory "/data/nginx/servers/#{app.name}/ssl" do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0775
  end

  file "/data/nginx/servers/#{app.name}/custom.conf" do
    action :create_if_missing
    owner node.ssh_username
    group node.ssh_username
    mode 0644
  end

  managed_template "/data/nginx/servers/#{app.name}.users" do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    source "users.erb"
    variables({
      :application => app
    })
    notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
  end

  mongrel_service = find_app_service(app, "mongrel")
  fcgi_service = find_app_service(app, "fcgi")
  mongrel_base_port =  (mongrel_service[:mongrel_base_port].to_i + (index * 200))
  unicorn = app.recipes.include?('unicorn')
  php = app.recipes.include?('php')

#
# HAX for SD-4650
# Remove it when awsm stops using dnapi to generate the dna and allows configure ports

  nginx_http_port = (meta = node.apps.detect {|a| a.metadata?(:nginx_http_port) } and meta.metadata?(:nginx_http_port)) || (node.solo? ? 80 : 81)
  nginx_https_port = (meta = node.apps.detect {|a| a.metadata?(:nginx_https_port) } and meta.metadata?(:nginx_https_port)) || (node.solo? ? 443 : 444)
  php_webroot = File.join('/',*(app.metadata(:php_webroot, "").split('/')))

  managed_template "/etc/nginx/listen_http.port" do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    source "listen-http.erb"
    variables({
        :http_bind_port => nginx_http_port,
    })
    notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
  end
  managed_template "/etc/nginx/listen_https.port" do
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    source "listen-https.erb"
    variables({
        :https_bind_port => nginx_https_port,
    })
    notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
  end

  # CC-260: Chef 10 could not handle two managed template blocks using the same
  # name with different ifs, so since this can be determined during compile
  # time values, we can use just a regular if statement

  if stack.match(mongrel_unicorn)
    managed_template "/data/nginx/servers/#{app.name}.conf" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "server.conf.erb"
      variables(
        lazy {
          {
            :application => app,
            :unicorn   => unicorn,
            :app_name   => app.name,
            :app_type => app.app_type,
            :mongrel_base_port => mongrel_base_port,
            :mongrel_instance_count => [1, recipe.get_pool_size / node[:applications].size].max,
            :http_bind_port => nginx_http_port,
            :https_bind_port => nginx_https_port,
            :server_names => app.vhosts.first.domain_name.empty? ? [] : [app.vhosts.first.domain_name],
            :fcgi_pass_port => fcgi_service[:fcgi_pass_port],
            :fcgi_mem_limit => fcgi_service[:fcgi_mem_limit],
            :fcgi_instance_count => fcgi_service[:fcgi_instance_count],
            :use_msec => use_msec
          }
        }
      )
      notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
    end
  end

  if stack.match(php_fpm)

    managed_template "/data/nginx/servers/#{app.name}.conf" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "fpm-server.conf.erb"
      variables({
        :application => app,
        :app_name => app.name,
        :http_bind_port => nginx_http_port,
        :https_bind_port => nginx_https_port,
        :server_names => app.vhosts.first.domain_name.empty? ? [] : [app.vhosts.first.domain_name],
        :webroot => php_webroot,
        :env_name => node[:environment][:name]
      })
      notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
    end

    managed_template "/etc/nginx/servers/#{app.name}/additional_server_blocks.customer" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      variables({
        :app_name   => app.name,
        :server_name => (app.vhosts.first.domain_name.empty? or app.vhosts.first.domain_name == "_") ? "www.domain.com" : app.vhosts.first.domain_name,
      })
      source "additional_server_blocks.customer.erb"
      not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_server_blocks.customer") }
    end
    managed_template "/etc/nginx/servers/#{app.name}/additional_location_blocks.customer" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "additional_location_blocks.customer.erb"
      not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_location_blocks.customer") }
    end
  end

  # if there is an ssl vhost
  if app.https?

    # Can be removed when no one is on nodejs-v2 stack
    file "/data/nginx/servers/#{app.name}.custom.ssl.conf" do
      action :delete
    end

    file "/data/nginx/servers/#{app.name}/custom.ssl.conf" do
      action :create_if_missing
      owner node.ssh_username
      group node.ssh_username
      mode 0644
    end

    template "/data/nginx/ssl/#{app.name}.key" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "sslkey.erb"
      backup 0
      variables(
        :key => app[:vhosts][1][:key]
      )
      notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
    end

    template "/data/nginx/ssl/#{app.name}.crt" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "sslcrt.erb"
      backup 0
      variables(
        :crt => app[:vhosts][1][:crt],
        :chain => app[:vhosts][1][:chain]
      )
      notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
    end

    # Uses Nginx include chain to reduce the dependancy on keepfiles
    # Main(override)->Customer->Default

      # Add certificate chain
      template "/data/nginx/servers/#{app.name}/default.ssl_cert" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "default_ssl_cert.erb"
        backup 3
        variables(
          :app_name   => app.name
        )
        notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
      end

      # Add Cipher chain
      template "/data/nginx/servers/#{app.name}/default.ssl_cipher" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "default_ssl_cipher.erb"
        backup 3
        variables(
          :app_name => app.name,
          :tlsv12_available => tlsv12_available,
          :dhparam_available => dhparam_available
        )
        notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
      end

    # Chain files are create if missing and do not reload Nginx
    # Add certificate chain
    template "/data/nginx/servers/#{app.name}/customer.ssl_cert" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "customer_ssl_cert.erb"
      action :create_if_missing
      variables(
        :app_name   => app.name,
        :tlsv12_available => tlsv12_available,
        :dhparam_available => dhparam_available
      )
    end

    # Add Cipher chain
    template "/data/nginx/servers/#{app.name}/customer.ssl_cipher" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "customer_ssl_cipher.erb"
      action :create_if_missing
      variables(
        :app_name => app.name
      )
    end
    # Add certificate chain
    template "/data/nginx/servers/#{app.name}/ssl_cert" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "main_ssl_cert.erb"
      action :create_if_missing
      variables(
        :app_name   => app.name
      )
    end

    # Add Cipher chain
    template "/data/nginx/servers/#{app.name}/ssl_cipher" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "main_ssl_cipher.erb"
      action :create_if_missing
      variables(
        :app_name => app.name
      )
    end
    
    # PHP SSL template
    if stack.match(php_fpm)
      managed_template "/data/nginx/servers/#{app.name}.ssl.conf" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "fpm-ssl.conf.erb"
        variables({
          :application => app,
          :app_name   => app.name,
          :http_bind_port => nginx_http_port,
          :https_bind_port => nginx_https_port,
          :server_names =>  app[:vhosts][1][:name].empty? ? [] : [app[:vhosts][1][:name]],
          :webroot => php_webroot,
          :env_name => node[:environment][:name]
        })
        notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
      end

      managed_template "/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        variables({
          :app_name   => app.name,
          :server_name => (app.vhosts.first.domain_name.empty? or app.vhosts.first.domain_name == "_") ? "www.domain.com" : app.vhosts.first.domain_name,
        })
        source "additional_server_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer") }
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "additional_location_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer") }
      end
    end

    template "/data/nginx/ssl/#{app.name}.pem" do
      owner node[:owner_name]
      group node[:owner_name]
      mode 0644
      source "sslpem.erb"
      backup 0
      variables(
        :crt => app[:vhosts][1][:crt],
        :chain => app[:vhosts][1][:chain],
        :key => app[:vhosts][1][:key]
      )
    end

    # CC-260: Same issue as previous; using compile-time if rather than run-time only_if directive
    if stack.match(mongrel_unicorn)
      managed_template "/data/nginx/servers/#{app.name}.ssl.conf" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "ssl.conf.erb"
        variables(
          lazy {
            {
              :unicorn   => unicorn,
              :application => app,
              :app_name   => app.name,
              :app_type => app.app_type,
              :mongrel_base_port => mongrel_base_port,
              :mongrel_instance_count => [1, recipe.get_pool_size / node[:applications].size].max,
              :http_bind_port => nginx_http_port,
              :https_bind_port => nginx_https_port,
              :server_names =>  app[:vhosts][1][:name].empty? ? [] : [app[:vhosts][1][:name]],
              :fcgi_pass_port => fcgi_service[:fcgi_pass_port],
              :fcgi_mem_limit => fcgi_service[:fcgi_mem_limit],
              :fcgi_instance_count => fcgi_service[:fcgi_instance_count],
              :use_msec => use_msec
            }
          }
        )
        notifies node[:nginx][:action], resources(:service => "nginx"), :delayed
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        variables({
          :app_name   => app.name,
          :server_name => (app.vhosts.first.domain_name.empty? or app.vhosts.first.domain_name == "_") ? "www.domain.com" : app.vhosts.first.domain_name,
        })
        source "additional_server_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer") }
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "additional_location_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer") }
      end
    end
  else
    execute "ensure-no-old-ssl-vhosts-for-#{app.name}" do
      command %Q{
        rm -f /data/nginx/servers/#{app.name}.ssl.conf;true
      }
    end
  end
end

service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action [ :start, :enable ]
end
