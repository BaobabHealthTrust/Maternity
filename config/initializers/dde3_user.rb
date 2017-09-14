if (CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false)
  require 'dde3_service'
  token = DDE3Service.token rescue nil
  if token.blank?
    token = DDE3Service.authenticate_by_admin
    puts "Token  = #{token}"
    DDE3Service.add_user(token) rescue nil
  end
end
