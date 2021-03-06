if ['app_master', 'app', 'util', 'solo'].include?(node[:instance_role])
  node[:applications].each do |app, data|
    template "/data/#{app}/shared/config/secrets.yml"do
      source 'secrets.yml.erb'
      owner node[:owner_name]
      group node[:owner_name]
      mode 0655
      backup 0
      # Pass a hash of variables to the method below and they will be available as local variables in the template.
      # For API keys this is usually completely unnecessary
      variables app: app
    end

    link "/data/#{app}/current/config/secrets.yml" do
      to "/data/#{app}/shared/config/secrets.yml"
    end
  end
end
