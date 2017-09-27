# role_ext.rb
#
# Author::  Kyle Mullins

module RoleExt
  def update_data(new_data)
    super
    @mentionable = new_data[:mentionable] unless new_data[:mentionable].nil?
  end
end
