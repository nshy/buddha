class Week
  include Comparable

  def initialize(date = Date.today)
    @monday = date - (date.cwday - 1)
  end

  def monday
    @monday
  end

  def sunday
    @monday + 6
  end

  def day(cwday)
    @monday + (cwday - 1)
  end

  def self.cwdays
    1..7
  end

  def dates
    monday..sunday
  end

  def prev
    Week.new(@monday - 7)
  end

  def next
    Week.new(@monday + 7)
  end

  def succ
    self.next
  end

  def <=>(week)
    self.monday <=> week.monday
  end

  def -(week)
    (@monday - week.monday).numerator / 7
  end

  def +(num)
    Week.new(@monday + 7 * num)
  end

  def to_s
    "start at #{@monday}"
  end
end
