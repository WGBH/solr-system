require 'logger'

module HasLogger
  # Sets the logger object
  def logger=(logger)
    fail InvalidLogger.new(logger) unless logger.is_a?(Logger) || logger.nil?
    @logger = logger
  end

  # Accessor for the logger object.
  # Defaults to a basic Logger object, logging to STDOUT
  def logger
    @logger ||= Logger.new(STDOUT)
  end

  class InvalidLogger < StandardError
    def initialize(obj)
      super("expected an instance of Logger, but #{obj.class} was given")
    end
  end
end
