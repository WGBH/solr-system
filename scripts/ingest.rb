require_relative '../lib/rails_stub'
require_relative 'lib/pb_core_ingester'
require_relative '../lib/has_logger'
require 'rake'

require_relative '../app/models/collection'
require_relative '../app/models/exhibit'

class Exception
  def short
    message + "\n" + backtrace[0..2].join("\n")
  end
end

class ParamsError < StandardError
end

class Ingest
  include HasLogger

  def const_init(name)
    const_name = name.upcase.tr('-', '_')
    flag_name = "--#{name}"
    begin
      # to avoid "warning: already initialized constant" in tests.
      Ingest.const_get(const_name)
    rescue NameError
      Ingest.const_set(const_name, flag_name)
    end
  end

  def initialize(argv)
    orig_argv = argv.dup

    %w(files dirs grep-files grep-dirs).each do |name|
      const_init(name)
    end

    %w(batch-commit stdout-log).each do |name|
      flag_name = const_init(name)
      variable_name = "@is_#{name.tr('-', '_')}"
      instance_variable_set(variable_name, argv.include?(flag_name))
      argv.delete(flag_name)
    end

    # The code above sets fields which log_init needs,
    # but it also modifies argv in place, so we need the dup.
    log_init!(orig_argv)

    mode = argv.shift
    args = argv

    @flags = { is_just_reindex: @is_just_reindex }

    begin
      case mode

      when DIRS
        fail ParamsError.new if args.empty? || args.map { |dir| !File.directory?(dir) }.any?
        target_dirs = args

      when FILES
        fail ParamsError.new if args.empty?
        @files = args

      when GREP_DIRS
        fail ParamsError.new if args.empty?
        @regex = argv.shift
        fail ParamsError.new if args.empty? || args.map { |dir| !File.directory?(dir) }.any?
        target_dirs = args

      when GREP_FILES
        fail ParamsError.new if args.empty?
        @regex = argv.shift
        fail ParamsError.new if args.empty?
        @files = args

      else
        fail ParamsError.new
      end
    rescue ParamsError
      abort usage_message
    end

    @files ||= target_dirs.map do |target_dir|
      Dir.entries(target_dir)
      .reject { |file_name| ['.', '..'].include?(file_name) }
      .map { |file_name| "#{target_dir}/#{file_name}" }
    end.flatten.sort
  end

  def log_init!(argv)
    # Specify a log file unless we are logging to stdout
    unless @is_stdout_log
      self.logger = Logger.new(log_file_name)

      # Print to stdout where the logfile is
      puts "logging to #{log_file_name}"
    end

    logger.formatter = proc do |severity, datetime, _progname, msg|
      "#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S')}]: #{msg}\n"
    end

    # Log how the script was invoked
    logger.info("START: Process ##{Process.pid}: #{__FILE__} #{argv.join(' ')}")
  end

  def usage_message
    <<-EOF.gsub(/^ {4}/, '')
      USAGE: #{File.basename(__FILE__)}
               [#{BATCH_COMMIT}] [#{STDOUT_LOG}]
                #{FILES} FILE ... |
                #{DIRS} DIR ... |
                #{GREP_FILES} REGEX FILE ... |
                #{GREP_DIRS} REGEX DIR ...

      boolean flags:
        #{BATCH_COMMIT}: Optionally, make just one commit at the end, rather than
          one commit per file.
        #{STDOUT_LOG}: Optionally, log to stdout, rather than a log file.

      mutually exclusive modes:
        #{DIRS}: Clean and ingest the given directories.
        #{FILES}: Clean and ingest the given files (either xml or zip).
        #{GREP_DIRS} and #{GREP_FILES}: Same as above, except a regex is also provided.
           Only PBCore which matches the regexp is ingested.
      EOF
  end

  def process
    ingester = PBCoreIngester.new(regex: @regex)

    # set the PBCoreIngester's logger to the same as this object's logger
    ingester.logger = logger

    @files.each do |path|
      begin
        success_count_before = ingester.success_count
        error_count_before = ingester.errors.values.flatten.count
        ingester.ingest(path: path, is_batch_commit: @is_batch_commit)
        success_count_after = ingester.success_count
        error_count_after = ingester.errors.values.flatten.count
        logger.info("Processed '#{path}' #{'but not committed' if @is_batch_commit}")
        logger.info("success: #{success_count_after - success_count_before}; " \
          "error: #{error_count_after - error_count_before}")
      end
    end

    if @is_batch_commit
      logger.info('Starting one big commit...')
      ingester.commit
      logger.info('Finished one big commit.')
    end

    # TODO: Investigate whether optimization is worth it. Requires a lot of disk and time.
    # puts 'Ingest complete; Begin optimization...'
    # ingester.optimize

    errors = ingester.errors.sort # So related errors are together
    error_count = errors.map { |pair| pair[1] }.flatten.count
    success_count = ingester.success_count
    total_count = error_count + success_count

    logger.info('SUMMARY: DETAIL')
    errors.each do |type, list|
      logger.warn("#{list.count} #{type} errors:\n#{list.join("\n")}")
    end

    logger.info('SUMMARY: STATS')
    logger.info('(Look just above for details on each error.)')
    errors.each do |type, list|
      logger.warn("#{list.count} (#{percent(list.count, total_count)}%) #{type}")
    end
    logger.info("#{success_count} (#{percent(success_count, total_count)}%) succeeded")

    logger.info('DONE')
  end

  def percent(part, whole)
    (100.0 * part / whole).round(1)
  end

  def log_file_name
    @log_file_name ||= "#{Rails.root}/log/ingest.#{Time.now.strftime('%Y-%m-%d_%H%M%S')}.log"
  end
end

Ingest.new(ARGV).process if __FILE__ == $PROGRAM_NAME
