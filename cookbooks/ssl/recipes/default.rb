# USAGE:
#   1. Upload the SSL certificate in the EngineYard interface: https://cloud.engineyard.com/ssl_certificates
#   2. Assign SSL Cert to each host from the dashboard panel
#   3. After you've assigned each at least once
#   3. Download the files from /data/nginx/ssl/* into ../files/default/
#   4. Make sure the application is set to the hostname you want to work with SSL
#

if ['app_master', 'app', 'util', 'solo'].include?(node[:instance_role])
  node[:applications].each do |app_name, data|
    cookbook_file "/data/nginx/ssl/#{app_name}.crt" do
      mode '0644'
      source "#{app_name}.crt"
      only_if { run_context.has_cookbook_file_in_cookbook?(cookbook_name, "#{app_name}.crt") }
    end

    cookbook_file "/data/nginx/ssl/#{app_name}.key" do
      mode '0644'
      source "#{app_name}.key"
      only_if { run_context.has_cookbook_file_in_cookbook?(cookbook_name, "#{app_name}.key") }
    end

    cookbook_file "/data/nginx/ssl/#{app_name}.pem" do
      mode '0644'
      source "#{app_name}.pem"
      only_if { run_context.has_cookbook_file_in_cookbook?(cookbook_name, "#{app_name}.pem") }
    end

    # This doesn't do anything!! This was left incomplete because it was deemed a waste of time
  end
end
