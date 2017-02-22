#!/usr/bin/env ruby

$style = ARGV.shift
$bucket_size = ARGV.shift.to_f

if !["linear", "log", "test"].any? { |d| d == $style } then
  puts "Error: first arg must be 'linear' or 'log'."
  exit 1
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
    if @count > 1 then
      variance = (@count * @sum_squares - (@sum * @sum)) /
        (@count * (@count - 1))
      Math.sqrt(variance)
    else
      0
    end
  end
end


class WeightedStats

  attr_reader :min, :max
  
  def initialize()
    @count = 0
    @sum = 0.0
    @mu = 0
    @s = 0
    @sum_weight = 0.0
    @min = nil
    @max = nil
  end

  def add(data, weight)
    @count += 1
    @sum_weight += weight
    @sum += data * weight
    old_mu = @mu
    @mu += (data - old_mu) * (weight / @sum_weight)
    @s += weight * (data - old_mu) * (data - @mu)
    @min = data if !@min || data < @min
    @max = data if !@max || data > @max
  end

  def count
    @count
  end

  def mean
    if count > 0 then
      @sum / @sum_weight
    else
      0
    end
  end

  def std_dev
    if @count > 1 then
      Math.sqrt(@s / @sum_weight * (@count.to_f / (@count - 1)))
    else
      0
    end
  end
end

class WeightedStatsLong
  class Record
    attr_reader :data, :weight
    
    def initialize(data, weight)
      @data = data
      @weight = weight
    end
  end
  
  def initialize()
    @count = 0
    @sum = 0.0
    @sum_weight = 0.0
    @data = []
  end

  def add(data, weight)
    @count += 1
    @sum_weight += weight
    @sum += data * weight
    @data << Record.new(data, weight)
  end

  def count
    @count
  end

  def mean
    if count > 0 then
      @sum / @sum_weight
    else
      0
    end
  end

  def std_dev
    if @count <= 1 then
      0
    else
      mn = mean
      num = @count * @data.reduce(0) { |memo,d|
        memo += d.weight * (mn - d.data)**2
      }
      denom = (@count - 1) * @sum_weight
      # denom = (@count) * @sum_weight
      Math.sqrt(num / denom)
    end
  end
end


# througput 9 to 20

to_bin_lin = Proc.new do |v|
  (v / $bucket_size).to_i
end

from_bin_lin = Proc.new do |bin|
  $bucket_size * bin + $bucket_size / 2.0
end

to_bin_log = Proc.new do |v|
  (Math::log2(v.to_f) / $bucket_size).to_i
end

from_bin_log = Proc.new do |bin|
  2.0 ** (bin * $bucket_size.to_f)
end

def main(argv, to_bin, from_bin)
  latency_bins = Hash.new { |h,k| h[k] = Stats.new }
  throughput_bins = Hash.new { |h,k| h[k] = Stats.new }
  latency_wt_bins = Hash.new { |h,k| h[k] = WeightedStats.new }
  throughput_wt_bins = Hash.new { |h,k| h[k] = WeightedStats.new }

  argv.each do |a|
    File.readlines(a).each do |l|
      next if l =~ /^ *#/
        a = l.split(' ')

      weight = a[4].to_f # total_bytes
      # next if weight < 4096

      throttle_size = a[8].to_f
      throughput = a[19].to_f
      latency = a[1].to_f

      bin = to_bin.call(throttle_size)

      throughput_bins[bin].add(throughput)
      latency_bins[bin].add(latency)

      throughput_wt_bins[bin].add(throughput, weight)
      latency_wt_bins[bin].add(latency, weight)
    end
  end

  puts "# combined data"
  puts "# 1:throttle_size_bytes 2:data_point_count 3:latency_mean 4:latency_std_dev 5:throughput_mean 6:throughput_std_dev 7:latency_wt_mean 8:latency_wt_std_dev 9:throughput_wt_mean 10:throughput_wt_std_dev 11:latency_min 12:latency_max 13:throughput_min 14:throughput_max"
  throughput_bins.keys.sort.each do |b|
    throughput_stats = throughput_bins[b]
    latency_stats = latency_bins[b]
    throughput_wt_stats = throughput_wt_bins[b]
    latency_wt_stats = latency_wt_bins[b]
    puts "#{from_bin.call(b)} #{latency_stats.count} #{latency_stats.mean} #{latency_stats.std_dev} #{throughput_stats.mean} #{throughput_stats.std_dev} #{latency_wt_stats.mean} #{latency_wt_stats.std_dev} #{throughput_wt_stats.mean} #{throughput_wt_stats.std_dev} #{latency_wt_stats.min} #{latency_wt_stats.max} #{throughput_wt_stats.min} #{throughput_wt_stats.max}"
  end
end


def test(data)
  s0 = Stats.new
  s1 = WeightedStats.new
  s2 = WeightedStatsLong.new
  data.each do |e|
    s0.add(e[0])
    s1.add(e[0], e[1])
    s2.add(e[0], e[1])
  end
  puts "#{s0.mean} , #{s0.std_dev}"
  puts "#{s1.mean} , #{s1.std_dev}"
  puts "#{s2.mean} , #{s2.std_dev}"
end


if $style == "test" then
  test([[5, 1], [4, 1], [3, 1], [10, 1], [9, 1], [5, 1]])
  puts "===="
  test([[5, 0.32], [4, 0.32], [3, 0.32], [10, 0.32], [9, 0.32], [5, 0.32]])
  puts "===="
  test([[5, 2], [4, 1], [3, 2], [10, 1], [9, 2], [5, 3]])
elsif $style == "linear" then
  main(ARGV, to_bin_lin, from_bin_lin)
else
  main(ARGV, to_bin_log, from_bin_log)
end
