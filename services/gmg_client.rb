# frozen_string_literal: true

require 'socket'

POWER_ON         = 'UK001!'
POWER_OFF        = 'UK004!'
GET_GRILL_STATUS = 'UR001!'
GET_GRILL_ID     = 'UL!'
GRILL_TEMP_F     = ->(temp) { "UT#{temp}!" }
FOOD_TEMP_F      = ->(temp) { "UF#{temp}!" }
GRILL_STATUS_MAP = {
  '0' => 'off',
  '1' => 'on',
  '2' => 'cooling'
}.freeze

# HEX_STATUS_EXAMPLE = "55528f0052009600060314321919000000000000ffffffff00000000000001000232000100009b00df4443303153554630372e310064fe"

class GmgClient
  def initialize(options = {})
    @port = options[:port] || 8080
    @host = options[:host] || '255.255.255.255' # broadcast
    discover_grill
    @socket = UDPSocket.new
    @socket.connect(@host, @port)
    update_status
  end

  attr_accessor :host, :port, :grill_id, :hex_status, :socket, :current_status

  def turn_on
    update_status
    return false if %w[on cooling].includes?(@current_status[:status])

    socket.send(POWER_ON, 0)
    update_status
  end

  def turn_off
    update_status
    return false if %w[off cooling].includes?(@current_status[:status])

    socket.send(POWER_OFF, 0)
    update_status
  end

  def grill_temp(temp)
    update_status
    return false if %w[off cooling].includes?(@current_status[:status])

    socket.send(GRILL_TEMP_F.call(temp), 0)
    update_status
  end

  def food_temp(temp)
    update_status
    return false if %w[off cooling].includes?(@current_status[:status])

    socket.send(FOOD_TEMP_F.call(temp), 0)
    update_status
  end

  def update_status
    fetch_status
    @current_status = decode_status
  end

  private

  def fetch_status
    socket.send(GET_GRILL_STATUS, 0)
    data = socket.recvfrom(64)
    @hex_status = data[0].unpack1('H*')
  end

  def decode_status
    {
      status: get_grill_status(@hex_status),
      current_grill_temp: get_current_grill_temp(@hex_status),
      desired_grill_temp: get_desired_grill_temp(@hex_status),
      current_food_temp: get_current_food_temp(@hex_status),
      desired_food_temp: get_desired_food_temp(@hex_status),
      low_pellet_alarm: get_low_pellet_alarm(@hex_status)
    }
  end

  def decode_temperature(hex_status, pos1, pos2)
    first = get_raw_value(hex_status, pos1)
    second = get_raw_value(hex_status, pos2)
    first + (second * 256)
  end

  def get_current_grill_temp(hex_status)
    decode_temperature(hex_status, 4, 6)
  end

  def get_desired_grill_temp(hex_status)
    decode_temperature(hex_status, 12, 14)
  end

  def get_current_food_temp(hex_status)
    temp = decode_temperature(hex_status, 8, 10)
    temp >= 557 ? 0 : temp
  end

  def get_desired_food_temp(hex_status)
    decode_temperature(hex_status, 56, 58)
  end

  def get_grill_status(hex_status)
    GRILL_STATUS_MAP[hex_status[61]] || 'unknown'
  end

  def get_low_pellet_alarm(hex_status)
    first = get_raw_value(hex_status, 48)
    second = get_raw_value(hex_status, 50)
    value = first + (second * 256)
    value == 128
  end

  def get_raw_value(hex, position)
    hex.slice(position, 2).to_i(16)
  end

  def discover_grill
    return unless @host == '255.255.255.255'

    UDPSocket.open do |socket|
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.send(GET_GRILL_ID, 0, @host, @port)

      data      = socket.recvfrom(12)
      @host     = data[1][3]
      @grill_id = data[0]
    end
  end
end