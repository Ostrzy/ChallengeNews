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

  attr_reader :remaining, :resetters, :predictions, :day

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

  def potential_resetters
    @predictions.keys
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
class SimpleYamlWriter
  def initialize file
    @f = file
  end

  def write root, values
    write_root root
    if values.is_a? Hash
      write_hash values
    elsif values.is_a? Array
      write_array values
    else
      write_else values
    end
  end

  private
    def write_root key
      @f.write "\n"
      @f.write "#{key}:\n"
    end

    def write_row line
      @f.write "  #{line}\n"
    end

    def write_hash hash
      hash.each do |key, value|
        write_row "#{key}: #{value}"
      end
    end

    def write_array arr
      arr.each do |value|
        write_row "- #{value}"
      end
    end

    def write_else values
      write_row values.to_s
    end
end

class ChallengeWriter
  def initialize challenge, writer = SimpleYamlWriter
    @day        = challenge.day
    @challenge  = challenge
    @writer     = writer
  end

  def write
    # Add predictions for next day to predictions.yml
    write_new_day Files::PREDICTIONS, formatted_predictions
    # Add potential resets to resets.yml
    write_new_day Files::RESETS, @challenge.potential_resetters
    # Write day specific data - for now only remaining days
    write_new_day Files::DAILY, "remaining: #{@challenge.remaining}", @day.curr
  end

  private
    def write_new_day file, values, date = @day.next
      File.open(TEST ? 'test.yml' : file, 'a+') do |f|
        @writer.new(f).write date, values
      end
    end

    def formatted_predictions
      Hash[@challenge.predictions.to_a.map{ |person, time| [person, time.strftime("%k:%M")] }]
    end
end

ChallengeWriter.new(@challenge).write

class MessageBuilder
  def initialize challenge, settings
    @day        = challenge.day
    @challenge  = challenge
    @settings   = settings
    @message    = []
    build_message
  end

  def message
    @rendered_message = @message.join("\n") + "\n"
  end

  private
    def build_message
      challenge_header
      if @challenge.reset?
        reset_acclamation
        reset_thanks
      end
      days_left
      if @challenge.delay?
        predictions_header
        predictions
      else
        no_predictions
      end
    end

    def challenge_header
      @message << "30 day challenge - #{@day.curr}"
    end

    def reset_acclamation
      @message << "@all Wszem i wobec ogłaszam reset!"
    end

    def reset_thanks
      @message << "Podziękowania należą się #{@challenge.resetters.map{ |p| "@#{@settings.map(p)}" }.join(', ')}"
    end

    def days_left
      @message << "Pozostało dni: #{@challenge.remaining}"
    end

    def predictions_header
      @message << "Godziny przyjścia na dzień #{@day.next}:"
    end

    def predictions
      @challenge.predictions.each do |person, prediction|
        @message << "  @#{@settings.map(person)} - #{prediction.strftime("%k:%M")}"
      end
    end

    def no_predictions
      @message << "Dzisiaj wszyscy przyszli o czasie!"
    end
end

class Messenger
  def initialize challenge, settings
    @challenge  = challenge
    @settings   = settings
    @message    = MessageBuilder.new(challenge, settings).message
  end

  def send
    raise NotImplementedError
  end
end

class HipchatMessenger < Messenger
  def send
    `curl -d "#{URI.encode_www_form(params)}" #{url}`
  end

  private
    def color
      if @challenge.reset?
        "red"
      elsif @challenge.delay?
        "yellow"
      else
        "green"
      end
    end

    def url
      "https://api.hipchat.com/v1/rooms/message?auth_token=#{@settings.hipchat}"
    end

    def params
      {
        :room_id        => "Brossa 5",
        :from           => "NaziNews",
        :message_format => "text",
        :message        => @message,
        :color          => color
      }
    end
end

class PutsMessenger < Messenger
  def send
    puts @message
  end
end

(TEST ? PutsMessenger : HipchatMessenger).new(@challenge, @settings).send
