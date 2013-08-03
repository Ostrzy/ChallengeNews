# encoding: utf-8
require 'yaml'
require 'date'
require 'uri'

#consts
DEADLINE  = 36000 # 10:00
RESET     = 39600 # 11:00
MULTIPLIER= 2

PREDICTIONS = 'predictions.yml'
DELAYS      = 'delays.yml'
RESETS      = 'resets.yml'
METADATA    = 'metadata.yml'

$today   = Date.today
$nextday = $today + ($today.wday == 5 ? 3 : 1)
$prevday = $today - ($today.wday == 1 ? 3 : 1)

#Process all shit
YAML::load(File.open(METADATA)).tap do |meta|
  if meta[$today]
    puts "Script has already been run today"
    exit 1
  end
  @mapping    = meta["mapping"]
  @remaining  = meta[$prevday]["remaining"] - ($today - $prevday).to_i
  @hipchat    = meta["hipchat"]
end
@delays = YAML::load(File.open(DELAYS))[$today] || {}

# Find if someone resetted timer today
@resetters = YAML::load(File.open(RESETS))[$today] || []
@delays.each do |person, delay|
  @resetters << person if delay > RESET
end
@resetters.uniq!
@remaining = 30 unless @resetters.empty?

#Calculate predictions
@predictions = @delays.keys.inject({}) do |memo, person|
  memo.tap do |m|
    prediction = $today.to_time + DEADLINE -
      MULTIPLIER * ([@delays[person], RESET].min - DEADLINE)
    m[person] = prediction
  end
end

# Method to add content with next day
class Writer
  def initialize file, date = $nextday
    @f    = file
    @date = date
  end

  def new_day
    @f.write "\n"
    @f.write "#{@date}:\n"
  end

  def write_row line
    @f.write "  #{line}\n"
  end
end

def write_new_day file, date = $nextday, &block
  File.open(file, 'a+') do |f|
    writer = Writer.new(f, date)
    writer.new_day
    writer.instance_exec @predictions, @remaining, &block
  end
end

# Add predictions for next day to predictions.yml
write_new_day(PREDICTIONS) do |predictions|
  predictions.each do |person, prediction|
    write_row "#{person}: #{prediction.strftime("%k:%M")}"
  end
end

# Add potential resets to resets.yml
write_new_day(RESETS) do |predictions|
  predictions.each do |person, _|
    write_row "- #{person}"
  end
end

# Write day specific metadata
write_new_day(METADATA, $today) do |_, remaining|
  write_row "remaining: #{remaining}"
end

# Construct message for HipChat
message = "30 day challenge - #{$today}\n"
unless @resetters.empty?
  message += "@all Wszem i wobec ogłaszam reset!\n"
  message += "Podziękowania należą się #{@resetters.map{ |p| "@#{@mapping[p]}" }.join(', ')}\n"
end
message += "Pozostało dni: #{@remaining}\n"
if @delays.empty?
  message += "Dzisiaj wszyscy przyszli o czasie!\n"
else
  message += "Godziny przyjścia na dzień #{$nextday}:\n"
  @predictions.each do |person, prediction|
    message += "  @#{@mapping[person]} - #{prediction.strftime("%k:%M")}\n"
  end
end

# Choose color which suits situation
color = if !@resetters.empty?
          "red"
        elsif !@delays.empty?
          "yellow"
        else
          "green"
        end

params = {
  :room_id        => "Brossa 5",
  :from           => "NaziNews",
  :message_format => "text",
  :message        => message,
  :color          => color
}

`curl -d "#{URI.encode_www_form(params)}" https://api.hipchat.com/v1/rooms/message?auth_token=#{@hipchat}`
