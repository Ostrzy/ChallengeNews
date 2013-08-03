# encoding: utf-8
require 'yaml'
require 'date'
require 'uri'

#consts
TEST      = false

module Files
  PREDICTIONS = 'predictions.yml'
  DELAYS      = 'delays.yml'
  RESETS      = 'resets.yml'
  SETTINGS    = 'settings.yml'
  DAILY       = 'daily.yml'
end

class Day
  attr_reader :curr, :next, :prev

  def initialize today = Date.today
    @curr = today
    @next = curr + (curr.wday == 5 ? 3 : 1)
    @prev = curr - (curr.wday == 1 ? 3 : 1)
  end

  def increment
    (curr - prev).to_i
  end
end

@day = Day.new(Date.today)

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

@settings = Settings.new

class AlreadyRunError < StandardError; end

class Challenge
  DEADLINE    = 36000 # 10:00
  RESET       = 39600 # 11:00
  MULTIPLIER  = 2
  LENGTH      = 30

  attr_reader :remaining, :resetters, :predictions

  def initialize day
    @day = day
    daily = YAML::load(File.open(Files::DAILY))
    if !TEST && daily[@day.curr]
      raise AlreadyRunError, "Challenge for today has already been run"
    end

    @remaining  = daily[@day.prev]["remaining"] - @day.increment
    @delays     = YAML::load(File.open(Files::DELAYS))[@day.curr] || {}
    check_reset
    calculate_predictions
  end

  def reset?
    !@resetters.empty?
  end

  def delay?
    !@delays.empty?
  end

  private
    def check_reset
      @resetters = YAML::load(File.open(Files::RESETS))[@day.curr] || []
      @delays.each do |person, delay|
        @resetters << person if delay > RESET
      end
      @resetters.uniq!
      @remaining = LENGTH unless @resetters.empty?
    end

    def calculate_predictions
      @predictions = @delays.keys.inject({}) do |memo, person|
        memo.tap do |m|
          prediction = @day.curr.to_time + DEADLINE -
            MULTIPLIER * ([@delays[person], RESET].min - DEADLINE)
          m[person] = prediction
        end
      end
    end
end

@challenge = Challenge.new(@day)

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
    writer.instance_exec @challenge.predictions, @challenge.remaining, &block
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
  write_new_day(Files::DAILY, @day.curr) do |_, remaining|
    write_row "remaining: #{remaining}"
  end
end

# Construct message for HipChat
message = "30 day challenge - #{@day.curr}\n"
if @challenge.reset?
  message += "@all Wszem i wobec ogłaszam reset!\n"
  message += "Podziękowania należą się #{@challenge.resetters.map{ |p| "@#{@settings.map(p)}" }.join(', ')}\n"
end
message += "Pozostało dni: #{@challenge.remaining}\n"
if @challenge.delay?
  message += "Godziny przyjścia na dzień #{@day.next}:\n"
  @challenge.predictions.each do |person, prediction|
    message += "  @#{@settings.map(person)} - #{prediction.strftime("%k:%M")}\n"
  end
else
  message += "Dzisiaj wszyscy przyszli o czasie!\n"
end

# Choose color which suits situation
color = if @challenge.reset?
          "red"
        elsif @challenge.delay?
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
  `curl -d "#{URI.encode_www_form(params)}" https://api.hipchat.com/v1/rooms/message?auth_token=#{@settings.hipchat}`
end
