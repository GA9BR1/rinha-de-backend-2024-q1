class Extract
  attr_reader :client_id, :conn
  
  NotFound = Class.new(StandardError)
  
  def initialize(client_id, conn)
    validate_client_id(client_id)
    
    @client_id = client_id
    @conn = conn
  end
  
  def call
    result = JSON.parse(conn.exec("SELECT client_extract(#{client_id}) AS extrato").getvalue(0, 0))
    raise NotFound, "Client not found" if result['saldo']['total'] == nil
    
    result.to_json
  end
  
  private
  
  def validate_client_id(client_id)
    unless !client_id.nil? && client_id > 0
      raise ArgumentError, "Invalid id"
    end
  end
end