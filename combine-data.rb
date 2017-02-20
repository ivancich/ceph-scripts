#!/usr/bin/env ruby

# througput 9 to 20

def to_bin(v)
  (v / 1000.0).to_i
end

def from_bin(bin)
  bin * 1000.0
end

class Stats
  def initialize()
    @count = 0
    @sum = 0.0
    @sum_squares = 0.0
  end

  def add(data)
    @count += 1
    @sum += data
    @sum_squares += data * data
  end

  def count
    @count
  end

  def mean
    if count > 0 then
      @sum / @count
    else
      0
    end
  end

  def std_dev
    if @count > 0 then
      variance = (@count * @sum_squares - (@sum * @sum)) /
        (@count * (@count - 1))
      Math.sqrt(variance)
    else
      0
    end
  end
end

ARGV.each do |a|
  File.readlines(a).each do |l|
    next if l =~ /^ *#/
      a = l.split(' ')
    
    puts "#
  end
end
