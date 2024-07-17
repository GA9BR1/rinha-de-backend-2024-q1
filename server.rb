require 'agoo'
require 'json'
require 'pg'

Agoo::Log.configure(dir: '', console: true)

Agoo::Server.init(ENV['PORT'].to_i, './root')


class Payments
  require_relative 'payment'
  require_relative 'extract'
  attr_reader :conn
  
  def initialize
    @conn = PG.connect(dbname: 'postgres', user: "#{ENV['PORT'] == '6464' ? 'app1' : 'app2'}", password: 'postgres', host: 'pg_bouncer', port: 6432)
  end

  def call(req)
    if req['REQUEST_METHOD'] == 'GET'
      handle_extract(req)
    elsif req['REQUEST_METHOD'] == 'POST'
      handle_payment(req)
    else
      [ 405, {}, [ "Method Not Allowed" ] ]
    end
  end
  
  private
  
  def handle_payment(req)
    begin
    payment = Payment.new(all_params(req), conn).call
    
    return [ 200, {}, [ payment.json_result ] ] if payment.success == 't'
    return [ 422, {}, [ "Error" ] ] if payment.success == 'f'
  
    rescue Payment::NotFound => e
      return [ 404, {}, [ e.message ] ]
    rescue ArgumentError => e
      return [ 422, {}, [ e.message ] ]
    end
  end
  
  def handle_extract(req)
    begin
    extract = Extract.new(client_id(req), conn).call
    [ 200, {}, [ extract ] ]
    
    rescue Extract::NotFound => e
      return [ 404, {}, [ e.message ] ]
    rescue ArgumentError => e
      return [ 422, {}, [ e.message ] ]
    end
  end
  
  def client_id(req)
    req['PATH_INFO'].split('/')[2].to_i
  end

  def all_params(req)
    body = req['rack.input'].read
    JSON.parse(body).merge({ 'client_id' => client_id(req) })
  end
end

class Status
  def call(req)
    [ 200, {}, [ "GET /status - Server is running" ] ]
  end
end

payments_handler = Payments.new
status_handler = Status.new

Agoo::Server.handle(:GET, "/clientes/*/extrato", payments_handler)
Agoo::Server.handle(:POST, "/clientes/*/transacoes", payments_handler)

Agoo::Server.handle(:GET, "/status", status_handler)

Agoo::Server.start()

# To run this example type the following then go to a browser and enter a URL
# of localhost:6464/status or localhost:6464/payments.
#
# ruby hello.rb
