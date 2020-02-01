class DbModel
  def prepare_document(excepted = [])
    var_hash = {}
    (instance_variables - excepted).each { |var| var_hash[ var.to_s.delete('@').to_sym ] = instance_variable_get(var) }
    var_hash
  end
end