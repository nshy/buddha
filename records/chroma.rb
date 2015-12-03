#!/bin/ruby

def get_cromaprint(path)
  print = nil
  File.open(path, "r") do |file|
    a = file.read.split("\n")[2].gsub(/^FINGERPRINT=/, '')
    print = a.split(',').collect { |v| v.to_i }
  end
  print
end

def bits_set(v)
  b = 0
  (0...32).each do |i|
    b += (v >> i) & 1
  end
  b
end

def correllation(inner, outer, offset)
  l = inner.size
  ln = l - offset
  a1 = inner.slice(0, ln)
  a2 = outer.slice(offset, ln)
  s = 0
  (0...ln).each do |i|
    s += bits_set(a1[i] ^ a2[i])
  end
  return s.to_f / ln / 32
end

def record_len(path)
  File.open(path, "r") do |file|
    file.read.strip.gsub(/^duration: /, '').to_i
  end
end

def chroma_compare(info1, info2)
  c1 = get_cromaprint(info1[:chroma])
  sec1 = record_len(info1[:meta])
  c2 = get_cromaprint(info2[:chroma])
  sec2 = record_len(info2[:meta])

  if sec1 < 120 or sec2 < 120
    return { min: Float::INFINITY,  diff: 0 }
  end

  if (sec1 > sec2)
    diff = sec1 - sec2
    outer = c1
    inner = c2
  else
    diff = sec2 - sec1
    outer = c2
    inner = c1
  end

  diff = 100 if diff > 100
  max_offset = (diff + 1) / 0.124

  corr = (0...max_offset).collect { |offset| correllation(inner, outer, offset) }

  { min: corr.min, diff: diff }
end
