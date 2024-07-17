class Payment
  attr_reader :amount, :client_id, :operation, :description, :conn
  
  NotFound = Class.new(StandardError)
  
  def initialize(params, conn)
    validate_params(params)
    
    @amount = params['valor']
    @client_id = params['client_id']
    @operation = params['tipo']
    @description = params['descricao']
    @conn = conn
  end

  def call
    return credit_amount if operation == 'c'
    return debit_amount
  end

  private

  def validate_params(params)
    validate_params_existence(params)
    validate_params_type(params)
    validate_params_amount(params)
    validate_params_id(params)
    validate_params_operation(params)
    validate_params_description(params)
  end

  def validate_params_existence(params)
    unless params.has_key?('valor') && params.has_key?('client_id') && params.has_key?('tipo') && params.has_key?('descricao')
      raise ArgumentError, "Invalid parameters"
    end
  end

  def validate_params_type(params)
    unless params['valor'].is_a?(Integer) && params['client_id'].is_a?(Integer) && 
           params['tipo'].is_a?(String) && params['descricao'].is_a?(String)
      raise ArgumentError, "Invalid parameters type"
    end
  end

  def validate_params_amount(params)
    unless params['valor'] > 0
      raise ArgumentError, "Invalid amount"
    end
  end

  def validate_params_id(params)
    unless params['client_id'] > 0
      raise ArgumentError, "Invalid id"
    end
  end

  def validate_params_operation(params)
    unless ['c', 'd'].include?(params['tipo'])
      raise ArgumentError, "Invalid operation"
    end
  end
  
  def validate_params_description(params)
    unless params['descricao'].length > 0 && params['descricao'].length <= 10
      raise ArgumentError, "Invalid description"
    end
  end
  
  def credit_amount
    result = conn.exec_params('SELECT credit_amount($1, $2, $3)', [@client_id, @amount, @description])
    response(result, 'credit_amount')
  end
  
  def debit_amount
    result = conn.exec_params('SELECT debit_amount($1, $2, $3)', [@client_id, @amount, @description])
    response(result, 'debit_amount')
  end
  
  ResponseJson = Struct.new(:success, :amount, :limit) do
    def json_result
      {
        'limite': limit,
        'saldo': amount
      }.to_json
    end
  end
  
  def response(result, type)
    success, amount, limit = result[0][type][1..-2].split(',')
    if amount == nil && limit == nil
      raise NotFound.new("Client not found")
    end
    ResponseJson.new(success, amount.to_i, limit.to_i)
  end
end
