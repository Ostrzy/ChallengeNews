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
