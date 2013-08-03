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
