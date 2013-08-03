# encoding: utf-8
require 'yaml'
require 'date'
require 'uri'

#consts
DEADLINE  = 36000 # 10:00
RESET     = 39600 # 11:00
MULTIPLIER= 2
TEST      = false

module Files
  PREDICTIONS = 'predictions.yml'
  DELAYS      = 'delays.yml'
  RESETS      = 'resets.yml'
  METADATA    = 'metadata.yml'
end

class Day
  attr_reader :curr, :next, :prev

  def initialize today = Date.today
    @curr = today
    @next = @today + (@today.wday == 5 ? 3 : 1)
    @prev = @today - (@today.wday == 1 ? 3 : 1)
  end

  def increment
    (curr - prev).to_i
  end
end

@day = Day.new(Date.today)

#Process all shit
YAML::load(File.open(Files::METADATA)).tap do |meta|
  if meta[@day.curr]
    puts "Script has already been run today"
    exit 1
  end
  @mapping    = meta["mapping"]
  @remaining  = meta[@day.prev]["remaining"] - @day.increment
  @hipchat    = meta["hipchat"]
end
@delays = YAML::load(File.open(Files::DELAYS))[@day.curr] || {}

# Find if someone resetted timer today
@resetters = YAML::load(File.open(Files::RESETS))[@day.curr] || []
@delays.each do |person, delay|
  @resetters << person if delay > RESET
end
@resetters.uniq!
@remaining = 30 unless @resetters.empty?

#Calculate predictions
@predictions = @delays.keys.inject({}) do |memo, person|
  memo.tap do |m|
    prediction = @day.curr.to_time + DEADLINE -
      MULTIPLIER * ([@delays[person], RESET].min - DEADLINE)
    m[person] = prediction
  end
end

# Method to add content with next day
class Writer
  def initialize file, date
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

def write_new_day file, date = @day.next, &block
  File.open(file, 'a+') do |f|
    writer = Writer.new(f, date)
    writer.new_day
    writer.instance_exec @predictions, @remaining, &block
  end
end

unless TEST
  # Add predictions for next day to predictions.yml
  write_new_day(Files::PREDICTIONS) do |predictions|
    predictions.each do |person, prediction|
      write_row "#{person}: #{prediction.strftime("%k:%M")}"
    end
  end

  # Add potential resets to resets.yml
  write_new_day(Files::RESETS) do |predictions|
    predictions.each do |person, _|
      write_row "- #{person}"
    end
  end

  # Write day specific metadata
  write_new_day(Files::METADATA, @day.curr) do |_, remaining|
    write_row "remaining: #{remaining}"
  end
end

# Construct message for HipChat
message = "30 day challenge - #{@day.curr}\n"
unless @resetters.empty?
  message += "@all Wszem i wobec ogłaszam reset!\n"
  message += "Podziękowania należą się #{@resetters.map{ |p| "@#{@mapping[p]}" }.join(', ')}\n"
end
message += "Pozostało dni: #{@remaining}\n"
if @delays.empty?
  message += "Dzisiaj wszyscy przyszli o czasie!\n"
else
  message += "Godziny przyjścia na dzień #{@day.next}:\n"
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

if TEST
  puts message
else
  `curl -d "#{URI.encode_www_form(params)}" https://api.hipchat.com/v1/rooms/message?auth_token=#{@hipchat}`
end
