require 'openc3/conversions/conversion'
module OpenC3
  class AgcSp < Conversion
    def initialize(e, b, s)
      super()
      @e = e.to_i
      @b = b.to_i
      @s = s.to_i
    end
    def call(value, packet, buffer)
      if value & 0o40000 != 0
        sign = -1
        value = value ^ 0o77777
      else
        sign = 1
      end

      n = ((value.to_f / 2**14) / (10**@e) / (2**@b)) * @s
      return sign * n
    end
  end
end
