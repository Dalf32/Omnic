# audit_ext.rb
#
# AUTHOR:: Kyle Mullins

module Omnic
  def self.audit(server, severity, message)
    server = server.is_a?(Discordrb::Server) ? server : Omnic.bot.server(server)

    AuditHandler.new(Omnic.bot, server, nil).audit(severity, message)
  end
end
