#require 'globus_era'

class GlobusJob < ActiveJob::Base

  #@@globus_era = Umrdr::GlobusEra.new
  @@globus_era_timestamp = Umrdr::Application.config.globus_era_timestamp
  @@globus_era_token = Umrdr::Application.config.globus_era_token.freeze

  @@globus_enabled = Umrdr::Application.config.globus_enabled.freeze
  #@@globus_token = Umrdr::Application.config.globus_era_file
  #@@globus_era_file = Umrdr::Application.config.globus_era_file
  @@globus_base_file_name = Umrdr::Application.config.base_file_name.freeze
  @@globus_base_url = Umrdr::Application.config.globus_base_url.freeze
  @@globus_download_dir = Umrdr::Application.config.globus_download_dir.freeze
  @@globus_prep_dir = Umrdr::Application.config.globus_prep_dir.freeze

  def self.files_available?( concern_id )
    copy_complete? concern_id
  end

  def self.copy_complete?( id )
    dir = @@globus_download_dir
    dir = dir.join files_target_file_name( id )
    Dir.exists? dir
  end

  def self.error_file( id )
    target_file_name_env( @@globus_prep_dir, 'error', target_base_name( id ) )
  end

  def self.error_file_exists?( id, write_error_to_log: false, log_prefix: '', quiet: true )
    error_file = error_file( id )
    error_file_exists = false
    if File.exists? error_file
      if write_error_to_log
        msg = nil
        open( error_file, 'r' ) { |f| msg = f.read; msg.chomp! }
        Rails.logger.debug "#{log_prefix} error file contains: #{msg}" unless quiet
      end
      error_file_exists = true
    end
    error_file_exists
  end

  def self.external_url( id )
    "#{@@globus_base_url}#{files_target_file_name(id)}%2F"
  end

  def self.files_target_file_name( id = '' )
    "#{@@globus_base_file_name}#{id}"
  end

  def self.files_prepping?( id )
    rv = !copy_complete?( id ) && locked?( id )
    rv
  end

  def self.lock( concern_id, log_prefix )
    lock_token = era_token
    lock_file = lock_file concern_id
    Rails.logger.debug "#{log_prefix} writing lock token #{lock_token} to #{lock_file}" unless @globus_job_quiet
    open( lock_file, 'w' ) { |f| f << lock_token << "\n" }
    File.exists? lock_file
  end

  def self.lock_file( id = '' )
    target_file_name_env( @@globus_prep_dir, 'lock', target_base_name( id ) )
  end

  def self.locked?( concern_id, write_error_to_log: false, log_prefix: '', quiet: true )
    return false if error_file_exists?( concern_id, write_error_to_log: true, log_prefix: log_prefix, quiet: quiet )
    lock_file = lock_file concern_id
    return false unless File.exists? lock_file
    current_token = era_token
    lock_token = read_token lock_file
    rv = ( current_token == lock_token )
    Rails.logger.debug "#{log_prefix} testing token from #{lock_file}: current_token: #{current_token} == lock_token: #{lock_token}: #{rv}" unless @quiet
    rv
  end

  def self.read_token( token_file )
    token = nil
    open( token_file, 'r' ) { |f| token = f.read.chomp! }
    return token
  end

  def self.target_base_name( id = '', prefix: '', postfix: '' )
    "#{prefix}#{@@globus_base_file_name}#{id}#{postfix}"
  end

  def self.target_file_name_env( dir, file_type, base_name )
    target_file_name( dir, ".#{Rails.env}.#{file_type}.#{base_name}" )
  end

  def self.target_file_name( dir, filename, ext = '' )
    return Pathname.new( filename + ext ) if dir.nil?
    dir.join( filename + ext )
  end

  # def self.token
  #   # TODO: remove this, replace by self.era_token
  #   #@@globus_token.path #if it's a Tempfile
  #   #@@globus_token
  #   @@globus_era.era_file
  # end

  def self.era_token
    #read_token @@globus_era_file
    #read_token @@globus_era.era_file
    @@globus_era_token
  end

  def self.era_token_time
    timestamp = era_token
    Time.parse( timestamp )
  end

  # def self.token_time
  #   ## TODO: remove as replaced by era_token_time
  #   File.birthtime @@globus_token
  #   #File.birthtime @@globus_token.path # if it's a Tempfile
  #   #Umrdr::GlobusEra.era_begin_timestamp
  # end

  # @param [String] concern_id
  # @param [String, "Globus: "] log_prefix
  def perform( concern_id, log_prefix: "Globus: " )
    @globus_concern_id = concern_id
    @globus_log_prefix = log_prefix
    @globus_lock_file = GlobusJob.lock_file concern_id
  end

  protected

  def globus_acquire_lock?
    return false if globus_locked?
    globus_lock
  end

  def globus_copy_job_complete?( concern_id )
    Dir.exists? target_download_dir concern_id
  end

  def globus_error( msg )
    file = globus_error_file
    Rails.logger.debug "#{@globus_log_prefix} writing error message to #{file}" unless @globus_job_quiet
    open( file, 'w' ) { |f| f << msg << "\n" }
    file
  end

  def globus_error_file
    GlobusJob.target_file_name_env( @@globus_prep_dir, 'error', GlobusJob.target_base_name( @globus_concern_id ) )
  end

  def globus_error_file_exists?( write_error_to_log: false )
    GlobusJob.error_file_exists?( @globus_concern_id,
                              write_error_to_log: write_error_to_log,
                              log_prefix: @globus_log_prefix,
                              quiet: @globus_job_quiet )
    # error_file = globus_error_file
    # error_file_exists = false
    # if File.exists? error_file
    #   if write_error_to_log
    #     msg = nil
    #     open( error_file, 'r' ) { |f| msg = f.read; msg.chomp! }
    #     Rails.logger.debug "#{@globus_log_prefix} error file contains: #{msg}" unless @globus_job_quiet
    #   end
    #   error_file_exists = true
    # end
    # error_file_exists
  end

  def globus_error_reset
    file = globus_error_file
    File.delete file if File.exists? file
    true
  end

  def globus_file_lock( file, mode: File::LOCK_EX )
    success = true
    if File.exists? file
      success = file.flock( mode )
      if success
        begin
          yield file
        ensure
          file.flock( File::LOCK_UN )
        end
      end
    else
      yield file
    end
    return success
  end

  def globus_job_perform( concern_id: '', email: nil, log_prefix: 'Globus: ', quiet: false, &globus_block )
    @globus_concern_id = concern_id
    @globus_log_prefix = log_prefix
    @globus_lock_file = nil
    @globus_job_quiet = quiet
    return unless @@globus_enabled
    begin
      if globus_job_complete?
        globus_job_perform_already_complete( email: email )
        return
      end
      @globus_lock_file = GlobusJob.lock_file @globus_concern_id
      Rails.logger.debug "#{@globus_log_prefix} lock file #{@globus_lock_file}" unless @globus_job_quiet
    rescue Exception => e
      msg = "#{@globus_log_prefix} #{e.class}: #{e.message} at #{e.backtrace[0]}"
      Rails.logger.error msg
      globus_error msg
      return
    end
    unless globus_acquire_lock?
      globus_job_perform_in_progress( email: email )
      return
    end
    begin
      globus_error_reset
      globus_job_perform_complete_reset
      globus_block.call
      @globus_lock_file = globus_unlock
      globus_job_perform_complete
    rescue Exception => e
      msg = "#{@globus_log_prefix} #{e.class}: #{e.message} at #{e.backtrace[0]}"
      Rails.logger.error msg
      globus_error msg
    ensure
      globus_unlock
    end
  end

  def globus_job_perform_already_complete( email: nil )
    if email.nil?
      Rails.logger.debug "#{@globus_log_prefix} skipping already complete globus job" unless @globus_job_quiet
    else
      Rails.logger.debug "#{@globus_log_prefix} skipping already complete globus job, email=#{email}" unless @globus_job_quiet
    end
  end

  def globus_job_perform_in_progress( email: nil )
    if email.nil?
      Rails.logger.debug "#{@globus_log_prefix} skipping in progress globus job" unless @globus_job_quiet
    else
      Rails.logger.debug "#{@globus_log_prefix} skipping in progress globus job, email=#{email}" unless @globus_job_quiet
    end
  end

  def globus_job_perform_complete
    file = globus_job_complete_file
    timestamp = Time.now.to_s
    open( file, 'w' ) { |f| f << timestamp << "\n" }
    globus_error_reset
    Rails.logger.debug "#{@globus_log_prefix} job complete at #{timestamp}" unless @globus_job_quiet
    return file
  end

  def globus_job_perform_complete_reset
    file = globus_job_complete_file
    File.delete file if File.exists? file
    true
  end

  def globus_lock
    GlobusJob.lock( @globus_concern_id, @globus_log_prefix )
    # lock_token = GlobusJob.token
    # lock_file = GlobusJob.lock_file @globus_concern_id
    # Rails.logger.debug "#{@globus_log_prefix} writing lock token #{lock_token} to #{lock_file}" unless @globus_job_quiet
    # open( lock_file, 'w' ) { |f| f << lock_token << "\n" }
    # File.exists? lock_file
  end

  def globus_lock_file( id = '' )
    GlobusJob.lock_file id
  end

  def globus_locked?
    GlobusJob.locked?( @globus_concern_id,
                       write_error_to_log: true,
                       log_prefix: @globus_log_prefix,
                       quiet: @globus_job_quiet )
    # return false if globus_error_file_exists?( write_error_to_log: true )
    # lock_file = GlobusJob.lock_file @globus_concern_id
    # return false unless File.exists? lock_file
    # current_token = GlobusJob.token
    # lock_token = nil
    # open( lock_file, 'r' ) { |f| lock_token = f.read.chomp! }
    # rv = ( current_token == lock_token )
    # Rails.logger.debug "#{@globus_log_prefix} testing token from #{lock_file}: current_token: #{current_token} == lock_token: #{lock_token}: #{rv}" unless @globus_job_quiet
    # rv
  end

  def globus_unlock
    return nil if @globus_lock_file.nil?
    return nil unless File.exists? @globus_lock_file
    Rails.logger.debug "#{@globus_log_prefix} unlock by deleting file #{@globus_lock_file}" unless @globus_job_quiet
    File.delete @globus_lock_file
    nil
  end

  def target_download_dir( concern_id )
    target_dir_name( @@globus_download_dir, GlobusJob.target_base_name( concern_id ) )
  end

  def target_dir_name( dir, subdir, mkdir: false )
    target_dir = dir.join subdir
    if mkdir
      Dir.mkdir(target_dir ) unless Dir.exists? target_dir
    end
    target_dir
  end

  def target_prep_dir( concern_id, prefix: '', postfix: '', mkdir: false )
    subdir = GlobusJob.target_base_name( concern_id, prefix: prefix, postfix: postfix )
    target_dir_name( @@globus_prep_dir, subdir, mkdir: mkdir )
  end

  def target_prep_tmp_dir( concern_id, prefix: '', postfix: '', mkdir: false )
    dir = target_prep_dir( concern_id, prefix: prefix, postfix: "#{postfix}_tmp" )
    if mkdir
      Dir.mkdir(dir ) unless Dir.exists? dir
    end
    dir
  end

end
