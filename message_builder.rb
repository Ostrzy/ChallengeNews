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
