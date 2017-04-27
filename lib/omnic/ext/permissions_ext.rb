# permissions_ext.rb
#
# Author::	Kyle Mullins

module PermissionsExt
  def from_symbols(*flag_symbols)
    Discordrb::Permissions.new(bits_for(*flag_symbols))
  end

  def bits_for(*flag_symbols)
    flag_symbols.inject(0) { |mask, flag_symbol| mask | get_bits(flag_symbol) }
  end

  private

  def get_bits(flag_symbol)
    1 << (Discordrb::Permissions::Flags.key(flag_symbol) || -1)
  end
end
