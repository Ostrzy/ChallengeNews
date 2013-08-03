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
