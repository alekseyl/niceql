class String
  def match?(pattern)
    self =~ pattern
  end
end unless String.method_defined?(:match?)