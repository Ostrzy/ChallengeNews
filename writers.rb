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
