require 'openc3/conversions/conversion'
module OpenC3
  class DskyReg < Conversion
    @@digits = {
      0b00000 => " ",
      0b10101 => "0",
      0b00011 => "1",
      0b11001 => "2",
      0b11011 => "3",
      0b01111 => "4",
      0b11110 => "5",
      0b11100 => "6",
      0b10011 => "7",
      0b11101 => "8",
      0b11111 => "9",
    }
    @@signs = {
      0b00 => " ",
      0b01 => "-",
      0b10 => "+",
      0b11 => "+",
    }
    def initialize(dsptab_name, reg)
      super()
      @dsptab_name = dsptab_name
      @reg = reg.to_i
    end
    def call(value, packet, buffer)
      dsptab = packet.read(@dsptab_name, :RAW, buffer)
      if @reg == 7 # PROG
        char1 = @@digits[(dsptab[10] >> 5) & 0o37]
        char2 = @@digits[(dsptab[10] >> 0) & 0o37]
        return char1 + char2
      elsif @reg == 4 # VERB
        char1 = @@digits[(dsptab[9] >> 5) & 0o37]
        char2 = @@digits[(dsptab[9] >> 0) & 0o37]
        return char1 + char2
      elsif @reg == 5 # NOUN
        char1 = @@digits[(dsptab[8] >> 5) & 0o37]
        char2 = @@digits[(dsptab[8] >> 0) & 0o37]
        return char1 + char2
      elsif @reg == 1 # REG1
        sign = @@signs[((dsptab[6] >> 9) & 0b10) | ((dsptab[5] >> 10) & 0b01)]
        char1 = @@digits[(dsptab[7] >> 0) & 0o37]
        char2 = @@digits[(dsptab[6] >> 5) & 0o37]
        char3 = @@digits[(dsptab[6] >> 0) & 0o37]
        char4 = @@digits[(dsptab[5] >> 5) & 0o37]
        char5 = @@digits[(dsptab[5] >> 0) & 0o37]
        return sign + char1 + char2 + char3 + char4 + char5
      elsif @reg == 2 # REG2
        sign = @@signs[((dsptab[4] >> 9) & 0b10) | ((dsptab[3] >> 10) & 0b01)]
        char1 = @@digits[(dsptab[4] >> 5) & 0o37]
        char2 = @@digits[(dsptab[4] >> 0) & 0o37]
        char3 = @@digits[(dsptab[3] >> 5) & 0o37]
        char4 = @@digits[(dsptab[3] >> 0) & 0o37]
        char5 = @@digits[(dsptab[2] >> 5) & 0o37]
        return sign + char1 + char2 + char3 + char4 + char5
      elsif @reg == 3 # REG3
        sign = @@signs[((dsptab[1] >> 9) & 0b10) | ((dsptab[0] >> 10) & 0b01)]
        char1 = @@digits[(dsptab[2] >> 0) & 0o37]
        char2 = @@digits[(dsptab[1] >> 5) & 0o37]
        char3 = @@digits[(dsptab[1] >> 0) & 0o37]
        char4 = @@digits[(dsptab[0] >> 5) & 0o37]
        char5 = @@digits[(dsptab[0] >> 0) & 0o37]
        return sign + char1 + char2 + char3 + char4 + char5
      end
    end
  end
end
