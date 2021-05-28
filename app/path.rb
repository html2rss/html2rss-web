# frozen_string_literal: true

class Path
  attr_reader :folder_name

  def initialize(name_with_ext, folder_name = nil)
    @name_with_ext = name_with_ext
    @folder_name = folder_name
  end

  ##
  # @return [String]
  def name
    [folder_name, config_name].compact.join('/')
  end

  ##
  # @return [String]
  def config_name
    parts[...-1].join('.')
  end

  ##
  # @return [String]
  def extension
    parts.last
  end

  private

  def parts
    @parts ||= @name_with_ext.split('.')
  end
end
