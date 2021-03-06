# looking_for_group_handler.rb
#
# Author::  Kyle Mullins

class LookingForGroupHandler < CommandHandler
  feature :lfg, default_enabled: true,
                description: 'Allows Users to give themselves special roles telling others what games they play, and announce when they want to play.'

  command(:lfg, :looking_for_group)
    .feature(:lfg).min_args(1).pm_enabled(false).usage('lfg <game_name>')
    .description('Notifies registered players that you want to play the given game.')

  command(:lfgregister, :register_for_game)
    .feature(:lfg).min_args(1).pm_enabled(false).usage('regforgame <game_name>')
    .description('Registers you to be notified when people want to play the given game. If you are already registered, unregisters instead.')

  command(:lfggames, :list_lfg_games)
    .feature(:lfg).usage('lfggames').no_args.pm_enabled(false)
    .description('Lists all the games people have registered for.')

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

    return unregister_for_game(user, game_name, role) if user.role?(role)

    user.add_role(role)
    "You have been registered as a player for #{game_name}"
  end

  def list_lfg_games(event)
    lfg_roles = get_game_roles(event.server).map { |role| role.name[0..-5] }

    return 'No one is registered for any games yet!' if lfg_roles.empty?

    "There are people registered for the following games: #{lfg_roles.join(', ')}"
  end

  private

  def unregister_for_game(user, game_name, role)
    user.remove_role(role)
    role.delete if role.members.empty?

    "You have been unregistered as a player for #{game_name}"
  end

  def get_game_roles(server)
    server.roles.select { |role| role.name.end_with?('-lfg') }.uniq
  end

  def get_role_for_game(server, game_name)
    server.roles.find { |role| role.name.downcase == "#{game_name.downcase}-lfg" }
  end

  def create_role_for_game(server, game_name)
    server.create_role(name: "#{game_name}-lfg", mentionable: true,
                       permissions: 0)
  end

  def role_members(server, role)
    server.members.select { |m| m.role? role }
  end
end
