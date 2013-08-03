# encoding: utf-8
require 'yaml'
require 'date'
require 'uri'

require './challenge.rb'
require './day.rb'
require './message_builder.rb'
require './messengers.rb'
require './settings.rb'
require './writers.rb'

#consts
TEST      = true

module Files
  PREDICTIONS = 'data/predictions.yml'
  DELAYS      = 'data/delays.yml'
  RESETS      = 'data/resets.yml'
  SETTINGS    = 'data/settings.yml'
  DAILY       = 'data/daily.yml'
end

@day        = Day.new(Date.today - 1)
@settings   = Settings.new
@challenge  = Challenge.new(@day)
ChallengeWriter.new(@challenge).write
(TEST ? PutsMessenger : HipchatMessenger).new(@challenge, @settings).send
