require 'openc3/conversions/conversion'
module OpenC3
  class AgcDp < Conversion
    def initialize(e, b, s)
      super()
      @e = e.to_i
      @b = b.to_i
      @s = s.to_f
    end
    def call(value, packet, buffer)
      word1 = (value >> 15) & 0o77777
      word2 = (value >>  0) & 0o77777
      if word1 & 0o40000 != 0
          word1 = -(word1 ^ 0o77777)
      end
      if word2 & 0o40000 != 0
          word2 = -(word2 ^ 0o77777)
      end

      if word1 > 0 and word2 < 0
        word1 -= 1
        word2 += 0o40000
      elsif word1 < 0 and word2 > 0
        word1 += 1
        word2 -= 0o40000
      end

      if word1 < 0 or (word1 == 0 and word2 < 0)
        sign = -1
        word1 = -word1
        word2 = -word2
      else
        sign = 1
      end

      n = ((((word1 << 14) | word2).to_f / 2**28) / (10**@e) / (2**@b)) * @s
      return sign * n
    end
  end
end
