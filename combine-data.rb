#!/usr/bin/env ruby

$style = ARGV.shift
$bucket_size = ARGV.shift.to_f

if $style != "linear" && $style != "log" then
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

  argv.each do |a|
    File.readlines(a).each do |l|
      next if l =~ /^ *#/
        a = l.split(' ')

      throttle_size = a[8].to_f
      bin = to_bin.call(throttle_size)
      throughput = a[19].to_f
      throughput_bins[bin].add(throughput)
      latency = a[1].to_f
      latency_bins[bin].add(latency)
    end
  end

  puts "# combined data"
  puts "# 1:throttle_size_bytes 2:data_point_count 3:latency_mean 4:latency_std_dev 5:throughput_mean 6:throughput_std_dev"
  throughput_bins.keys.sort.each do |b|
    throughput_stats = throughput_bins[b]
    latency_stats = latency_bins[b]
    puts "#{from_bin.call(b)} #{latency_stats.count} #{latency_stats.mean} #{latency_stats.std_dev} #{throughput_stats.mean} #{throughput_stats.std_dev}"
  end
end


if $style == "linear" then
  main(ARGV, to_bin_lin, from_bin_lin)
else
  main(ARGV, to_bin_log, from_bin_log)
end
