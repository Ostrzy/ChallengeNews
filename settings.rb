class Settings
  attr_reader :hipchat

  def initialize
    settings = YAML::load(File.open(Files::SETTINGS))
    @mapping = settings["mapping"]
    @hipchat = settings["hipchat"]
  end

  def map name
    @mapping[name]
  end
end

