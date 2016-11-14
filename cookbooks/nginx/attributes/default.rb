action = metadata(:nginx_action,:restart)
using_openssl_101 = (metadata('openssl_ebuild_version','1.0.1') =~ /1\.0\.1/)
if node[:environment][:stack] == 'nginx_passenger3'
  nginx :version => (using_openssl_101 ? '1.2.9-r6' : '1.2.9-r5'), :passenger_gem => "3.0.21", :action => action
else
  nginx :version => (using_openssl_101 ? '1.6.2-r8' : '1.6.2-r6'), :passenger_gem => "4.0.57", :action => action
end

Chef::Log.info("Version: #{nginx[:version]}, Passenger Gem:#{nginx[:passenger_gem]}\n")
