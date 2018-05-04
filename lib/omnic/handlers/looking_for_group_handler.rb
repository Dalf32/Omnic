# looking_for_group_handler.rb
#
# Author::  Kyle Mullins

class LookingForGroupHandler < CommandHandler
  feature :looking_for_group, default_enabled: true

  command :lfg, :looking_for_group, feature: :looking_for_group, min_args: 1,
      pm_enabled: false, usage: 'lfg <game_name>',
      description: 'Notifies registered players that you want to play the given game.'

  command :regforgame, :register_for_game, feature: :looking_for_group,
      min_args: 1, pm_enabled: false, usage: 'regforgame <game_name>',
      description: 'Registers you to be notified when people want to play the given game.'

  command :unregforgame, :unregister_for_game, feature: :looking_for_group,
      min_args: 1, pm_enabled: false, usage: 'unregforgame <game_name>',
      description: 'Unregisters you for the given game.'

  command :lfggames, :list_lfg_games, feature: :looking_for_group, usage: 'lfggames',
      max_args: 0, pm_enabled: false, description: 'Lists all the games people have registered for.'

  def looking_for_group(event, *game_name)
    game_name = game_name.join(' ')
    role = get_role_for_game(event.server, game_name)

    return "No one has registered for #{game_name}!" if role.nil?

    "Hey #{role.mention}, #{event.author.display_name} wants to play!"
  end

  def register_for_game(event, *game_name)
    game_name = game_name.join(' ')
    role = get_role_for_game(event.server, game_name) ||
           create_role_for_game(event.server, game_name)
    user = event.author

    return "You are already registered for #{game_name}" if user.role?(role)

    user.add_role(role)
    "You have been registered as a player for #{game_name}"
  end

  def unregister_for_game(event, *game_name)
    game_name = game_name.join(' ')
    role = get_role_for_game(event.server, game_name)
    user = event.author

    return "#{game_name} is not a registered game!" if role.nil?
    return "You are not registered for #{game_name}" unless user.role?(role)

    user.remove_role(role)
    # role.delete if role.members.empty?
    # TODO: Change to the above when Discordrb next releases
    members = role_members(event.server, role) - [user]
    role.delete if members.empty?

    "You have been unregistered as a player for #{game_name}"
  end

  def list_lfg_games(event)
    lfg_roles = get_game_roles(event.server).map { |role| role.name[0..-5] }

    return 'No one is registered for any games yet!' if lfg_roles.empty?

    "There are people registered for the following games: #{lfg_roles.join(', ')}"
  end

  private

  def get_game_roles(server)
    server.roles.select { |role| role.name.end_with?('-lfg') }.uniq
  end

  def get_role_for_game(server, game_name)
    server.roles.find { |role| role.name.downcase == "#{game_name.downcase}-lfg" }
  end

  def create_role_for_game(server, game_name)
    # server.create_role(name: "#{game_name}-lfg", mentionable: true,
    #                    packed_permissions: 0)
    # TODO: Change to the above when Discordrb next releases
    server.create_role.tap do |role|
      role.name = "#{game_name}-lfg"
      role.mentionable = true
      role.packed = 0
    end
  end

  def role_members(server, role)
    server.members.select { |m| m.role? role }
  end
end
